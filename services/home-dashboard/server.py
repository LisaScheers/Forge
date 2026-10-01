"""A Unix-socket status API. Nginx authenticates the private route."""
from http.server import BaseHTTPRequestHandler
import json
import os
from pathlib import Path
import socketserver
import time
from urllib.parse import urlsplit

ROOT = Path(__file__).parent
STATUS = Path(os.environ.get("DASH_STATUS", "/var/lib/home-dashboard-status"))


def read_view(private):
    try:
        snapshot = json.loads((STATUS / ("private.json" if private else "public.json")).read_text())
    except (OSError, ValueError):
        catalog = json.loads((ROOT / "catalog.json").read_text())
        snapshot = {"generated": None, "services": [
            {key: entry[key] for key in ("id", "name", "description", "group", "icon", "url", "connection", "local", "network", "public") if key in entry}
            for entry in catalog if private or entry.get("public", False)]}
        for service in snapshot["services"]:
            service.update(status="unknown", checks=[])
    if not snapshot["generated"] or time.time() - snapshot["generated"] > 120:
        for service in snapshot["services"]:
            service["status"] = "unknown"
            for check in service["checks"]:
                check["status"] = "unknown"
    return snapshot


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def reply(self, code, body, content_type="application/json"):
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Cache-Control", "private, no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        route = urlsplit(self.path).path
        if route in ("/api/public", "/api/private"):
            private = route == "/api/private"
            user = self.headers.get("X-Dashboard-User", "")
            if private and not user:
                self.reply(401, b'{"error":"Sign in required"}')
                return
            view = read_view(private)
            if private:
                view["user"] = user
            self.reply(200, json.dumps(view, ensure_ascii=False).encode())
        elif route == "/login":
            self.send_response(302)
            self.send_header("Location", "/")
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
        else:
            self.reply(404, b'{"error":"Not found"}')


class Server(socketserver.ThreadingMixIn, socketserver.UnixStreamServer):
    daemon_threads = True


if __name__ == "__main__":
    sock = os.environ.get("DASH_SOCKET", "/run/home-dashboard/api.sock")
    Path(sock).unlink(missing_ok=True)
    with Server(sock, Handler) as server:
        os.chmod(sock, 0o660)
        server.serve_forever()
