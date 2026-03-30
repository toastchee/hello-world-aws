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
    *, *::before, *::after {{ box-sizing: border-box; margin: 0; padding: 0; }}
    body {{
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background: #0f0f13;
      color: #e2e2e2;
      min-height: 100vh;
      display: flex;
      align-items: flex-start;
      justify-content: center;
      padding: 60px 20px;
    }}
    .card {{
      background: #1a1a24;
      border: 1px solid #2e2e42;
      border-radius: 16px;
      padding: 40px;
      width: 100%;
      max-width: 560px;
      box-shadow: 0 8px 40px rgba(0,0,0,0.4);
    }}
    h1 {{
      font-size: 1.6rem;
      font-weight: 700;
      letter-spacing: -0.02em;
      margin-bottom: 28px;
      background: linear-gradient(135deg, #a78bfa, #60a5fa);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }}
    form {{
      display: flex;
      gap: 10px;
      margin-bottom: 32px;
    }}
    input[type="text"] {{
      flex: 1;
      background: #0f0f13;
      border: 1px solid #2e2e42;
      border-radius: 8px;
      color: #e2e2e2;
      font-size: 0.95rem;
      padding: 10px 14px;
      outline: none;
      transition: border-color 0.2s;
    }}
    input[type="text"]:focus {{ border-color: #a78bfa; }}
    input[type="text"]::placeholder {{ color: #555570; }}
    button {{
      background: linear-gradient(135deg, #7c3aed, #2563eb);
      border: none;
      border-radius: 8px;
      color: #fff;
      cursor: pointer;
      font-size: 0.95rem;
      font-weight: 600;
      padding: 10px 20px;
      transition: opacity 0.2s;
    }}
    button:hover {{ opacity: 0.85; }}
    table {{ width: 100%; border-collapse: collapse; }}
    th {{
      text-align: left;
      font-size: 0.75rem;
      font-weight: 600;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      color: #555570;
      padding: 0 0 12px;
      border-bottom: 1px solid #2e2e42;
    }}
    td {{
      padding: 14px 0;
      border-bottom: 1px solid #1e1e2e;
      font-size: 0.92rem;
    }}
    td:last-child {{ color: #555570; font-size: 0.82rem; }}
    tr:last-child td {{ border-bottom: none; }}
  </style>
</head>
<body>
  <div class="card">
    <h1>Greetings</h1>
    <form method="POST" action="/hello">
      <input type="text" name="name" placeholder="Enter your name" required>
      <button type="submit">Greet</button>
    </form>
    <table>
      <thead><tr><th>Name</th><th>Time</th></tr></thead>
      <tbody>{rows}</tbody>
    </table>
  </div>
</body>
</html>"""

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "text/html"},
        "body": html,
    }
