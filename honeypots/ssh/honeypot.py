#!/usr/bin/env python3
"""
Lightweight SSH Honeypot for Kubernetes Deception System
Minimal dependencies, optimized for low memory usage
"""

import asyncio
import hashlib
import json
import logging
import os
import socket
import struct
import time
from dataclasses import dataclass, asdict
from datetime import datetime
from typing import Optional

# Configure logging
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")
LOG_FORMAT = os.getenv("LOG_FORMAT", "json")

logging.basicConfig(
    level=getattr(logging, LOG_LEVEL),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s' if LOG_FORMAT != "json" else '%(message)s'
)
logger = logging.getLogger("ssh-honeypot")


@dataclass
class SSHEvent:
    """Represents an SSH interaction event"""
    timestamp: str
    event_type: str
    source_ip: str
    source_port: int
    username: str
    password: str = ""
    command: str = ""
    session_id: str = ""
    success: bool = False

    def to_json(self) -> str:
        return json.dumps(asdict(self))


class SSHHoneypot:
    """Lightweight SSH Honeypot implementation"""

    # SSH protocol constants
    SSH_MSG_KEXINIT = 20
    SSH_MSG_USERAUTH_REQUEST = 50
    SSH_MSG_CHANNEL_REQUEST = 98

    def __init__(
        self,
        host: str = "0.0.0.0",
        port: int = 2222,
        max_connections: int = 50,
        ban_time: int = 300,
    ):
        self.host = host
        self.port = port
        self.max_connections = max_connections
        self.ban_time = ban_time
        self.active_connections = 0
        self.banned_ips: dict = {}
        self.events: list = []

        # SSH server identification
        self.server_version = b"SSH-2.0-OpenSSH_8.9p1 Ubuntu-3ubuntu0.1\r\n"

        # Metrics
        self.total_connections = 0
        self.failed_logins = 0
        self.successful_logins = 0

    async def start(self):
        """Start the SSH honeypot server"""
        server = await asyncio.start_server(
            self.handle_connection,
            self.host,
            self.port,
            limit=1024 * 64,  # 64KB buffer limit for memory efficiency
        )

        addr = server.sockets[0].getsockname()
        logger.info(json.dumps({
            "event": "server_started",
            "host": addr[0],
            "port": addr[1],
            "max_connections": self.max_connections,
        }))

        async with server:
            await server.serve_forever()

    async def handle_connection(
        self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter
    ):
        """Handle incoming SSH connection"""
        addr = writer.get_extra_info("peername")
        client_ip, client_port = addr[0], addr[1]

        # Check if IP is banned
        if self.is_banned(client_ip):
            writer.close()
            await writer.wait_closed()
            return

        # Check connection limit
        if self.active_connections >= self.max_connections:
            writer.close()
            await writer.wait_closed()
            return

        self.active_connections += 1
        self.total_connections += 1
        session_id = self.generate_session_id(client_ip, client_port)

        logger.info(json.dumps({
            "event": "connection_opened",
            "session_id": session_id,
            "source_ip": client_ip,
            "source_port": client_port,
        }))

        try:
            # Send server version
            writer.write(self.server_version)
            await writer.drain()

            # Receive client version
            client_version = await asyncio.wait_for(
                reader.readline(), timeout=30.0
            )
            client_version = client_version.decode("utf-8", errors="ignore").strip()

            logger.info(json.dumps({
                "event": "client_version",
                "session_id": session_id,
                "version": client_version,
            }))

            # Simulate SSH handshake
            await self.simulate_handshake(reader, writer, session_id, client_ip, client_port)

        except asyncio.TimeoutError:
            logger.debug(json.dumps({
                "event": "timeout",
                "session_id": session_id,
            }))
        except ConnectionResetError:
            logger.debug(json.dumps({
                "event": "connection_reset",
                "session_id": session_id,
            }))
        except Exception as e:
            logger.error(json.dumps({
                "event": "error",
                "session_id": session_id,
                "error": str(e),
            }))
        finally:
            self.active_connections -= 1
            writer.close()
            try:
                await writer.wait_closed()
            except Exception:
                pass

            logger.info(json.dumps({
                "event": "connection_closed",
                "session_id": session_id,
            }))

    async def simulate_handshake(
        self,
        reader: asyncio.StreamReader,
        writer: asyncio.StreamWriter,
        session_id: str,
        client_ip: str,
        client_port: int,
    ):
        """Simulate SSH key exchange and authentication"""
        # Send key exchange init
        kexinit = self.build_kexinit()
        writer.write(kexinit)
        await writer.drain()

        # Wait for auth attempts
        login_attempts = 0
        max_attempts = 3

        while login_attempts < max_attempts:
            try:
                data = await asyncio.wait_for(reader.read(4096), timeout=60.0)
                if not data:
                    break

                # Parse authentication attempts
                auth_info = self.parse_auth_packet(data)
                if auth_info:
                    username, password = auth_info

                    event = SSHEvent(
                        timestamp=datetime.utcnow().isoformat(),
                        event_type="ssh_login_attempt",
                        source_ip=client_ip,
                        source_port=client_port,
                        username=username,
                        password=password,
                        session_id=session_id,
                        success=False,
                    )

                    logger.warning(json.dumps({
                        "event": "login_attempt",
                        "session_id": session_id,
                        "username": username,
                        "password_hash": hashlib.sha256(password.encode()).hexdigest()[:16],
                        "attempt": login_attempts + 1,
                    }))

                    self.events.append(event)
                    self.failed_logins += 1
                    login_attempts += 1

                    # Send auth failure
                    writer.write(self.build_auth_failure())
                    await writer.drain()

            except asyncio.TimeoutError:
                break

        # Ban IP after max attempts
        if login_attempts >= max_attempts:
            self.ban_ip(client_ip)

    def build_kexinit(self) -> bytes:
        """Build SSH_MSG_KEXINIT packet"""
        # Simplified KEXINIT message
        cookie = os.urandom(16)
        kex_algorithms = b"curve25519-sha256,ecdh-sha2-nistp256"
        host_key_algorithms = b"ssh-ed25519,ssh-rsa"
        encryption = b"aes256-ctr,aes128-ctr"
        mac = b"hmac-sha2-256,hmac-sha1"
        compression = b"none"
        languages = b""

        payload = bytearray()
        payload.append(self.SSH_MSG_KEXINIT)
        payload.extend(cookie)

        for algo in [kex_algorithms, host_key_algorithms, encryption, encryption, mac, mac, compression, compression, languages, languages]:
            payload.extend(struct.pack(">I", len(algo)))
            payload.extend(algo)

        payload.extend(b"\x00")  # first_kex_packet_follows
        payload.extend(b"\x00\x00\x00\x00")  # reserved

        # Wrap in packet
        packet_len = len(payload) + 1  # +1 for padding length
        padding_len = 8 - ((packet_len + 4) % 8)
        if padding_len < 4:
            padding_len += 8

        result = struct.pack(">I", packet_len + padding_len)
        result += struct.pack("B", padding_len)
        result += bytes(payload)
        result += os.urandom(padding_len)

        return result

    def build_auth_failure(self) -> bytes:
        """Build SSH authentication failure response"""
        # SSH_MSG_USERAUTH_FAILURE
        payload = bytearray()
        payload.append(51)  # SSH_MSG_USERAUTH_FAILURE
        payload.extend(struct.pack(">I", 17))
        payload.extend(b"password,keyboard")
        payload.append(0)  # partial success = false

        packet_len = len(payload) + 1
        padding_len = 8 - ((packet_len + 4) % 8)
        if padding_len < 4:
            padding_len += 8

        result = struct.pack(">I", packet_len + padding_len)
        result += struct.pack("B", padding_len)
        result += bytes(payload)
        result += os.urandom(padding_len)

        return result

    def parse_auth_packet(self, data: bytes) -> Optional[tuple]:
        """Extract username and password from auth packet"""
        try:
            # Look for username pattern in raw data
            # This is a simplified parser - real implementation would be more complex
            text = data.decode("utf-8", errors="ignore")

            # Simple heuristic: look for null-separated strings
            parts = text.split("\x00")
            username = ""
            password = ""

            for i, part in enumerate(parts):
                if part and len(part) < 64:
                    if not username and part.isalnum():
                        username = part
                    elif username and not password:
                        password = part

            if username:
                return (username, password)

        except Exception:
            pass

        return None

    def generate_session_id(self, ip: str, port: int) -> str:
        """Generate unique session ID"""
        data = f"{ip}:{port}:{time.time()}"
        return hashlib.sha256(data.encode()).hexdigest()[:16]

    def is_banned(self, ip: str) -> bool:
        """Check if IP is currently banned"""
        if ip in self.banned_ips:
            if time.time() < self.banned_ips[ip]:
                return True
            del self.banned_ips[ip]
        return False

    def ban_ip(self, ip: str):
        """Ban an IP address"""
        self.banned_ips[ip] = time.time() + self.ban_time
        logger.warning(json.dumps({
            "event": "ip_banned",
            "ip": ip,
            "duration": self.ban_time,
        }))

    def get_metrics(self) -> dict:
        """Return current metrics"""
        return {
            "total_connections": self.total_connections,
            "active_connections": self.active_connections,
            "failed_logins": self.failed_logins,
            "successful_logins": self.successful_logins,
            "banned_ips": len(self.banned_ips),
        }


async def main():
    """Main entry point"""
    host = os.getenv("HOST", "0.0.0.0")
    # Use PORT env var, avoiding K8s service injection conflicts
    port_str = os.getenv("HONEYPOT_PORT", "2222")
    # Handle case where K8s injects tcp://... format
    if port_str.startswith("tcp://"):
        port = 2222
    else:
        port = int(port_str)
    max_connections = int(os.getenv("MAX_CONNECTIONS", "50"))
    ban_time = int(os.getenv("BAN_TIME", "300"))

    honeypot = SSHHoneypot(
        host=host,
        port=port,
        max_connections=max_connections,
        ban_time=ban_time,
    )

    await honeypot.start()


if __name__ == "__main__":
    asyncio.run(main())
