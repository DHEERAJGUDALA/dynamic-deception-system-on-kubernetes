#!/usr/bin/env python3
"""
Lightweight E-commerce API for Deception Demo
Provides fake endpoints that look like real e-commerce APIs
"""

import json
import os
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("ecommerce-api")


# Fake product database
PRODUCTS = [
    {"id": 1, "name": "Laptop Pro", "price": 999.99, "stock": 50},
    {"id": 2, "name": "Smartphone X", "price": 699.99, "stock": 100},
    {"id": 3, "name": "Tablet Air", "price": 499.99, "stock": 75},
    {"id": 4, "name": "Wireless Earbuds", "price": 149.99, "stock": 200},
]

# Fake user database (decoy credentials)
USERS = {
    "admin": "admin123",
    "user": "password",
    "test": "test123",
}


class APIHandler(BaseHTTPRequestHandler):
    """Handle API requests"""

    def log_message(self, format, *args):
        logger.info(json.dumps({
            "event": "request",
            "client": self.client_address[0],
            "method": self.command,
            "path": self.path,
        }))

    def send_json(self, data, status=200):
        """Send JSON response"""
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

    def do_GET(self):
        """Handle GET requests"""
        parsed = urlparse(self.path)
        path = parsed.path
        query = parse_qs(parsed.query)

        if path == "/api/products":
            self.send_json({"products": PRODUCTS})

        elif path.startswith("/api/products/"):
            try:
                product_id = int(path.split("/")[-1])
                product = next((p for p in PRODUCTS if p["id"] == product_id), None)
                if product:
                    self.send_json(product)
                else:
                    self.send_json({"error": "Product not found"}, 404)
            except ValueError:
                self.send_json({"error": "Invalid product ID"}, 400)

        elif path == "/api/health":
            self.send_json({"status": "healthy"})

        elif path == "/api/config":
            # Honeypot: Fake config endpoint
            logger.warning(json.dumps({
                "event": "suspicious_access",
                "path": path,
                "client": self.client_address[0],
            }))
            self.send_json({
                "db_host": "db.internal.local",
                "db_user": "app_user",
                "db_name": "ecommerce",
                "api_key": "sk-fake-api-key-12345",
            })

        else:
            self.send_json({"error": "Not found"}, 404)

    def do_POST(self):
        """Handle POST requests"""
        parsed = urlparse(self.path)
        path = parsed.path

        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length).decode() if content_length else ""

        if path == "/api/login":
            try:
                data = json.loads(body) if body.startswith("{") else {}
                # Parse form data
                if not data and body:
                    pairs = body.split("&")
                    data = {}
                    for pair in pairs:
                        if "=" in pair:
                            k, v = pair.split("=", 1)
                            data[k] = v

                username = data.get("username", "")
                password = data.get("password", "")

                logger.warning(json.dumps({
                    "event": "login_attempt",
                    "username": username,
                    "client": self.client_address[0],
                }))

                # Always fail but log the attempt
                self.send_json({"error": "Invalid credentials"}, 401)

            except Exception as e:
                self.send_json({"error": str(e)}, 400)

        elif path == "/api/search":
            # Honeypot: SQL injection detection point
            try:
                data = json.loads(body) if body else {}
                query = data.get("q", "")

                # Log search query (potential SQL injection)
                logger.info(json.dumps({
                    "event": "search",
                    "query": query[:200],
                    "client": self.client_address[0],
                }))

                # Check for SQL injection patterns
                sql_patterns = ["union", "select", "drop", "delete", "--", "or 1=1"]
                if any(p in query.lower() for p in sql_patterns):
                    logger.warning(json.dumps({
                        "event": "sql_injection_attempt",
                        "query": query[:200],
                        "client": self.client_address[0],
                    }))

                self.send_json({"results": []})

            except Exception as e:
                self.send_json({"error": str(e)}, 400)

        else:
            self.send_json({"error": "Not found"}, 404)


def main():
    port = int(os.getenv("PORT", "8081"))
    server = HTTPServer(("0.0.0.0", port), APIHandler)
    logger.info(f"Starting API server on port {port}")
    server.serve_forever()


if __name__ == "__main__":
    main()
