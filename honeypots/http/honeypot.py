#!/usr/bin/env python3
"""
Lightweight HTTP Honeypot for Kubernetes Deception System
Emulates common web services and detects attacks
"""

import asyncio
import hashlib
import json
import logging
import os
import re
import time
from dataclasses import dataclass, asdict
from datetime import datetime
from typing import Dict, List, Optional
from urllib.parse import parse_qs, urlparse

# Configure logging
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")
logging.basicConfig(level=getattr(logging, LOG_LEVEL))
logger = logging.getLogger("http-honeypot")


@dataclass
class HTTPEvent:
    """Represents an HTTP interaction event"""
    timestamp: str
    event_type: str
    source_ip: str
    source_port: int
    method: str
    path: str
    headers: dict
    body: str = ""
    user_agent: str = ""
    attack_type: str = ""
    session_id: str = ""

    def to_json(self) -> str:
        return json.dumps(asdict(self))


# SQL Injection patterns
SQL_INJECTION_PATTERNS = [
    r"(\%27)|(\')|(\-\-)|(\%23)|(#)",
    r"((\%3D)|(=))[^\n]*((\%27)|(\')|(\-\-)|(\%3B)|(;))",
    r"\w*((\%27)|(\'))((\%6F)|o|(\%4F))((\%72)|r|(\%52))",
    r"((\%27)|(\'))union",
    r"exec(\s|\+)+(s|x)p\w+",
    r"UNION\s+SELECT",
    r"SELECT\s+.*\s+FROM",
    r"INSERT\s+INTO",
    r"DELETE\s+FROM",
    r"DROP\s+TABLE",
    r"UPDATE\s+.*\s+SET",
    r"OR\s+1\s*=\s*1",
    r"OR\s+'[^']*'\s*=\s*'[^']*'",
]

# XSS patterns
XSS_PATTERNS = [
    r"<script[^>]*>",
    r"javascript:",
    r"onerror\s*=",
    r"onload\s*=",
    r"onclick\s*=",
    r"<iframe",
    r"<img[^>]+onerror",
]

# Path traversal patterns
PATH_TRAVERSAL_PATTERNS = [
    r"\.\./",
    r"\.\.\\",
    r"/etc/passwd",
    r"/etc/shadow",
    r"c:\\windows",
    r"boot\.ini",
]

# Suspicious paths that attackers commonly probe
SUSPICIOUS_PATHS = [
    "/admin",
    "/wp-admin",
    "/wp-login.php",
    "/phpmyadmin",
    "/phpMyAdmin",
    "/.env",
    "/config.php",
    "/wp-config.php",
    "/xmlrpc.php",
    "/.git",
    "/.svn",
    "/backup",
    "/db",
    "/sql",
    "/shell",
    "/cmd",
    "/console",
    "/manager",
    "/actuator",
    "/api/v1/pods",
    "/metrics",
]


