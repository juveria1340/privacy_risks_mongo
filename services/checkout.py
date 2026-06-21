from flask import Flask, jsonify
import pymongo
import random
from datetime import datetime

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
def checkout():
    client = get_client()
    db = client.ecommerce
    user_id = f"user_{random.randint(0, 99)}"
    order_id = f"order_{random.randint(1000, 9999)}"
    products = [{"productId": f"prod_{random.randint(0,199)}", "quantity": random.randint(1,3), "price": round(random.uniform(5.0, 500.0), 2)} for _ in range(random.randint(1,4))]
    db.orders.insert_one({
        "orderId": order_id,
        "userId": user_id,
        "products": products,
        "totalAmount": round(sum(p["price"] for p in products), 2),
        "status": "pending",
        "createdAt": datetime.now()
    })
    db.carts.delete_one({"userId": user_id})
    client.close()
    return jsonify({"status": "ok", "operation": "checkout", "orderId": order_id}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
