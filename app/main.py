from flask import Flask
import time

import socket

app = Flask(__name__)

@app.get("/healthz")
def healthz():
    #return {"ok": True}, 200
    return {"service":"demo-app", "pod": socket.gethostname(), "ts": time.time()}, 200  

@app.get("/health")
def health():
    return {"service": "demo-app", "ts": time.time(), "ver": "beta-test-3"}, 200

@app.get("/")
def index():
    #return {"service": "demo-app", "ts": time.time()}, 200
    return {"service":"demo-app", "pod": socket.gethostname(), "ts": time.time()}, 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)