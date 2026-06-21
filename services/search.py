from flask import Flask, jsonify
import pymongo
import random

app = Flask(__name__)

def get_client():
    return pymongo.MongoClient(
        "mongodb://mongodb.dissertation.svc.cluster.local:27017",
        tls=True,
        tlsCAFile="/etc/tls/ca.crt",
        tlsCertificateKeyFile="/etc/tls/mongo.pem",
        tlsAllowInvalidHostnames=True,
        serverSelectionTimeoutMS=5000
    )

@app.route('/api/v1', methods=['GET'])
def search():
    client = get_client()
    db = client.ecommerce
    category = random.choice(["electronics","clothing","books","home","sports"])
    results = list(db.products.aggregate([
        {"\\": {"category": category}},
        {"\\": {"_id": "\\", "avgPrice": {"\\": "\\"}, "count": {"\\": 1}}},
        {"\\": {"avgPrice": -1}}
    ]))
    client.close()
    return jsonify({"status": "ok", "operation": "search", "count": len(results)}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
