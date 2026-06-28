from flask import Flask, jsonify
import pymongo
import random
import re

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

CATEGORIES = [
    "Computers&Accessories",
    "Electronics",
    "Home&Kitchen",
    "Car&Motorbike",
    "Health&PersonalCare"
]

@app.route('/api/v1', methods=['GET'])
def search():
    client = get_client()
    db = client.ecommerce
    category = random.choice(CATEGORIES)
    results = list(db.products.aggregate([
        {"$match": {"category": {"$regex": f"^{re.escape(category)}", "$options": "i"}}},
        {"$group": {
            "_id": "$category",
            "avgPrice": {"$avg": "$price"},
            "count": {"$sum": 1},
            "avgRating": {"$avg": "$rating"}
        }},
        {"$sort": {"avgRating": -1}},
        {"$limit": 10}
    ]))
    client.close()
    return jsonify({
        "status": "ok",
        "operation": "search",
        "category": category,
        "count": len(results)
    }), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
