import json
import threading
import unittest
from http.server import BaseHTTPRequestHandler, HTTPServer

from gateway_probe import probe


class Gateway(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.headers.get("Authorization") != "Bearer right" or self.path != "/v1/models":
            self.send_response(401)
            self.end_headers()
            return
        body = json.dumps({"data": [{"id": "gemini-3.8-flash"}, {"id": "openrouter/glm-5.3-flash"}]}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        request = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        # The upstream for this model is down, though the gateway still lists it.
        if self.path != "/v1/chat/completions" or request["model"] == "openrouter/glm-5.3-flash":
            self.send_response(502)
            self.end_headers()
            return
        body = json.dumps({"choices": [{"message": {"content": "OK"}}]}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *arguments):
        pass


class GatewayProbeTests(unittest.TestCase):
    def setUp(self):
        self.server = HTTPServer(("127.0.0.1", 0), Gateway)
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        self.addCleanup(self.server.shutdown)
        self.url = f"http://127.0.0.1:{self.server.server_port}"

    def test_expected_models_present(self):
        status, _ = probe(self.url, "right", ["gemini-3.8-flash", "openrouter/glm-5.3-flash"])
        self.assertEqual(status, 0)

    def test_a_missing_model_is_not_an_outage(self):
        status, message = probe(self.url, "right", ["gemini-3.8-flash", "gpt-retired"])
        self.assertEqual(status, 1)
        self.assertIn("gpt-retired", message)

    def test_inference_catches_a_listed_model_that_does_not_answer(self):
        self.assertEqual(probe(self.url, "right", ["gemini-3.8-flash"], infer=True)[0], 0)
        status, message = probe(self.url, "right", ["gemini-3.8-flash", "openrouter/glm-5.3-flash"], infer=True)
        self.assertEqual(status, 1)
        self.assertIn("openrouter/glm-5.3-flash", message)

    def test_a_refused_key_or_dead_gateway_is_an_outage(self):
        self.assertEqual(probe(self.url, "wrong", ["gemini-3.8-flash"])[0], 2)
        self.assertEqual(probe("http://127.0.0.1:9", "right", ["gemini-3.8-flash"])[0], 2)


if __name__ == "__main__":
    unittest.main()
