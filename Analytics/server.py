#!/usr/bin/env python3
"""Nino: local-only reference collector, Python 3.12+, standard library only."""
from __future__ import annotations

import argparse
from collections import deque
import datetime as dt
import hashlib
import http.server
import ipaddress
import json
import os
import socket
import time
import sqlite3
import uuid
from pathlib import Path
from typing import Any

EVENTS = frozenset({
    "recording_failed", "transcription_failed", "app_opened", "recording_started", "recording_completed", "transcription_completed",
    "document_imported", "document_exported", "timer_started", "sticky_note_created",
    "assistant_used", "connector_connected", "onboarding_completed", "project_created",
    "feedback_created", "github_refreshed",
})
MAX_BODY = 65_536
MAX_COUNTERS = 128
MAX_COUNT = 1_000
POLICY_VERSION = 1
RETENTION_DAYS = 90


class InvalidPayload(ValueError):
    pass


class BatchConflict(ValueError):
    pass


def unique_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise InvalidPayload("duplicate_key")
        result[key] = value
    return result


def parse_day(value: Any) -> dt.date:
    if not isinstance(value, str) or len(value) != 10:
        raise InvalidPayload("invalid_day")
    try:
        result = dt.date.fromisoformat(value)
    except ValueError as error:
        raise InvalidPayload("invalid_day") from error
    if result.isoformat() != value:
        raise InvalidPayload("invalid_day")
    return result


def validate_batch(raw: bytes, today: dt.date | None = None) -> dict[str, Any]:
    today = today or dt.datetime.now(dt.UTC).date()
    if not raw or len(raw) > MAX_BODY:
        raise InvalidPayload("body_size")
    try:
        value = json.loads(raw, object_pairs_hook=unique_object)
    except (ValueError, UnicodeError, RecursionError) as error:
        raise InvalidPayload("invalid_json") from error
    if not isinstance(value, dict) or set(value) != {
        "schema_version", "policy_version", "consented_at_day", "batch_id", "counters"
    }:
        raise InvalidPayload("unexpected_fields")
    if type(value["schema_version"]) is not int or value["schema_version"] != 1:
        raise InvalidPayload("schema_version")
    if type(value["policy_version"]) is not int or value["policy_version"] != POLICY_VERSION:
        raise InvalidPayload("policy_version")
    consent_day = parse_day(value["consented_at_day"])
    if not dt.date(2020, 1, 1) <= consent_day <= today:
        raise InvalidPayload("consent_day")
    try:
        batch_id = uuid.UUID(value["batch_id"])
    except (ValueError, TypeError, AttributeError) as error:
        raise InvalidPayload("batch_id") from error
    if batch_id.version != 4 or str(batch_id) != value["batch_id"]:
        raise InvalidPayload("batch_id")
    counters = value["counters"]
    if not isinstance(counters, list) or not 1 <= len(counters) <= MAX_COUNTERS:
        raise InvalidPayload("counter_count")
    seen: set[tuple[str, str, int]] = set()
    for counter in counters:
        if not isinstance(counter, dict) or set(counter) != {"day", "event", "major_version", "count"}:
            raise InvalidPayload("counter_fields")
        day = parse_day(counter["day"])
        if not max(consent_day, today - dt.timedelta(days=30)) <= day <= today:
            raise InvalidPayload("counter_day")
        if not isinstance(counter["event"], str) or counter["event"] not in EVENTS:
            raise InvalidPayload("event")
        if type(counter["major_version"]) is not int or not 0 <= counter["major_version"] <= 999:
            raise InvalidPayload("major_version")
        if type(counter["count"]) is not int or not 1 <= counter["count"] <= MAX_COUNT:
            raise InvalidPayload("count")
        key = (counter["day"], counter["event"], counter["major_version"])
        if key in seen:
            raise InvalidPayload("duplicate_counter")
        seen.add(key)
    return value


class UsageDatabase:
    def __init__(self, path: Path) -> None:
        self.path = path
        path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        with self.connect() as connection:
            connection.executescript("""
                CREATE TABLE IF NOT EXISTS totals (
                    day TEXT NOT NULL, event TEXT NOT NULL, major_version INTEGER NOT NULL,
                    policy_version INTEGER NOT NULL, count INTEGER NOT NULL CHECK (count >= 0),
                    PRIMARY KEY(day, event, major_version, policy_version)
                );
                CREATE TABLE IF NOT EXISTS batches (
                    batch_id TEXT PRIMARY KEY, digest TEXT NOT NULL, received_day TEXT NOT NULL,
                    accepted_count INTEGER NOT NULL
                );
            """)
        os.chmod(path, 0o600)

    def connect(self) -> sqlite3.Connection:
        return sqlite3.connect(self.path, timeout=5)

    def accept(self, raw: bytes, today: dt.date | None = None) -> dict[str, Any]:
        today = today or dt.datetime.now(dt.UTC).date()
        payload = validate_batch(raw, today)
        canonical = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode()
        digest = hashlib.sha256(canonical).hexdigest()
        total = sum(counter["count"] for counter in payload["counters"])
        cutoff = (today - dt.timedelta(days=RETENTION_DAYS)).isoformat()
        with self.connect() as connection:
            connection.execute("BEGIN IMMEDIATE")
            connection.execute("DELETE FROM totals WHERE day < ?", (cutoff,))
            connection.execute("DELETE FROM batches WHERE received_day < ?", (cutoff,))
            previous = connection.execute(
                "SELECT digest, accepted_count FROM batches WHERE batch_id = ?", (payload["batch_id"],)
            ).fetchone()
            if previous:
                if previous[0] != digest:
                    raise BatchConflict("batch_id_reused_with_different_payload")
                duplicate = True
            else:
                for counter in payload["counters"]:
                    connection.execute("""
                        INSERT INTO totals(day, event, major_version, policy_version, count)
                        VALUES (?, ?, ?, ?, ?)
                        ON CONFLICT(day, event, major_version, policy_version)
                        DO UPDATE SET count = count + excluded.count
                    """, (counter["day"], counter["event"], counter["major_version"], payload["policy_version"], counter["count"]))
                connection.execute("INSERT INTO batches VALUES (?, ?, ?, ?)",
                                   (payload["batch_id"], digest, today.isoformat(), total))
                duplicate = False
        return {"schema_version": 1, "batch_id": payload["batch_id"], "accepted_count": total, "duplicate": duplicate}

    def purge(self, today: dt.date | None = None) -> None:
        today = today or dt.datetime.now(dt.UTC).date()
        cutoff = (today - dt.timedelta(days=RETENTION_DAYS)).isoformat()
        with self.connect() as connection:
            connection.execute("DELETE FROM totals WHERE day < ?", (cutoff,))
            connection.execute("DELETE FROM batches WHERE received_day < ?", (cutoff,))

    def summary(self, today: dt.date | None = None) -> list[dict[str, Any]]:
        today = today or dt.datetime.now(dt.UTC).date()
        cutoff = (today - dt.timedelta(days=RETENTION_DAYS)).isoformat()
        with self.connect() as connection:
            connection.execute("DELETE FROM totals WHERE day < ?", (cutoff,))
            connection.execute("DELETE FROM batches WHERE received_day < ?", (cutoff,))
            rows = connection.execute(
                "SELECT day, event, major_version, policy_version, count FROM totals ORDER BY day, event, major_version"
            ).fetchall()
        return [dict(zip(("day", "event", "major_version", "policy_version", "count"), row)) for row in rows]