class HTTPHoneypot:
    """Lightweight HTTP Honeypot implementation"""

    def __init__(
        self,
        host: str = "0.0.0.0",
        port: int = 8080,
        max_connections: int = 100,
    ):
        self.host = host
        self.port = port
        self.max_connections = max_connections
        self.active_connections = 0
        self.events: List[HTTPEvent] = []

        # Compile regex patterns
        self.sql_patterns = [re.compile(p, re.IGNORECASE) for p in SQL_INJECTION_PATTERNS]
        self.xss_patterns = [re.compile(p, re.IGNORECASE) for p in XSS_PATTERNS]
        self.path_patterns = [re.compile(p, re.IGNORECASE) for p in PATH_TRAVERSAL_PATTERNS]

        # Fake service responses
        self.fake_services = self._load_fake_services()

        # Metrics
        self.total_requests = 0
        self.attacks_detected = 0

    def _load_fake_services(self) -> Dict[str, bytes]:
        """Load fake service responses"""
        return {
            "/": self._build_response(200, "OK", self._get_index_page()),
            "/health": self._build_response(200, "OK", '{"status": "healthy"}'),
            "/ready": self._build_response(200, "OK", '{"ready": true}'),
            "/robots.txt": self._build_response(200, "OK", "User-agent: *\nDisallow: /admin\nDisallow: /api"),
            "/admin": self._build_response(401, "Unauthorized", self._get_login_page()),
            "/wp-admin": self._build_response(200, "OK", self._get_wordpress_admin()),
            "/phpmyadmin": self._build_response(200, "OK", self._get_phpmyadmin_page()),
            "/api": self._build_response(200, "OK", '{"version": "1.0", "endpoints": ["/users", "/products"]}'),
        }

    async def start(self):
        """Start the HTTP honeypot server"""
        server = await asyncio.start_server(
            self.handle_connection,
            self.host,
            self.port,
            limit=1024 * 128,  # 128KB buffer
        )

        addr = server.sockets[0].getsockname()
        logger.info(json.dumps({
            "event": "server_started",
            "host": addr[0],
            "port": addr[1],
        }))

        async with server:
            await server.serve_forever()

    async def handle_connection(
        self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter
    ):
        """Handle incoming HTTP connection"""
        addr = writer.get_extra_info("peername")
        client_ip, client_port = addr[0], addr[1]

        if self.active_connections >= self.max_connections:
            writer.close()
            await writer.wait_closed()
            return

        self.active_connections += 1
        session_id = hashlib.sha256(f"{client_ip}:{client_port}:{time.time()}".encode()).hexdigest()[:16]

        try:
            # Read request
            request_data = await asyncio.wait_for(reader.read(8192), timeout=30.0)
            if not request_data:
                return

            # Parse request
            request = self.parse_request(request_data.decode("utf-8", errors="ignore"))
            if not request:
                return

            self.total_requests += 1
            method, path, headers, body = request

            # Detect attacks
            attack_type = self.detect_attack(path, headers, body)

            # Log event
            event = HTTPEvent(
                timestamp=datetime.utcnow().isoformat(),
                event_type="http_request",
                source_ip=client_ip,
                source_port=client_port,
                method=method,
                path=path,
                headers=headers,
                body=body[:1000],  # Truncate body
                user_agent=headers.get("User-Agent", ""),
                attack_type=attack_type,
                session_id=session_id,
            )

            log_data = {
                "event": "http_request",
                "session_id": session_id,
                "method": method,
                "path": path,
                "source_ip": client_ip,
                "user_agent": headers.get("User-Agent", "")[:100],
            }

            if attack_type:
                log_data["attack_type"] = attack_type
                self.attacks_detected += 1
                logger.warning(json.dumps(log_data))
            else:
                logger.info(json.dumps(log_data))

            self.events.append(event)

            # Send response
            response = self.get_response(path, method, headers)
            writer.write(response)
            await writer.drain()

        except asyncio.TimeoutError:
            pass
        except Exception as e:
            logger.error(json.dumps({"event": "error", "error": str(e)}))
        finally:
            self.active_connections -= 1
            writer.close()
            try:
                await writer.wait_closed()
            except Exception:
                pass

    def parse_request(self, data: str) -> Optional[tuple]:
        """Parse HTTP request"""
        try:
            lines = data.split("\r\n")
            if not lines:
                return None

            # Parse request line
            request_line = lines[0].split(" ")
            if len(request_line) < 2:
                return None

            method = request_line[0]
            path = request_line[1]

            # Parse headers
            headers = {}
            body_start = 0
            for i, line in enumerate(lines[1:], 1):
                if line == "":
                    body_start = i + 1
                    break
                if ": " in line:
                    key, value = line.split(": ", 1)
                    headers[key] = value

            # Get body
            body = "\r\n".join(lines[body_start:]) if body_start < len(lines) else ""

            return (method, path, headers, body)

        except Exception:
            return None

    def detect_attack(self, path: str, headers: dict, body: str) -> str:
        """Detect various attack types"""
        full_input = f"{path} {body} {' '.join(headers.values())}"

        # Check SQL injection
        for pattern in self.sql_patterns:
            if pattern.search(full_input):
                return "sql_injection"

        # Check XSS
        for pattern in self.xss_patterns:
            if pattern.search(full_input):
                return "xss"

        # Check path traversal
        for pattern in self.path_patterns:
            if pattern.search(path):
                return "path_traversal"

        # Check suspicious paths
        parsed_path = urlparse(path).path.lower()
        for suspicious in SUSPICIOUS_PATHS:
            if suspicious.lower() in parsed_path:
                return "reconnaissance"

        return ""

    def get_response(self, path: str, method: str, headers: dict) -> bytes:
        """Get appropriate response for request"""
        parsed_path = urlparse(path).path

        # Check for exact match
        if parsed_path in self.fake_services:
            return self.fake_services[parsed_path]

        # Check for prefix match
        for service_path in self.fake_services:
            if parsed_path.startswith(service_path) and service_path != "/":
                return self.fake_services[service_path]

        # Default 404 response
        return self._build_response(404, "Not Found", "<html><body><h1>404 Not Found</h1></body></html>")

    def _build_response(self, status_code: int, status_text: str, body: str) -> bytes:
        """Build HTTP response"""
        content_type = "application/json" if body.startswith("{") else "text/html"
        response = f"HTTP/1.1 {status_code} {status_text}\r\n"
        response += f"Content-Type: {content_type}\r\n"
        response += f"Content-Length: {len(body)}\r\n"
        response += "Server: Apache/2.4.41 (Ubuntu)\r\n"
        response += "Connection: close\r\n"
        response += "\r\n"
        response += body
        return response.encode()

    def _get_index_page(self) -> str:
        return """<!DOCTYPE html>
<html><head><title>Welcome</title></head>
<body><h1>Welcome to our service</h1><p>Please log in to continue.</p></body></html>"""

    def _get_login_page(self) -> str:
        return """<!DOCTYPE html>
<html><head><title>Admin Login</title></head>
<body><h1>Admin Login</h1>
<form method="post"><input name="user" placeholder="Username"><input name="pass" type="password"><button>Login</button></form></body></html>"""

    def _get_wordpress_admin(self) -> str:
        return """<!DOCTYPE html>
<html><head><title>WordPress &rsaquo; Log In</title></head>
<body class="login"><div id="login">
<h1><a href="https://wordpress.org/">WordPress</a></h1>
<form method="post"><p><label>Username<input name="log" type="text"></label></p>
<p><label>Password<input name="pwd" type="password"></label></p>
<p><input type="submit" value="Log In"></p></form></div></body></html>"""

    def _get_phpmyadmin_page(self) -> str:
        return """<!DOCTYPE html>
<html><head><title>phpMyAdmin</title></head>
<body><div id="pma_header"><h1>phpMyAdmin</h1></div>
<form method="post"><input name="pma_username" placeholder="Username">
<input name="pma_password" type="password"><button>Go</button></form></body></html>"""

    def get_metrics(self) -> dict:
        """Return current metrics"""
        return {
            "total_requests": self.total_requests,
            "active_connections": self.active_connections,
            "attacks_detected": self.attacks_detected,
        }


async def main():
    """Main entry point"""
    host = os.getenv("HOST", "0.0.0.0")
    port_str = os.getenv("HONEYPOT_PORT", "8080")
    if port_str.startswith("tcp://"):
        port = 8080
    else:
        port = int(port_str)
    max_connections = int(os.getenv("MAX_CONNECTIONS", "100"))

    honeypot = HTTPHoneypot(
        host=host,
        port=port,
        max_connections=max_connections,
    )

    await honeypot.start()


if __name__ == "__main__":
    asyncio.run(main())
