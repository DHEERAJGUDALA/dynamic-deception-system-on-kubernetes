#!/usr/bin/env python3
"""
Lightweight Database Honeypot for Kubernetes Deception System
Emulates MySQL/PostgreSQL protocols
"""

import asyncio
import hashlib
import json
import logging
import os
import re
import struct
import time
from dataclasses import dataclass, asdict
from datetime import datetime
from typing import List, Optional

LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")
logging.basicConfig(level=getattr(logging, LOG_LEVEL))
logger = logging.getLogger("db-honeypot")


@dataclass
class DBEvent:
    """Represents a database interaction event"""
    timestamp: str
    event_type: str
    source_ip: str
    source_port: int
    protocol: str
    username: str = ""
    database: str = ""
    query: str = ""
    is_injection: bool = False
    session_id: str = ""

    def to_json(self) -> str:
        return json.dumps(asdict(self))


# SQL injection detection patterns
SQL_INJECTION_PATTERNS = [
    r"UNION\s+SELECT",
    r"OR\s+1\s*=\s*1",
    r"OR\s+'[^']*'\s*=\s*'[^']*'",
    r";\s*DROP\s+TABLE",
    r";\s*DELETE\s+FROM",
    r"--\s*$",
    r"SLEEP\s*\(",
    r"BENCHMARK\s*\(",
    r"LOAD_FILE\s*\(",
    r"INTO\s+OUTFILE",
    r"INTO\s+DUMPFILE",
    r"information_schema",
    r"CONCAT\s*\(",
    r"CHAR\s*\(",
    r"0x[0-9a-fA-F]+",
]


