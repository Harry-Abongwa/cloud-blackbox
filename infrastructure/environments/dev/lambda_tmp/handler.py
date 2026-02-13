import json
import os
import boto3
from datetime import datetime, timedelta
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource('dynamodb')
TABLE_NAME = os.environ.get("TABLE_NAME") or os.environ.get("INCIDENT_TABLE")
table = dynamodb.Table(TABLE_NAME)

ALLOWED_SEVERITIES = {"High", "Medium", "Low"}

def error_response(msg):
    return {
        "statusCode": 400,
        "body": json.dumps({"error": msg})
    }

def lambda_handler(event, context):
    try:
        params = event.get("queryStringParameters") or {}

        severity = params.get("severity")
        if not severity:
            return error_response("severity parameter required")

        if severity not in ALLOWED_SEVERITIES:
            return error_response("Invalid severity value")

        limit = int(params.get("limit", 10))
        if limit > 50:
            limit = 50

        include_raw = params.get("includeRaw") == "true"

        from_param = params.get("from")
        if from_param:
            from_time = datetime.fromisoformat(from_param.replace("Z", "+00:00"))
        else:
            from_time = datetime.utcnow() - timedelta(hours=24)

        response = table.query(
            IndexName="severity-index",
            KeyConditionExpression=Key("severity").eq(severity),
            Limit=limit,
            ScanIndexForward=False
        )

        items = []
        for item in response.get("Items", []):
            event_time = item.get("eventTime")
            if event_time and datetime.fromisoformat(event_time.replace("Z","+00:00")) < from_time:
                continue

            filtered = {
                "incidentId": item.get("incidentId"),
                "eventName": item.get("eventName"),
                "userIdentity": item.get("userIdentity"),
                "sourceIPAddress": item.get("sourceIPAddress"),
                "eventTime": item.get("eventTime"),
                "severity": item.get("severity"),
                "isSensitive": item.get("isSensitive")
            }

            if include_raw:
                filtered["rawEvent"] = item.get("rawEvent")

            items.append(filtered)

        body = {
            "mode": "severity-index",
            "severity": severity,
            "count": len(items),
            "items": items
        }

        if "LastEvaluatedKey" in response:
            body["nextToken"] = json.dumps(response["LastEvaluatedKey"])

        return {
            "statusCode": 200,
            "body": json.dumps(body)
        }

    except Exception as e:
        print("ERROR:", str(e))
        return {
            "statusCode": 500,
            "body": json.dumps({"error": "Internal Server Error"})
        }
