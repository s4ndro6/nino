from __future__ import annotations
import copy
import datetime as dt
import http.client
import json
import tempfile
import threading
import unittest
import uuid
from pathlib import Path
from server import BatchConflict, InvalidPayload, LocalHTTPServer, UsageDatabase, handler_for, validate_batch

TODAY = dt.date(2026, 11, 5)

def fixture() -> dict:
    return {"schema_version": 1, "policy_version": 1, "consented_at_day": TODAY.isoformat(),
            "batch_id": str(uuid.uuid4()), "counters": [
                {"day": TODAY.isoformat(), "event": "timer_started", "major_version": 0, "count": 3},
                {"day": TODAY.isoformat(), "event": "sticky_note_created", "major_version": 0, "count": 2}]}

def encoded(value: dict) -> bytes:
    return json.dumps(value).encode()

class CollectorTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.database = UsageDatabase(Path(self.temporary.name) / "usage.sqlite3")
    def tearDown(self) -> None:
        self.temporary.cleanup()
    def test_idempotence_and_aggregate(self) -> None:
        batch = fixture()
        first = self.database.accept(encoded(batch), TODAY)
        second = self.database.accept(encoded(batch), TODAY)
        self.assertFalse(first["duplicate"]); self.assertTrue(second["duplicate"])
        self.assertEqual(first["accepted_count"], 5)
        self.assertEqual(sum(row["count"] for row in self.database.summary(TODAY)), 5)
        batch["batch_id"] = str(uuid.uuid4()); self.database.accept(encoded(batch), TODAY)
        self.assertEqual(sum(row["count"] for row in self.database.summary(TODAY)), 10)
    def test_batch_conflict_rolls_back(self) -> None:
        batch = fixture(); self.database.accept(encoded(batch), TODAY); batch["counters"][0]["count"] = 4
        with self.assertRaises(BatchConflict): self.database.accept(encoded(batch), TODAY)
        self.assertEqual(sum(row["count"] for row in self.database.summary(TODAY)), 5)
    def test_strict_schema(self) -> None:
        variants = []
        for key, value in [("schema_version", True), ("policy_version", 2), ("batch_id", "user-123"), ("email", "person@example.test"), ("consented_at_day", "2026-11-06")]:
            batch = fixture(); batch[key] = value; variants.append(batch)
        for key, value in [("count", True), ("count", 0), ("count", 1001), ("count", 1.2), ("event", "note contents"), ("day", "2026-10-01"), ("day", "2026-11-06"), ("day", "2026-11-99"), ("major_version", -1), ("text", "private")]:
            batch = fixture(); batch["counters"][0][key] = value; variants.append(batch)
        batch = fixture(); batch["counters"] = []; variants.append(batch)
        batch = fixture(); batch["counters"] = [batch["counters"][0]] * 129; variants.append(batch)
        batch = fixture(); batch["counters"].append(copy.deepcopy(batch["counters"][0])); variants.append(batch)
        for batch in variants:
            with self.subTest(batch=batch), self.assertRaises(InvalidPayload): validate_batch(encoded(batch), TODAY)
        with self.assertRaises(InvalidPayload): validate_batch(b"x" * 65_537, TODAY)
        with self.assertRaises(InvalidPayload): validate_batch(b'{"schema_version":1,"schema_version":1}', TODAY)
        self.assertEqual(self.database.summary(TODAY), [])
    def test_retention(self) -> None:
        self.database.accept(encoded(fixture()), TODAY)
        self.assertEqual(self.database.summary(TODAY + dt.timedelta(days=91)), [])
        with self.database.connect() as connection: self.assertEqual(connection.execute("SELECT count(*) FROM batches").fetchone()[0], 0)
    def test_concurrent_retry_counted_once(self) -> None:
        raw = encoded(fixture()); errors = []
        def send() -> None:
            try: self.database.accept(raw, TODAY)
            except Exception as error: errors.append(error)
        threads = [threading.Thread(target=send) for _ in range(8)]
        for thread in threads: thread.start()
        for thread in threads: thread.join()
        self.assertEqual(errors, [])
        self.assertEqual(sum(row["count"] for row in self.database.summary(TODAY)), 5)
    def test_http_local_synthetic_fixture(self) -> None:
        server = LocalHTTPServer(("127.0.0.1", 0), handler_for(self.database))
        server.recent_requests.clear()
        self.assertTrue(all(server.allow_request() for _ in range(60)))
        self.assertFalse(server.allow_request())
        server.recent_requests.clear()
        thread = threading.Thread(target=server.serve_forever, daemon=True); thread.start()
        try:
            batch = fixture(); day = dt.datetime.now(dt.UTC).date().isoformat(); batch["consented_at_day"] = day
            for counter in batch["counters"]: counter["day"] = day
            connection = http.client.HTTPConnection("127.0.0.1", server.server_port, timeout=3)
            connection.request("POST", "/v1/usage", encoded(batch), {"Content-Type": "application/json"})
            response = connection.getresponse(); self.assertEqual(response.status, 200)
            self.assertEqual(json.loads(response.read())["accepted_count"], 5); self.assertIsNone(response.getheader("Set-Cookie")); connection.close()
            connection = http.client.HTTPConnection("127.0.0.1", server.server_port, timeout=3)
            connection.request("POST", "/v1/usage", b"x" * 65_537, {"Content-Type": "application/json"})
            response = connection.getresponse(); self.assertEqual(response.status, 413); response.read(); connection.close()
        finally:
            server.shutdown(); thread.join(); server.server_close()

if __name__ == "__main__": unittest.main()
