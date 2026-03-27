import json
import os
import boto3

sqs = boto3.client("sqs")
QUEUE_URL = os.environ["QUEUE_URL"]


def handler(event, context):
    params = event.get("queryStringParameters") or {}
    name = params.get("name", "World")

    sqs.send_message(
        QueueUrl=QUEUE_URL,
        MessageBody=json.dumps({"name": name})
    )

    return {
        "statusCode": 200,
        "body": json.dumps({"message": f"Hola, {name}!", "queued": True})
    }
