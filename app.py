from flask import Flask, jsonify, request
from prometheus_client import Counter, generate_latest, CONTENT_TYPE_LATEST
import psycopg2
import os
import requests

app = Flask(__name__)

# Prometheus metrics
REQUEST_COUNT = Counter('healthletic_requests_total', 'Total HTTP Requests', ['endpoint'])

DB_HOST = os.getenv('DB_HOST', 'db')
DB_USER = os.getenv('DB_USER', 'postgres')
DB_PASS = os.getenv('DB_PASS', 'password')
DB_NAME = os.getenv('DB_NAME', 'healthletic')
DB_PORT = int(os.getenv('DB_PORT', 5432))

def db_connect():
    conn = psycopg2.connect(host=DB_HOST, user=DB_USER, password=DB_PASS, dbname=DB_NAME, port=DB_PORT)
    return conn

@app.route('/health', methods=['GET'])
def health():
    REQUEST_COUNT.labels(endpoint='/health').inc()
    return jsonify({"status": "healthy"}), 200

@app.route('/db', methods=['GET'])
def check_db():
    REQUEST_COUNT.labels(endpoint='/db').inc()
    try:
        conn = db_connect()
        cur = conn.cursor()
        cur.execute('SELECT 1')
        cur.fetchone()
        cur.close()
        conn.close()
        return jsonify({"db": "connected"}), 200
    except Exception as e:
        return jsonify({"db_error": str(e)}), 500

@app.route('/echo', methods=['POST'])
def echo():
    REQUEST_COUNT.labels(endpoint='/echo').inc()
    data = request.get_json(silent=True) or {}
    return jsonify({"you_sent": data}), 200

@app.route('/metrics', methods=['GET'])
def metrics():
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

@app.route('/', methods=['GET'])
def home():
    REQUEST_COUNT.labels(endpoint='/').inc()
    return jsonify({"message": "Healthletic Backend Running"}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
