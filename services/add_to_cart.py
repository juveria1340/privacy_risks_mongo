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
def add_to_cart():
    client = get_client()
    db = client.ecommerce
    user_id = f"user_{random.randint(0, 99)}"
    product_id = f"prod_{random.randint(0, 199)}"
    db.carts.update_one(
        {"userId": user_id},
        {"\\": {"products": {"productId": product_id, "quantity": 1}}},
        upsert=True
    )
    client.close()
    return jsonify({"status": "ok", "operation": "add_to_cart"}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
