import pymongo
import random
import time
from datetime import datetime, timedelta

# Wait for MongoDB to be ready
print("Waiting for MongoDB to be ready...")
client = None
for i in range(30):
    try:
        client = pymongo.MongoClient(
            "mongodb://mongodb.dissertation.svc.cluster.local:27017",
            tls=True,
            tlsCAFile="/etc/tls/ca.crt",
            tlsAllowInvalidHostnames=True,
            serverSelectionTimeoutMS=5000
        )
        client.admin.command("ping")
        print("MongoDB is ready!")
        break
    except Exception as e:
        print(f"Attempt {i+1}/30 - MongoDB not ready yet: {e}")
        time.sleep(5)

if client is None:
    print("Could not connect to MongoDB after 30 attempts")
    exit(1)

db = client.ecommerce

# Clear existing data
db.products.drop()
db.users.drop()
db.carts.drop()
db.orders.drop()
print("Cleared existing collections")

# Seed Products
categories = ["electronics", "clothing", "books", "home", "sports"]
brands = ["BrandA", "BrandB", "BrandC", "BrandD", "BrandE"]
tags_pool = ["sale", "new", "popular", "trending", "limited"]

products = []
for i in range(200):
    products.append({
        "productId": f"prod_{i}",
        "name": f"Product {i}",
        "brand": random.choice(brands),
        "category": random.choice(categories),
        "price": round(random.uniform(5.0, 500.0), 2),
        "tags": random.sample(tags_pool, k=random.randint(1, 3)),
        "stock": random.randint(0, 100),
        "rating": round(random.uniform(1.0, 5.0), 1)
    })
db.products.insert_many(products)
print(f"Inserted {len(products)} products")

# Seed Users
users = []
for i in range(100):
    users.append({
        "userId": f"user_{i}",
        "name": f"User {i}",
        "email": f"user{i}@example.com",
        "profile": {
            "age": random.randint(18, 65),
            "location": random.choice(["UK", "US", "DE", "FR", "AU"]),
            "preferences": random.sample(categories, k=2)
        }
    })
db.users.insert_many(users)
print(f"Inserted {len(users)} users")

# Seed Carts
carts = []
for i in range(80):
    cart_products = random.sample([f"prod_{j}" for j in range(200)], k=random.randint(1, 5))
    carts.append({
        "userId": f"user_{i}",
        "products": [
            {"productId": pid, "quantity": random.randint(1, 3)}
            for pid in cart_products
        ],
        "updatedAt": datetime.now() - timedelta(hours=random.randint(1, 48))
    })
db.carts.insert_many(carts)
print(f"Inserted {len(carts)} carts")

# Seed Orders
orders = []
for i in range(150):
    order_products = random.sample([f"prod_{j}" for j in range(200)], k=random.randint(1, 4))
    orders.append({
        "orderId": f"order_{i}",
        "userId": f"user_{random.randint(0, 99)}",
        "products": [
            {"productId": pid, "quantity": random.randint(1, 2),
             "price": round(random.uniform(5.0, 500.0), 2)}
            for pid in order_products
        ],
        "totalAmount": round(random.uniform(10.0, 1000.0), 2),
        "status": random.choice(["pending", "shipped", "delivered"]),
        "createdAt": datetime.now() - timedelta(days=random.randint(1, 30))
    })
db.orders.insert_many(orders)
print(f"Inserted {len(orders)} orders")

# Create Indexes
db.products.create_index("category")
db.products.create_index("tags")
db.users.create_index("userId")
db.carts.create_index("userId")
db.orders.create_index("userId")
db.orders.create_index("createdAt")
print("Indexes created")

print("\n=== Seed Complete ===")
print(f"Products:  {db.products.count_documents({})}")
print(f"Users:     {db.users.count_documents({})}")
print(f"Carts:     {db.carts.count_documents({})}")
print(f"Orders:    {db.orders.count_documents({})}")
client.close()