def handler_for(database: UsageDatabase) -> type[http.server.BaseHTTPRequestHandler]:
    class Handler(http.server.BaseHTTPRequestHandler):
        server_version = "NinoLocalCollector"
        sys_version = ""

        def setup(self) -> None:
            super().setup()
            self.connection.settimeout(5)  # Bounds the header read too, not only the JSON body.

        def log_message(self, format: str, *args: Any) -> None:
            # Deliberately no IP, request path, headers or payload access log.
            pass

        def reply(self, status: int, payload: dict[str, Any]) -> None:
            body = json.dumps(payload, separators=(",", ":")).encode()
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.send_header("Connection", "close")
            self.end_headers()
            self.wfile.write(body)
            self.close_connection = True

        def do_POST(self) -> None:
            if not self.server.allow_request():
                self.reply(429, {"error": "local_rate_limit"}); return
            if self.path != "/v1/usage":
                self.reply(404, {"error": "not_found"}); return
            if self.headers.get("Transfer-Encoding") is not None:
                self.reply(400, {"error": "transfer_encoding_not_supported"}); return
            lengths = self.headers.get_all("Content-Length", [])
            if len(lengths) != 1 or len(lengths[0]) > 10 or not lengths[0].isascii() or not lengths[0].isdigit():
                self.reply(411, {"error": "content_length_required"}); return
            length = int(lengths[0])
            if not 1 <= length <= MAX_BODY:
                self.reply(413, {"error": "body_size"}); return
            if self.headers.get("Content-Type", "").split(";", 1)[0].strip() != "application/json":
                self.reply(415, {"error": "json_required"}); return
            self.connection.settimeout(5)
            try:
                raw = self.rfile.read(length)
                if len(raw) != length:
                    raise InvalidPayload("incomplete_body")
                acknowledgement = database.accept(raw)
            except InvalidPayload as error:
                self.reply(400, {"error": str(error)}); return
            except BatchConflict:
                self.reply(409, {"error": "batch_conflict"}); return
            except (socket.timeout, TimeoutError):
                self.reply(408, {"error": "request_timeout"}); return
            except sqlite3.Error:
                self.reply(503, {"error": "storage_unavailable"}); return
            self.reply(200, acknowledgement)
    Handler.usage_database = database
    return Handler


class LocalHTTPServer(http.server.HTTPServer):
    def __init__(self, address: tuple[str, int], handler: type[http.server.BaseHTTPRequestHandler]) -> None:
        super().__init__(address, handler)
        self.recent_requests: deque[float] = deque()
        self.last_purge_day: dt.date | None = None
        self.service_actions()

    def allow_request(self) -> bool:
        now = time.monotonic()
        while self.recent_requests and self.recent_requests[0] <= now - 60:
            self.recent_requests.popleft()
        if len(self.recent_requests) >= 60:
            return False
        self.recent_requests.append(now)
        return True

    def service_actions(self) -> None:
        today = dt.datetime.now(dt.UTC).date()
        if self.last_purge_day != today:
            self.RequestHandlerClass.usage_database.purge(today)
            self.last_purge_day = today

    def handle_error(self, request: Any, client_address: Any) -> None:
        # Default BaseServer tracebacks contain a client IP; do not emit them.
        pass


def main() -> None:
    parser = argparse.ArgumentParser(description="Nino analytics — local synthetic fixtures only")
    parser.add_argument("command", choices=("serve", "summary"))
    parser.add_argument("--db", type=Path, default=Path("./local-data/usage.sqlite3"))
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8769)
    args = parser.parse_args()
    if not ipaddress.ip_address(args.host).is_loopback or args.host != "127.0.0.1":
        parser.error("Only 127.0.0.1 is supported. This reference server is not a public deployment.")
    database = UsageDatabase(args.db)
    if args.command == "summary":
        print(json.dumps(database.summary(), indent=2, ensure_ascii=False))
        return
    server = LocalHTTPServer((args.host, args.port), handler_for(database))
    print(f"Local reference collector on 127.0.0.1:{server.server_port}; no request access logs.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
