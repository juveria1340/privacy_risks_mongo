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

# Real Amazon top-level categories
CATEGORIES = [
    "Computers&Accessories",
    "Electronics",
    "Home&Kitchen",
    "Car&Motorbike",
    "Health&PersonalCare",
    "OfficeProducts",
    "Toys&Games",
    "MusicalInstruments"
]

@app.route('/api/v1', methods=['GET'])
def product_browse():
    client = get_client()
    db = client.ecommerce
    category = random.choice(CATEGORIES)
    # Use regex to match category prefix
    import re
    results = list(db.products.find(
        {"category": {"$regex": f"^{re.escape(category)}", "$options": "i"}}
    ).limit(10))
    product = db.products.find_one(
        {"category": {"$regex": f"^{re.escape(category)}", "$options": "i"}}
    )
    client.close()
    return jsonify({
        "status": "ok",
        "operation": "product_browse",
        "category": category,
        "count": len(results)
    }), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
