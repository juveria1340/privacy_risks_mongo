from flask import Flask, jsonify
import pymongo

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
def health():
    client = get_client()
    result = client.admin.command("ping")
    client.close()
    return jsonify({"status": "ok", "operation": "health", "ping": result}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
