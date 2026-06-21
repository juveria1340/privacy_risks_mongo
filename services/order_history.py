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
def order_history():
    client = get_client()
    db = client.ecommerce
    user_id = f"user_{random.randint(0, 99)}"
    orders = list(db.orders.find(
        {"userId": user_id}
    ).sort("createdAt", -1).limit(10))
    client.close()
    return jsonify({"status": "ok", "operation": "order_history", "count": len(orders)}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
