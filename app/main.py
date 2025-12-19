from flask import Flask
import time

app = Flask(__name__)

@app.get("/healthz")
def healthz():
    return {"ok": True}

@app.get("/")
def index():
    return {"service": "demo-app", "ts": time.time()}

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)