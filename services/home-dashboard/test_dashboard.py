import datetime
from contextlib import closing
import json
import http.client
from pathlib import Path
import socket
import sqlite3
import tempfile
import threading
import time
import unittest
from unittest.mock import patch

import collect
import server


class StatusTests(unittest.TestCase):
    def test_pending_paused_stale_and_long_running_push(self):
        now = datetime.datetime(2026, 10, 1, 12, tzinfo=datetime.timezone.utc).timestamp()
        row = {"name": "Check", "active": 1, "interval": 60, "retry_interval": 60,
               "maxretries": 2, "status": 2, "ping": 12, "time": "2026-10-01 11:59:00"}
        self.assertEqual(collect.monitor_check(row, now)["status"], "pending")
        row["time"] = "2026-10-01 10:00:00"
        self.assertEqual(collect.monitor_check(row, now)["status"], "unknown")
        row.update(interval=93600, status=1)
        self.assertEqual(collect.monitor_check(row, now)["status"], "up")
        row["active"] = 0
        self.assertEqual(collect.monitor_check(row, now)["status"], "paused")

    def test_private_catalog_and_database_credentials_never_export_publicly(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            database = root / "kuma.db"
            with closing(sqlite3.connect(database)) as db, db:
                db.executescript("""
                  CREATE TABLE monitor(id INTEGER,name TEXT,active INTEGER,interval INTEGER,
                    retry_interval INTEGER,maxretries INTEGER,type TEXT,push_token TEXT);
                  CREATE TABLE heartbeat(id INTEGER,monitor_id INTEGER,status INTEGER,time TEXT,ping INTEGER,msg TEXT);
                  INSERT INTO monitor VALUES(1,'Secret private monitor',1,60,60,2,'http','DO-NOT-EXPORT');
                  INSERT INTO heartbeat VALUES(1,1,1,'2026-10-01 11:59:00',12,'Secret error URL');
                """)
            fake_probe = {"name": "Probe", "status": "up", "checked": 1, "latency": 1, "kind": "HTTP reachability"}
            with patch("collect.http_check", return_value=fake_probe):
                collect.collect(database, root / "status")
            public = json.loads((root / "status/public.json").read_text())
            private = json.loads((root / "status/private.json").read_text())
            self.assertEqual({service["id"] for service in public["services"]}, {"site", "forgejo"})
            self.assertNotIn("Secret private monitor", json.dumps(public))
            self.assertNotIn("DO-NOT-EXPORT", json.dumps(private))
            self.assertNotIn("Secret error URL", json.dumps(private))
            self.assertTrue(any(service["name"] == "Secret private monitor" for service in private["services"]))
            self.assertTrue(all("probe" not in service for service in private["services"]))

    def test_stale_export_and_missing_export_fail_unknown(self):
        with tempfile.TemporaryDirectory() as temporary, patch.object(server, "STATUS", Path(temporary)):
            view = server.read_view(False)
            self.assertEqual({service["id"] for service in view["services"]}, {"site", "forgejo"})
            self.assertTrue(all(service["status"] == "unknown" for service in view["services"]))
            (Path(temporary) / "public.json").write_text(json.dumps({"generated": 1, "services": [{"status": "up", "checks": [{"status": "up"}]}]}))
            self.assertEqual(server.read_view(False)["services"][0]["status"], "unknown")

    def test_down_and_unknown_components_are_not_healthy(self):
        self.assertEqual(collect.aggregate([{"status": "up"}, {"status": "down"}]), "down")
        self.assertEqual(collect.aggregate([{"status": "up"}, {"status": "unknown"}]), "unknown")
        self.assertEqual(collect.aggregate([]), "unknown")

    def test_remote_listener_stale_or_invalid_snapshot_cannot_be_healthy(self):
        service = {"name": "Listener", "probe": {"url": "http://localhost/status", "snapshot": True}}
        for body, expected in (({"generated": time.time() - 300, "status": "up"}, "unknown"),
                               ({"generated": time.time(), "status": "up"}, "up"),
                               ({"generated": time.time(), "status": "down"}, "down"),
                               ({"generated": time.time()}, "unknown")):
            with patch("collect.http.client.HTTPConnection") as connection:
                response = connection.return_value.getresponse.return_value
                response.status = 200
                response.read.return_value = json.dumps(body).encode()
                self.assertEqual(collect.http_check(service)["status"], expected)


class ApiTests(unittest.TestCase):
    def test_unauthenticated_private_request_and_public_identity_header(self):
        with tempfile.TemporaryDirectory() as temporary:
            sock = str(Path(temporary) / "api.sock")
            api = server.Server(sock, server.Handler)
            worker = threading.Thread(target=api.serve_forever, daemon=True)
            worker.start()
            try:
                for route, identity, expected in (("/api/private", "", 401),
                                                   ("/api/public", "lisa", 200),
                                                   ("/api/private", "lisa", 200)):
                    connection = http.client.HTTPConnection("localhost")
                    connection.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                    connection.sock.connect(sock)
                    with patch.object(server, "STATUS", Path(temporary)):
                        connection.request("GET", route, headers={"X-Dashboard-User": identity})
                        response = connection.getresponse()
                        self.assertEqual(response.status, expected)
                        self.assertEqual(response.getheader("Cache-Control"), "private, no-store")
                        view = json.loads(response.read())
                        if route == "/api/public":
                            self.assertEqual({item["id"] for item in view["services"]}, {"site", "forgejo"})
                            self.assertNotIn("user", view)
                        elif expected == 200:
                            self.assertEqual(view["user"], "lisa")
                            self.assertTrue(any(item["id"] == "jellyfin" for item in view["services"]))
                    connection.close()
            finally:
                api.shutdown()
                api.server_close()
                worker.join()


if __name__ == "__main__":
    unittest.main()
