import pymongo
import csv
import random
import time
import re
from datetime import datetime, timedelta

def parse_price(price_str):
    if not price_str or price_str == "nan":
        return 0.0
    cleaned = re.sub(r"[^\d.]", "", str(price_str))
    try:
        return float(cleaned)
    except:
        return 0.0

def parse_rating(rating_str):
    try:
        return float(str(rating_str).replace(",", ".").strip())
    except:
        return 0.0

print("Waiting for MongoDB to be ready...")
client = None
for i in range(30):
    try:
        client = pymongo.MongoClient(
            "mongodb://mongodb.dissertation.svc.cluster.local:27017",
            tls=True,
            tlsCAFile="/etc/tls/ca.crt",
            tlsCertificateKeyFile="/etc/tls/mongo.pem",
            tlsAllowInvalidHostnames=True,
            serverSelectionTimeoutMS=5000
        )
        client.admin.command("ping")
        print("MongoDB is ready!")
        break
    except Exception as e:
        print(f"Attempt {i+1}/30 - MongoDB not ready: {e}")
        time.sleep(5)

if client is None:
    print("Could not connect to MongoDB")
    exit(1)

db = client.ecommerce

# Clear existing collections
db.products.drop()
db.users.drop()
db.carts.drop()
db.orders.drop()
print("Cleared existing collections")

# Load Amazon CSV using built-in csv module (no pandas needed)
print("Loading Amazon Sales Dataset...")
products = []
categories = set()

with open("/data/amazon.csv", encoding="utf-8") as f:
    reader = csv.DictReader(f)
    for row in reader:
        try:
            category = str(row.get("category", "general"))
            categories.add(category)
            products.append({
                "productId": str(row.get("product_id", "")),
                "name": str(row.get("product_name", "")),
                "category": category,
                "price": parse_price(row.get("discounted_price", "0")),
                "originalPrice": parse_price(row.get("actual_price", "0")),
                "discount": str(row.get("discount_percentage", "0%")),
                "rating": parse_rating(row.get("rating", "0")),
                "ratingCount": str(row.get("rating_count", "0")),
                "description": str(row.get("about_product", "")),
                "reviewTitle": str(row.get("review_title", "")),
                "reviewContent": str(row.get("review_content", ""))
            })
        except Exception as e:
            print(f"Skipping row: {e}")
            continue

db.products.insert_many(products)
print(f"Inserted {len(products)} real Amazon products")

categories = list(categories)
print(f"Found {len(categories)} unique categories")

# Product IDs for cart and order generation
product_ids = [p["productId"] for p in products]

# Synthetic Users
print("Generating users...")
users = []
locations = ["UK", "US", "DE", "IN", "AU", "FR", "CA", "JP"]
for i in range(500):
    users.append({
        "userId": f"user_{i}",
        "name": f"Customer {i}",
        "email": f"customer{i}@example.com",
        "profile": {
            "age": random.randint(18, 65),
            "location": random.choice(locations),
            "preferences": random.sample(
                categories[:20] if len(categories) > 20 else categories,
                k=min(2, len(categories))
            )
        }
    })
db.users.insert_many(users)
print(f"Inserted {len(users)} users")

# Synthetic Carts
print("Generating carts...")
carts = []
for i in range(300):
    cart_products = random.sample(
        product_ids,
        k=random.randint(1, min(5, len(product_ids)))
    )
    carts.append({
        "userId": f"user_{random.randint(0, 499)}",
        "products": [
            {"productId": pid, "quantity": random.randint(1, 3)}
            for pid in cart_products
        ],
        "updatedAt": datetime.now() - timedelta(hours=random.randint(1, 48))
    })
db.carts.insert_many(carts)
print(f"Inserted {len(carts)} carts")

# Synthetic Orders
print("Generating orders...")
orders = []
statuses = ["pending", "shipped", "delivered", "cancelled"]
for i in range(1000):
    order_products = random.sample(
        product_ids,
        k=random.randint(1, min(4, len(product_ids)))
    )
    orders.append({
        "orderId": f"order_{i}",
        "userId": f"user_{random.randint(0, 499)}",
        "products": [
            {"productId": pid, "quantity": random.randint(1, 2)}
            for pid in order_products
        ],
        "status": random.choice(statuses),
        "createdAt": datetime.now() - timedelta(days=random.randint(1, 365))
    })
db.orders.insert_many(orders)
print(f"Inserted {len(orders)} orders")

# Create Indexes
print("Creating indexes...")
db.products.create_index("category")
db.products.create_index("rating")
db.products.create_index("productId")
db.users.create_index("userId")
db.carts.create_index("userId")
db.orders.create_index("userId")
db.orders.create_index("createdAt")
print("Indexes created")

print("\n=== Seed Complete ===")
print(f"Products : {db.products.count_documents({})}")
print(f"Users    : {db.users.count_documents({})}")
print(f"Carts    : {db.carts.count_documents({})}")
print(f"Orders   : {db.orders.count_documents({})}")
client.close()
