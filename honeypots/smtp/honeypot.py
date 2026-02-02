#!/usr/bin/env python3
"""
Lightweight SMTP Honeypot for Kubernetes Deception System
Captures email attempts and spam
"""

import asyncio
import hashlib
import json
import logging
import os
import time
from dataclasses import dataclass, asdict
from datetime import datetime
from typing import List

LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")
logging.basicConfig(level=getattr(logging, LOG_LEVEL))
logger = logging.getLogger("smtp-honeypot")


@dataclass
class SMTPEvent:
    """Represents an SMTP interaction event"""
    timestamp: str
    event_type: str
    source_ip: str
    source_port: int
    mail_from: str = ""
    rcpt_to: List[str] = None
    subject: str = ""
    message_size: int = 0
    session_id: str = ""

    def __post_init__(self):
        if self.rcpt_to is None:
            self.rcpt_to = []

    def to_json(self) -> str:
        return json.dumps(asdict(self))


class SMTPHoneypot:
    """Lightweight SMTP Honeypot implementation"""

    def __init__(
        self,
        host: str = "0.0.0.0",
        port: int = 2525,
        max_message_size: int = 1048576,  # 1MB
    ):
        self.host = host
        self.port = port
        self.max_message_size = max_message_size
        self.active_connections = 0
        self.events: List[SMTPEvent] = []

        self.hostname = os.getenv("HOSTNAME", "mail.example.com")

        # Metrics
        self.total_connections = 0
        self.total_messages = 0

    async def start(self):
        """Start the SMTP honeypot server"""
        server = await asyncio.start_server(
            self.handle_connection,
            self.host,
            self.port,
            limit=self.max_message_size,
        )

        addr = server.sockets[0].getsockname()
        logger.info(json.dumps({
            "event": "server_started",
            "protocol": "smtp",
            "host": addr[0],
            "port": addr[1],
        }))

        async with server:
            await server.serve_forever()

    async def handle_connection(
        self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter
    ):
        """Handle incoming SMTP connection"""
        addr = writer.get_extra_info("peername")
        client_ip, client_port = addr[0], addr[1]

        self.active_connections += 1
        self.total_connections += 1
        session_id = hashlib.sha256(f"{client_ip}:{client_port}:{time.time()}".encode()).hexdigest()[:16]

        logger.info(json.dumps({
            "event": "connection_opened",
            "session_id": session_id,
            "source_ip": client_ip,
            "protocol": "smtp",
        }))

        # Session state
        mail_from = ""
        rcpt_to = []
        in_data = False
        message_data = []

        try:
            # Send greeting
            await self.send_response(writer, f"220 {self.hostname} ESMTP ready")

            while True:
                try:
                    line = await asyncio.wait_for(reader.readline(), timeout=300.0)
                    if not line:
                        break

                    line = line.decode("utf-8", errors="ignore").strip()

                    if in_data:
                        if line == ".":
                            # End of message
                            in_data = False
                            self.total_messages += 1

                            message = "\n".join(message_data)
                            subject = self.extract_subject(message)

                            event = SMTPEvent(
                                timestamp=datetime.utcnow().isoformat(),
                                event_type="smtp_message",
                                source_ip=client_ip,
                                source_port=client_port,
                                mail_from=mail_from,
                                rcpt_to=rcpt_to,
                                subject=subject,
                                message_size=len(message),
                                session_id=session_id,
                            )
                            self.events.append(event)

                            logger.warning(json.dumps({
                                "event": "message_received",
                                "session_id": session_id,
                                "mail_from": mail_from,
                                "rcpt_to": rcpt_to,
                                "subject": subject[:100],
                                "size": len(message),
                            }))

                            await self.send_response(writer, "250 OK: Message queued")
                            message_data = []
                        else:
                            if len("\n".join(message_data)) < self.max_message_size:
                                message_data.append(line)
                        continue

                    # Parse SMTP commands
                    command = line.upper().split()[0] if line else ""

                    if command == "HELO" or command == "EHLO":
                        await self.send_response(writer, f"250 {self.hostname}")

                    elif command == "MAIL":
                        mail_from = self.extract_address(line)
                        logger.info(json.dumps({
                            "event": "mail_from",
                            "session_id": session_id,
                            "address": mail_from,
                        }))
                        await self.send_response(writer, "250 OK")

                    elif command == "RCPT":
                        rcpt = self.extract_address(line)
                        rcpt_to.append(rcpt)
                        logger.info(json.dumps({
                            "event": "rcpt_to",
                            "session_id": session_id,
                            "address": rcpt,
                        }))
                        await self.send_response(writer, "250 OK")

                    elif command == "DATA":
                        in_data = True
                        await self.send_response(writer, "354 Start mail input; end with <CRLF>.<CRLF>")

                    elif command == "RSET":
                        mail_from = ""
                        rcpt_to = []
                        message_data = []
                        await self.send_response(writer, "250 OK")

                    elif command == "NOOP":
                        await self.send_response(writer, "250 OK")

                    elif command == "QUIT":
                        await self.send_response(writer, "221 Bye")
                        break

                    elif command == "VRFY":
                        await self.send_response(writer, "252 Cannot VRFY user")

                    elif command == "AUTH":
                        # Log auth attempt
                        logger.warning(json.dumps({
                            "event": "auth_attempt",
                            "session_id": session_id,
                            "command": line,
                        }))
                        await self.send_response(writer, "235 Authentication successful")

                    else:
                        await self.send_response(writer, "500 Command not recognized")

                except asyncio.TimeoutError:
                    break

        except Exception as e:
            logger.error(json.dumps({"event": "error", "error": str(e)}))
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

    async def send_response(self, writer: asyncio.StreamWriter, message: str):
        """Send SMTP response"""
        writer.write(f"{message}\r\n".encode())
        await writer.drain()

    def extract_address(self, line: str) -> str:
        """Extract email address from MAIL/RCPT command"""
        try:
            start = line.find("<")
            end = line.find(">")
            if start != -1 and end != -1:
                return line[start + 1:end]
            parts = line.split(":")
            if len(parts) > 1:
                return parts[1].strip().strip("<>")
        except Exception:
            pass
        return ""

    def extract_subject(self, message: str) -> str:
        """Extract subject from message headers"""
        for line in message.split("\n"):
            if line.lower().startswith("subject:"):
                return line[8:].strip()
        return ""

    def get_metrics(self) -> dict:
        """Return current metrics"""
        return {
            "total_connections": self.total_connections,
            "active_connections": self.active_connections,
            "total_messages": self.total_messages,
        }


async def main():
    """Main entry point"""
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("SMTP_HONEYPOT_PORT", "2525"))
    max_message_size = int(os.getenv("MAX_MESSAGE_SIZE", "1048576"))

    honeypot = SMTPHoneypot(
        host=host,
        port=port,
        max_message_size=max_message_size,
    )

    await honeypot.start()


if __name__ == "__main__":
    asyncio.run(main())
