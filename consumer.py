import json
import os
from datetime import datetime, timezone

import boto3

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["TABLE_NAME"])


def handler(event, context):
    for record in event["Records"]:
        body = json.loads(record["body"])
        name = body.get("name", "World")

        table.put_item(Item={
            "name": name,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        })

        print(f"Saved greeting for: {name}")
