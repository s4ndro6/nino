#!/usr/bin/env python3
"""Synthetic protocol/security integration tests. No accounts or user data read.

python3 work/nino-mcp/test_mcp.py [--binary /path/to/nino-mcp]
Without --binary, compiles Server.swift in a temporary directory with local cache.
"""
from __future__ import annotations

import argparse
import copy
from datetime import datetime, timedelta, timezone
import json
import os
from pathlib import Path
import select
import stat
import subprocess
import tempfile
import time
import unittest
import uuid
from typing import Any

BINARY: Path


def make_snapshot() -> dict[str, Any]:
    return {
        "schemaVersion": 1,
        "sharingEnabled": True,
        "updatedAt": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "sessionID": str(uuid.uuid4()).upper(),
        "project": {
            "id": str(uuid.uuid4()).upper(),
            "title": "Recette du ticket démo",
            "brief": "Vérifier les liens et l’affichage compact.\nTexte de test uniquement.",
            "nextAction": "Ouvrir le panneau compact",
            "tasks": [{"id": str(uuid.uuid4()).upper(), "title": "Vérifier", "done": False}],
            "links": [{"id": str(uuid.uuid4()).upper(), "label": "Recette", "url": "https://example.com/test"}],
        },
    }


class Client:
    def __init__(self, workspace: Path) -> None:
        self.process = subprocess.Popen(
            [str(BINARY), "--workspace", str(workspace)],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            bufsize=0,
        )
        self.buffer = b""
        self.sequence = 0

    def write(self, value: Any) -> None:
        self.write_raw(json.dumps(value, ensure_ascii=False).encode() + b"\n")

    def write_raw(self, data: bytes) -> None:
        assert self.process.stdin is not None
        view = memoryview(data)
        while view:
            count = self.process.stdin.write(view)
            assert count is not None and count > 0
            view = view[count:]

    def receive(self, timeout: float = 3.0) -> dict[str, Any] | None:
        assert self.process.stdout is not None
        deadline = time.monotonic() + timeout
        while b"\n" not in self.buffer:
            remaining = deadline - time.monotonic()
            if remaining <= 0 or not select.select([self.process.stdout], [], [], remaining)[0]:
                return None
            chunk = os.read(self.process.stdout.fileno(), 8192)
            if not chunk:
                raise AssertionError("Server ended before its response")
            self.buffer += chunk
        line, self.buffer = self.buffer.split(b"\n", 1)
        return json.loads(line)

    def request(self, method: str, parameters: dict[str, Any] | None = None) -> dict[str, Any]:
        self.sequence += 1
        request: dict[str, Any] = {"jsonrpc": "2.0", "id": self.sequence, "method": method}
        if parameters is not None:
            request["params"] = parameters
        self.write(request)
        result = self.receive()
        assert result is not None, f"No response for {method}"
        assert result.get("id") == self.sequence, result
        assert result.get("jsonrpc") == "2.0", result
        return result

    def initialize(self, version: str = "2025-11-25") -> dict[str, Any]:
        result = self.request("initialize", {
            "protocolVersion": version,
            "capabilities": {},
            "clientInfo": {"name": "synthetic-test", "version": "1"},
        })
        self.write({"jsonrpc": "2.0", "method": "notifications/initialized"})
        return result

    def call(self, name: str, arguments: dict[str, Any] | None = None) -> dict[str, Any]:
        return self.request("tools/call", {"name": name, "arguments": arguments or {}})

    def close(self) -> None:
        if self.process.stdin:
            self.process.stdin.close()
        try:
            self.process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            self.process.kill()
            self.process.wait(timeout=3)
        if self.process.stdout:
            self.process.stdout.close()
        if self.process.stderr:
            stderr = self.process.stderr.read()
            self.process.stderr.close()
            assert not stderr, stderr.decode(errors="replace")


class MCPTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="nino-mcp-test-")
        self.root = Path(self.temporary.name).resolve()
        self.workspace = self.root / "Workspace"
        self.workspace.mkdir()
        self.snapshot = make_snapshot()
        self.save()
        self.client = Client(self.workspace)
        self.client.initialize()

    def tearDown(self) -> None:
        self.client.close()
        self.temporary.cleanup()

    def save(self) -> None:
        (self.workspace / "context.json").write_text(json.dumps(self.snapshot), encoding="utf-8")

    def progress(self, **overrides: Any) -> dict[str, Any]:
        values = {"projectID": self.snapshot["project"]["id"], "sessionID": self.snapshot["sessionID"],
                  "state": "working", "message": "Vérification en cours", "agent": "Test local"}
        values.update(overrides)
        return values

    def assert_tool_error(self, response: dict[str, Any]) -> None:
        self.assertTrue(response["result"]["isError"], response)

    def test_initialize_versions_and_fallback(self) -> None:
        for requested, expected in [("2025-06-18", "2025-06-18"), ("2025-11-25", "2025-11-25"), ("future", "2025-11-25")]:
            with self.subTest(version=requested):
                client = Client(self.workspace)
                try:
                    result = client.initialize(requested)["result"]
                    self.assertEqual(result["protocolVersion"], expected)
                    self.assertEqual(result["serverInfo"]["name"], "nino")
                    self.assertIn("tools", result["capabilities"])
                finally:
                    client.close()

    def test_lifecycle_and_ping(self) -> None:
        client = Client(self.workspace)
        try:
            self.assertEqual(client.request("ping")["result"], {})
            self.assertEqual(client.request("tools/list")["error"]["code"], -32002)
            client.request("initialize", {"protocolVersion": "2025-11-25", "capabilities": {}, "clientInfo": {"name": "test", "version": "1"}})
            self.assertEqual(client.request("tools/list")["error"]["code"], -32002)
            client.write({"jsonrpc": "2.0", "method": "notifications/initialized"})
            self.assertIn("tools", client.request("tools/list")["result"])
            self.assertEqual(client.initialize()["error"]["code"], -32600)
        finally:
            client.close()

    def test_tools_and_annotations(self) -> None:
        tools = self.client.request("tools/list")["result"]["tools"]
        self.assertEqual([tool["name"] for tool in tools], ["nino_get_context", "nino_report_progress"])
        self.assertTrue(tools[0]["annotations"]["readOnlyHint"])
        self.assertFalse(tools[1]["annotations"]["readOnlyHint"])
        self.assertFalse(tools[1]["annotations"]["destructiveHint"])
        self.assertFalse(tools[1]["inputSchema"]["additionalProperties"])

    def test_context_and_resource(self) -> None:
        result = self.client.call("nino_get_context")["result"]
        self.assertFalse(result["isError"])
        self.assertEqual(json.loads(result["content"][0]["text"]), self.snapshot)
        resources = self.client.request("resources/list")["result"]["resources"]
        self.assertEqual(len(resources), 1)
        result = self.client.request("resources/read", {"uri": "nino://current-work"})["result"]
        self.assertEqual(json.loads(result["contents"][0]["text"]), self.snapshot)
        self.assertEqual(self.client.request("resources/read", {"uri": "file:///etc/passwd"})["error"]["code"], -32602)

    def test_progress_changes_only_activity_and_has_safe_permissions(self) -> None:
        before = (self.workspace / "context.json").read_bytes()
        for state in ["working", "waiting", "completed", "failed"]:
            result = self.client.call("nino_report_progress", self.progress(state=state))["result"]
            self.assertFalse(result["isError"])
            event = json.loads((self.workspace / "activity.json").read_text())
            self.assertEqual(event["state"], state)
            self.assertEqual(event["projectID"], self.snapshot["project"]["id"])
            self.assertEqual(event["sessionID"], self.snapshot["sessionID"])
            self.assertEqual(event["agent"], "Test local")
            self.assertIn("reportedAt", event)
            self.assertEqual(stat.S_IMODE((self.workspace / "activity.json").stat().st_mode), 0o600)
        self.assertEqual(before, (self.workspace / "context.json").read_bytes())
        self.assertEqual({path.name for path in self.workspace.iterdir()}, {"context.json", "activity.json"})

    def test_unshared_fail_closed_and_revoke_live(self) -> None:
        self.assertFalse(self.client.call("nino_get_context")["result"]["isError"])
        self.snapshot["sharingEnabled"] = False
        self.save()
        self.assert_tool_error(self.client.call("nino_get_context"))
        self.assert_tool_error(self.client.call("nino_report_progress", self.progress()))
        self.assertFalse((self.workspace / "activity.json").exists())
        self.assertIn("error", self.client.request("resources/read", {"uri": "nino://current-work"}))

    def test_changed_project_or_session(self) -> None:
        for field in ["projectID", "sessionID"]:
            self.assert_tool_error(self.client.call("nino_report_progress", self.progress(**{field: str(uuid.uuid4())})))
        old = self.progress()
        self.snapshot["sessionID"] = str(uuid.uuid4()).upper()
        self.save()
        self.assert_tool_error(self.client.call("nino_report_progress", old))
        self.assertFalse((self.workspace / "activity.json").exists())

    def test_invalid_tool_parameters(self) -> None:
        for overrides in [{"state": "run-shell"}, {"message": ""}, {"message": "x" * 501}, {"agent": "x" * 61},
                          {"command": "echo unsafe"}, {"projectID": "../../outside"}, {"message": 7},
                          {"message": "\0"}, {"sessionID": None}]:
            with self.subTest(overrides=overrides):
                self.assertEqual(self.client.call("nino_report_progress", self.progress(**overrides))["error"]["code"], -32602)
        self.assertEqual(self.client.call("nino_get_context", {"path": "/etc/passwd"})["error"]["code"], -32602)
        self.assertEqual(self.client.call("unknown")["error"]["code"], -32602)
        self.assertFalse((self.workspace / "activity.json").exists())

    def test_no_response_or_effect_for_notifications(self) -> None:
        for method in ["notifications/unknown", "ping", "tools/call"]:
            self.client.write({"jsonrpc": "2.0", "method": method,
                               "params": {"name": "nino_report_progress", "arguments": self.progress()}})
        self.assertIsNone(self.client.receive(timeout=0.1))
        self.assertFalse((self.workspace / "activity.json").exists())
        self.assertEqual(self.client.request("ping")["result"], {})

    def test_bad_json_recovers_without_echo(self) -> None:
        for value in [b'{broken secret-value\n', b'\xff\n', b'null\n', b'[]\n', b'{"jsonrpc":"1.0","method":"ping","id":1}\n']:
            self.client.write_raw(value)
            response = self.client.receive()
            self.assertIsNotNone(response)
            self.assertIn("error", response)
            self.assertIsNone(response["id"])
            self.assertNotIn("secret-value", json.dumps(response))
        self.assertEqual(self.client.request("ping")["result"], {})

    def test_request_size_bounded_and_recovers(self) -> None:
        self.client.write_raw(b'"' + b'x' * (128 * 1024 + 4) + b'"\n')
        self.assertEqual(self.client.receive()["error"]["code"], -32700)
        self.assertEqual(self.client.request("ping")["result"], {})

    def test_unknown_methods_and_extra_params(self) -> None:
        self.assertEqual(self.client.request("shell/run", {"command": "echo test"})["error"]["code"], -32601)
        for method in ["tools/list", "resources/list", "ping"]:
            self.assertEqual(self.client.request(method, {"unexpected": True})["error"]["code"], -32602)
        self.assertIn("tools", self.client.request("tools/list", {"_meta": {"progressToken": 7}})["result"])
        self.assertEqual(self.client.request("tools/list", {"_meta": True})["error"]["code"], -32602)
        for invalid_id in [None, True, [], {}]:
            self.client.write({"jsonrpc": "2.0", "id": invalid_id, "method": "ping"})
            self.assertEqual(self.client.receive()["error"]["code"], -32600)

    def test_snapshot_schema_limits_and_secrets(self) -> None:
        baseline = copy.deepcopy(self.snapshot)
        invalid = []
        value = copy.deepcopy(baseline); value["privateToken"] = "do-not-leak"; invalid.append(value)
        value = copy.deepcopy(baseline); value["project"]["repositoryPath"] = "/secret"; invalid.append(value)
        value = copy.deepcopy(baseline); value["sharingEnabled"] = 1; invalid.append(value)
        value = copy.deepcopy(baseline); value["schemaVersion"] = True; invalid.append(value)
        value = copy.deepcopy(baseline); value["project"]["brief"] = "x" * 12001; invalid.append(value)
        value = copy.deepcopy(baseline); value["project"]["tasks"][0]["done"] = 1; invalid.append(value)
        value = copy.deepcopy(baseline); value["project"]["links"][0]["url"] = "file:///etc/passwd"; invalid.append(value)
        value = copy.deepcopy(baseline); value["project"]["links"][0]["url"] = "https://user:pass@example.com/"; invalid.append(value)
        value = copy.deepcopy(baseline); value["updatedAt"] = "yesterday"; invalid.append(value)
        for value in invalid:
            self.snapshot = value; self.save()
            result = self.client.call("nino_get_context")
            self.assert_tool_error(result)
            self.assertNotIn("do-not-leak", json.dumps(result))
            self.assertNotIn("/secret", json.dumps(result))

    def test_missing_oversized_and_malformed_snapshot(self) -> None:
        path = self.workspace / "context.json"
        path.unlink()
        self.assert_tool_error(self.client.call("nino_get_context"))
        path.write_bytes(b'x' * (256 * 1024 + 1))
        self.assert_tool_error(self.client.call("nino_get_context"))
        path.write_text('{"secret": malformed')
        self.assert_tool_error(self.client.call("nino_get_context"))

    def test_context_symlink_hardlink_and_fifo(self) -> None:
        path = self.workspace / "context.json"
        external = self.root / "external.json"
        path.rename(external)
        path.symlink_to(external)
        self.assert_tool_error(self.client.call("nino_get_context"))
        path.unlink()
        os.link(external, path)
        self.assert_tool_error(self.client.call("nino_get_context"))
        path.unlink()
        os.mkfifo(path)
        self.assert_tool_error(self.client.call("nino_get_context"))

    def test_workspace_and_ancestor_symlinks(self) -> None:
        link = self.root / "alias"
        link.symlink_to(self.workspace, target_is_directory=True)
        parent_link = self.root / "parent-alias"
        parent_link.symlink_to(self.root, target_is_directory=True)
        for path in [link, parent_link / "Workspace", self.root / "missing"]:
            client = Client(path)
            try:
                client.initialize()
                self.assert_tool_error(client.call("nino_get_context"))
            finally:
                client.close()

    def test_activity_symlink_and_hardlink_no_external_write(self) -> None:
        external = self.root / "outside.txt"
        external.write_text("untouched")
        activity = self.workspace / "activity.json"
        activity.symlink_to(external)
        self.assert_tool_error(self.client.call("nino_report_progress", self.progress()))
        self.assertEqual(external.read_text(), "untouched")
        activity.unlink()
        os.link(external, activity)
        self.assert_tool_error(self.client.call("nino_report_progress", self.progress()))
        self.assertEqual(external.read_text(), "untouched")

    def test_refresh_reads_current_snapshot(self) -> None:
        self.snapshot["project"]["nextAction"] = "Écrire le compte rendu"
        self.save()
        result = self.client.call("nino_get_context")["result"]
        self.assertEqual(json.loads(result["content"][0]["text"])["project"]["nextAction"], "Écrire le compte rendu")

    def test_expired_or_future_grant_fail_closed(self) -> None:
        for offset in [-301, 31]:
            self.snapshot["updatedAt"] = (datetime.now(timezone.utc) + timedelta(seconds=offset)).isoformat().replace("+00:00", "Z")
            self.save()
            self.assert_tool_error(self.client.call("nino_get_context"))
            self.assert_tool_error(self.client.call("nino_report_progress", self.progress()))
        self.assertFalse((self.workspace / "activity.json").exists())


def main() -> int:
    global BINARY
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", type=Path)
    arguments, unittest_arguments = parser.parse_known_args()
    with tempfile.TemporaryDirectory(prefix="nino-mcp-build-") as directory:
        if arguments.binary:
            BINARY = arguments.binary.resolve()
        else:
            build = Path(directory).resolve()
            BINARY = build / "nino-mcp"
            subprocess.run(["xcrun", "swiftc", "-parse-as-library", "-swift-version", "5",
                            "-module-cache-path", str(build / "cache"),
                            str(Path(__file__).resolve().parent.parent / "MCP" / "Server.swift"), "-o", str(BINARY)], check=True)
        program = unittest.main(argv=[__file__, *unittest_arguments], exit=False, verbosity=2)
        return 0 if program.result.wasSuccessful() else 1


if __name__ == "__main__":
    raise SystemExit(main())
