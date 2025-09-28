"""
A sample backend server. Saves and retrieves entries using mongodb
"""
import os
import time
from flask import Flask, jsonify, request, Response
from flask_pymongo import PyMongo
import bleach

# ---- Observability (Prometheus) --------------------------------------------
from prometheus_client import (
    Counter, generate_latest, CONTENT_TYPE_LATEST,
    CollectorRegistry, ProcessCollector, PlatformCollector, GCCollector,
)

registry = CollectorRegistry()
# default process/platform/GC collectors
ProcessCollector(registry=registry)
PlatformCollector(registry=registry)
GCCollector(registry=registry)

HTTP_REQUESTS = Counter(
    "http_requests_total",
    "Total HTTP requests",
    ["method", "endpoint", "code", "job"],
    registry=registry,
)

# ---- App -------------------------------------------------------------------
app = Flask(__name__)

# Mongo config (safe if env absent for local sanity — we just won't call /messages)
mongo_uri = os.environ.get("GUESTBOOK_DB_ADDR")
if mongo_uri:
    app.config["MONGO_URI"] = f"mongodb://{mongo_uri}/guestbook"
    mongo = PyMongo(app)
else:
    mongo = None  # ok for local sanity when DB not present

# ---- Routes ----------------------------------------------------------------

@app.after_request
def after_request(resp):
    try:
        HTTP_REQUESTS.labels(
            method=request.method,
            endpoint=request.path,
            code=resp.status_code,
            job="backend",
        ).inc()
    except Exception:
        pass
    return resp

@app.route("/api/healthz", methods=["GET"])
def healthz():
    return ("ok", 200)

@app.route("/api/readyz", methods=["GET"])
def readyz():
    # in a real check, verify DB health; for now just say ready
    return ("ok", 200)

@app.route("/api/metrics", methods=["GET"])
def metrics():
    return Response(generate_latest(registry), mimetype=CONTENT_TYPE_LATEST)

@app.route("/api/fail", methods=["GET"])
def fail():
    # forced 500 to test alerts
    return ("boom", 500)

# Data endpoints (use only if Mongo is configured/running)
@app.route("/api/messages", methods=["GET"])
def get_messages():
    if not mongo:
        return jsonify({"error": "DB not configured"}), 503
    field_mask = {"author": 1, "message": 1, "date": 1, "_id": 0}
    msg_list = list(mongo.db.messages.find({}, field_mask).sort("_id", -1))
    return jsonify(msg_list), 200

@app.route("/api/messages", methods=["POST"])
def add_message():
    if not mongo:
        return jsonify({"error": "DB not configured"}), 503
    raw_data = request.get_json() or {}
    msg_data = {
        "author": bleach.clean(raw_data.get("author", "")),
        "message": bleach.clean(raw_data.get("message", "")),
        "date": time.time(),
    }
    mongo.db.messages.insert_one(msg_data)
    return jsonify({}), 201

# ---- Main ------------------------------------------------------------------
if __name__ == "__main__":
    # allow local run without enforcing envs (k8s will set them)
    port = int(os.environ.get("PORT", "8080"))
    print("BACKEND starting… file:", __file__)
    print("Routes:", [str(r) for r in app.url_map.iter_rules()])
    app.run(debug=False, host="0.0.0.0", port=port)
