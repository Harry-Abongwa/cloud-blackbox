import json
import os
import boto3
import base64
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource("dynamodb")
TABLE_NAME = os.environ.get("INCIDENT_TABLE")
table = dynamodb.Table(TABLE_NAME)


def lambda_handler(event, context):
    try:
        params = event.get("queryStringParameters") or {}
        severity = params.get("severity")
        include_raw = params.get("includeRaw", "false").lower() == "true"
        limit = int(params.get("limit", 10))
        from_time = params.get("from")
        next_token = params.get("nextToken")

        if not severity:
            return response(400, {"error": "severity parameter required"})

        query_args = {
            "IndexName": "severity-index",
            "KeyConditionExpression": Key("severity").eq(severity),
            "Limit": limit,
            "ScanIndexForward": False,
        }

        if from_time:
            query_args["KeyConditionExpression"] = (
                Key("severity").eq(severity) &
                Key("eventTime").gte(from_time)
            )

        if next_token:
            decoded = json.loads(base64.b64decode(next_token))
            query_args["ExclusiveStartKey"] = decoded

        result = table.query(**query_args)

        items = []
        for item in result.get("Items", []):
            clean = {
                "incidentId": item.get("incidentId"),
                "eventName": item.get("eventName"),
                "userIdentity": item.get("userIdentity"),
                "sourceIPAddress": item.get("sourceIPAddress"),
                "eventTime": item.get("eventTime"),
                "severity": item.get("severity"),
                "isSensitive": item.get("isSensitive"),
            }

            if include_raw:
                clean["rawEvent"] = item.get("rawEvent")

            items.append(clean)

        response_body = {
            "mode": "severity-index",
            "severity": severity,
            "count": len(items),
            "items": items,
        }

        if "LastEvaluatedKey" in result:
            response_body["nextToken"] = base64.b64encode(
                json.dumps(result["LastEvaluatedKey"]).encode()
            ).decode()

        return response(200, response_body)

    except Exception as e:
        return response(500, {"error": str(e)})


def response(status, body):
    return {
        "statusCode": status,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps(body),
    }
