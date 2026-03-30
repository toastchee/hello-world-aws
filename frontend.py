import os
import boto3

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["TABLE_NAME"])


def handler(event, context):
    result = table.scan()
    items = sorted(result["Items"], key=lambda x: x["timestamp"], reverse=True)

    rows = "".join(
        f"<tr><td>{item['name']}</td><td>{item['timestamp']}</td></tr>"
        for item in items
    )

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Greetings</title>
  <style>
    body {{ font-family: sans-serif; max-width: 600px; margin: 40px auto; padding: 0 20px; }}
    h1 {{ font-size: 1.5rem; }}
    table {{ width: 100%; border-collapse: collapse; margin-top: 20px; }}
    th {{ text-align: left; border-bottom: 2px solid #000; padding: 8px 0; }}
    td {{ padding: 8px 0; border-bottom: 1px solid #ddd; }}
  </style>
</head>
<body>
  <h1>Greetings</h1>
  <table>
    <thead><tr><th>Name</th><th>Time</th></tr></thead>
    <tbody>{rows}</tbody>
  </table>
</body>
</html>"""

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "text/html"},
        "body": html,
    }
