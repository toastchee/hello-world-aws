import json
import os
import boto3

sqs = boto3.client("sqs")
QUEUE_URL = os.environ["QUEUE_URL"]


def handler(event, context):
    params = event.get("queryStringParameters") or {}
    name = params.get("name")

    if not name and event.get("body"):
        body = event["body"]
        if event.get("isBase64Encoded"):
            import base64
            body = base64.b64decode(body).decode()
        for part in body.split("&"):
            if part.startswith("name="):
                name = part[len("name="):].replace("+", " ")
                break

    name = name or "World"

    sqs.send_message(
        QueueUrl=QUEUE_URL,
        MessageBody=json.dumps({"name": name})
    )

    return {
        "statusCode": 302,
        "headers": {"Location": "/"},
    }
