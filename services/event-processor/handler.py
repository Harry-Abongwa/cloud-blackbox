import json
import boto3
import os
import hashlib
from datetime import datetime, timezone

dynamodb = boto3.resource("dynamodb")
TABLE_NAME = os.environ.get("INCIDENT_TABLE")

# Sensitive IAM actions we care about
SENSITIVE_ACTIONS = {
    "AttachUserPolicy": "High",
    "PutUserPolicy": "High",
    "CreateAccessKey": "Critical",
    "DeleteTrail": "Critical",
    "UpdateAssumeRolePolicy": "High",
    "CreateUser": "Medium",
    "DeleteUser": "High",
    "AddUserToGroup": "Medium",
    "RemoveUserFromGroup": "Medium",
    "CreatePolicy": "High",
    "CreatePolicyVersion": "High",
    "SetDefaultPolicyVersion": "High",
}

def classify_action(event_name: str):
    if event_name in SENSITIVE_ACTIONS:
        return True, SENSITIVE_ACTIONS[event_name]
    return False, "Low"

def utc_hour_bucket(iso_time: str) -> str:
    # CloudTrail eventTime looks like: 2026-02-13T08:01:20Z
    dt = datetime.strptime(iso_time, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
    return dt.strftime("%Y-%m-%dT%H")  # hour bucket

def stable_incident_id(actor_arn: str, hour_bucket: str) -> str:
    base = f"{actor_arn}|{hour_bucket}"
    return hashlib.sha256(base.encode("utf-8")).hexdigest()[:20]  # short stable id

def lambda_handler(event, context):
    detail = event.get("detail", {})
    event_name = detail.get("eventName", "Unknown")
    actor_arn = detail.get("userIdentity", {}).get("arn", "Unknown")
    source_ip = detail.get("sourceIPAddress", "Unknown")
    event_time = detail.get("eventTime", datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))
    event_id = detail.get("eventID", "unknown-event-id")

    is_sensitive, severity = classify_action(event_name)

    # Ignore non-sensitive IAM calls
    if not is_sensitive:
        return {"statusCode": 200, "body": json.dumps({"message": "Non-sensitive event ignored"})}

    hour_bucket = utc_hour_bucket(event_time) if event_time.endswith("Z") else event_time[:13]
    actor_hour_key = f"{actor_arn}|{hour_bucket}"
    incident_id = stable_incident_id(actor_arn, hour_bucket)

    table = dynamodb.Table(TABLE_NAME)

    item = {
        "incidentId": incident_id,
        "eventTime": event_time,          # sort key: timeline ordering
        "eventId": event_id,              # dedup identity
        "eventName": event_name,
        "userIdentity": actor_arn,
        "sourceIPAddress": source_ip,
        "severity": severity,
        "isSensitive": True,
        "actorHourKey": actor_hour_key,
        "rawEvent": json.dumps(detail),
    }

    # Dedup safety: same eventId should not be written twice in same incident/timestamp
    # (If it does happen, we’ll just overwrite the exact same PK/SK; harmless.)
    table.put_item(Item=item)

    return {"statusCode": 200, "body": json.dumps({"message": "Sensitive incident recorded", "incidentId": incident_id})}