class MySQLHoneypot:
    """MySQL Protocol Honeypot"""

    # MySQL protocol constants
    MYSQL_PROTOCOL_VERSION = 10
    MYSQL_SERVER_VERSION = b"5.7.38-0ubuntu0.18.04.1"

    def __init__(
        self,
        host: str = "0.0.0.0",
        port: int = 3306,
        max_connections: int = 25,
    ):
        self.host = host
        self.port = port
        self.max_connections = max_connections
        self.active_connections = 0
        self.events: List[DBEvent] = []
        self.connection_id = 0

        # Compile patterns
        self.injection_patterns = [re.compile(p, re.IGNORECASE) for p in SQL_INJECTION_PATTERNS]

        # Metrics
        self.total_connections = 0
        self.total_queries = 0
        self.injections_detected = 0

    async def start(self):
        """Start the MySQL honeypot server"""
        server = await asyncio.start_server(
            self.handle_connection,
            self.host,
            self.port,
            limit=1024 * 32,
        )

        addr = server.sockets[0].getsockname()
        logger.info(json.dumps({
            "event": "server_started",
            "protocol": "mysql",
            "host": addr[0],
            "port": addr[1],
        }))

        async with server:
            await server.serve_forever()

    async def handle_connection(
        self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter
    ):
        """Handle incoming MySQL connection"""
        addr = writer.get_extra_info("peername")
        client_ip, client_port = addr[0], addr[1]

        if self.active_connections >= self.max_connections:
            writer.close()
            await writer.wait_closed()
            return

        self.active_connections += 1
        self.total_connections += 1
        self.connection_id += 1
        session_id = hashlib.sha256(f"{client_ip}:{client_port}:{time.time()}".encode()).hexdigest()[:16]

        logger.info(json.dumps({
            "event": "connection_opened",
            "session_id": session_id,
            "source_ip": client_ip,
            "protocol": "mysql",
        }))

        try:
            # Send greeting packet
            greeting = self.build_greeting_packet()
            writer.write(greeting)
            await writer.drain()

            # Receive auth packet
            auth_data = await asyncio.wait_for(reader.read(1024), timeout=30.0)
            if auth_data:
                username, database = self.parse_auth_packet(auth_data)

                logger.info(json.dumps({
                    "event": "auth_attempt",
                    "session_id": session_id,
                    "username": username,
                    "database": database,
                }))

                event = DBEvent(
                    timestamp=datetime.utcnow().isoformat(),
                    event_type="db_auth",
                    source_ip=client_ip,
                    source_port=client_port,
                    protocol="mysql",
                    username=username,
                    database=database,
                    session_id=session_id,
                )
                self.events.append(event)

                # Send auth OK
                writer.write(self.build_ok_packet())
                await writer.drain()

                # Handle queries
                await self.handle_queries(reader, writer, session_id, client_ip, client_port)

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

    async def handle_queries(
        self,
        reader: asyncio.StreamReader,
        writer: asyncio.StreamWriter,
        session_id: str,
        client_ip: str,
        client_port: int,
    ):
        """Handle incoming SQL queries"""
        while True:
            try:
                data = await asyncio.wait_for(reader.read(4096), timeout=300.0)
                if not data:
                    break

                # Parse query
                query = self.parse_query_packet(data)
                if query:
                    self.total_queries += 1
                    is_injection = self.detect_injection(query)

                    log_data = {
                        "event": "sql_query",
                        "session_id": session_id,
                        "query": query[:200],
                    }

                    if is_injection:
                        self.injections_detected += 1
                        log_data["attack"] = "sql_injection"
                        logger.warning(json.dumps(log_data))
                    else:
                        logger.info(json.dumps(log_data))

                    event = DBEvent(
                        timestamp=datetime.utcnow().isoformat(),
                        event_type="sql_query",
                        source_ip=client_ip,
                        source_port=client_port,
                        protocol="mysql",
                        query=query,
                        is_injection=is_injection,
                        session_id=session_id,
                    )
                    self.events.append(event)

                    # Send response
                    response = self.build_query_response(query)
                    writer.write(response)
                    await writer.drain()

            except asyncio.TimeoutError:
                break

    def build_greeting_packet(self) -> bytes:
        """Build MySQL greeting packet"""
        packet = bytearray()

        # Protocol version
        packet.append(self.MYSQL_PROTOCOL_VERSION)

        # Server version (null-terminated)
        packet.extend(self.MYSQL_SERVER_VERSION)
        packet.append(0)

        # Connection ID
        packet.extend(struct.pack("<I", self.connection_id))

        # Auth plugin data part 1 (8 bytes)
        packet.extend(os.urandom(8))

        # Filler
        packet.append(0)

        # Capability flags (lower 2 bytes)
        packet.extend(struct.pack("<H", 0xF7FF))

        # Character set
        packet.append(33)  # utf8

        # Status flags
        packet.extend(struct.pack("<H", 0x0002))

        # Capability flags (upper 2 bytes)
        packet.extend(struct.pack("<H", 0x0081))

        # Length of auth plugin data
        packet.append(21)

        # Reserved
        packet.extend(b"\x00" * 10)

        # Auth plugin data part 2 (12 bytes)
        packet.extend(os.urandom(12))
        packet.append(0)

        # Auth plugin name
        packet.extend(b"mysql_native_password")
        packet.append(0)

        # Build packet header
        length = len(packet)
        header = struct.pack("<I", length)[:3] + b"\x00"

        return header + bytes(packet)

    def build_ok_packet(self) -> bytes:
        """Build MySQL OK packet"""
        packet = bytearray()
        packet.append(0x00)  # OK header
        packet.append(0)  # affected rows
        packet.append(0)  # last insert id
        packet.extend(struct.pack("<H", 0x0002))  # status flags
        packet.extend(struct.pack("<H", 0))  # warnings

        header = struct.pack("<I", len(packet))[:3] + b"\x02"
        return header + bytes(packet)

    def build_query_response(self, query: str) -> bytes:
        """Build response to query"""
        # Simple empty result set
        query_lower = query.lower().strip()

        if query_lower.startswith("select"):
            # Empty result set
            return self.build_empty_result()
        else:
            # OK packet
            return self.build_ok_packet()

    def build_empty_result(self) -> bytes:
        """Build empty result set"""
        result = bytearray()

        # Column count packet
        col_count = b"\x01\x00\x00\x01\x01"  # 1 column
        result.extend(col_count)

        # Column definition (simplified)
        col_def = bytearray()
        col_def.extend(b"\x03def")  # catalog
        col_def.append(0)  # schema
        col_def.append(0)  # table
        col_def.append(0)  # org_table
        col_def.extend(b"\x06result")  # name
        col_def.append(0)  # org_name
        col_def.append(0x0c)  # length of fixed fields
        col_def.extend(struct.pack("<H", 33))  # charset
        col_def.extend(struct.pack("<I", 255))  # column length
        col_def.append(0xfd)  # column type (varchar)
        col_def.extend(struct.pack("<H", 0))  # flags
        col_def.append(0)  # decimals
        col_def.extend(b"\x00\x00")  # filler

        col_header = struct.pack("<I", len(col_def))[:3] + b"\x02"
        result.extend(col_header + bytes(col_def))

        # EOF packet
        eof = b"\x05\x00\x00\x03\xfe\x00\x00\x02\x00"
        result.extend(eof)

        # No rows - just EOF
        eof2 = b"\x05\x00\x00\x04\xfe\x00\x00\x02\x00"
        result.extend(eof2)

        return bytes(result)

    def parse_auth_packet(self, data: bytes) -> tuple:
        """Parse authentication packet"""
        try:
            if len(data) < 36:
                return ("unknown", "")

            # Skip header (4 bytes) and capabilities (4 bytes) and max packet (4 bytes)
            # and charset (1 byte) and reserved (23 bytes)
            offset = 36

            # Username (null-terminated)
            username_end = data.find(b"\x00", offset)
            if username_end == -1:
                return ("unknown", "")
            username = data[offset:username_end].decode("utf-8", errors="ignore")

            # Skip auth response
            offset = username_end + 1
            if offset < len(data):
                auth_len = data[offset]
                offset += auth_len + 1

            # Database (null-terminated, if present)
            database = ""
            if offset < len(data):
                db_end = data.find(b"\x00", offset)
                if db_end != -1:
                    database = data[offset:db_end].decode("utf-8", errors="ignore")

            return (username, database)

        except Exception:
            return ("unknown", "")

    def parse_query_packet(self, data: bytes) -> Optional[str]:
        """Parse query from command packet"""
        try:
            if len(data) < 5:
                return None

            # Check command type (byte 4)
            command = data[4]
            if command != 0x03:  # COM_QUERY
                return None

            # Query starts at byte 5
            query = data[5:].decode("utf-8", errors="ignore")
            return query.strip()

        except Exception:
            return None

    def detect_injection(self, query: str) -> bool:
        """Detect SQL injection attempts"""
        for pattern in self.injection_patterns:
            if pattern.search(query):
                return True
        return False

    def get_metrics(self) -> dict:
        """Return current metrics"""
        return {
            "total_connections": self.total_connections,
            "active_connections": self.active_connections,
            "total_queries": self.total_queries,
            "injections_detected": self.injections_detected,
        }


async def main():
    """Main entry point"""
    host = os.getenv("HOST", "0.0.0.0")
    port_str = os.getenv("HONEYPOT_PORT", "3306")
    if port_str.startswith("tcp://"):
        port = 3306
    else:
        port = int(port_str)
    max_connections = int(os.getenv("MAX_CONNECTIONS", "25"))

    honeypot = MySQLHoneypot(
        host=host,
        port=port,
        max_connections=max_connections,
    )

    await honeypot.start()


if __name__ == "__main__":
    asyncio.run(main())
