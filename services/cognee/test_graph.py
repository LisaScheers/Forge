import tempfile
import unittest
from pathlib import Path

from aiohttp import web
from aiohttp.test_utils import TestClient, TestServer

from graph import DEFAULT_DATASET, create_app


class GraphBoundaryTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.requests = []
        self.backend_status = 200

        async def visualize(request):
            self.requests.append((request.method, dict(request.query), dict(request.headers)))
            return web.Response(
                status=self.backend_status,
                text='<!DOCTYPE html><html lang="en" class="light"><head>'
                '<script src="https://d3js.org/d3.v7.min.js"></script>'
                '<link href="https://fonts.googleapis.com/css2?family=Inter" rel="stylesheet">'
                '</head><body>synthetic graph</body></html>',
            )

        backend_app = web.Application()
        backend_app.router.add_get("/api/v1/visualize", visualize)
        self.backend = TestServer(backend_app)
        await self.backend.start_server()
        self.temp = tempfile.TemporaryDirectory()
        d3 = Path(self.temp.name) / "d3.js"
        d3.write_text("/* synthetic asset */")
        self.client = TestClient(TestServer(create_app(
            "server-only-key", d3, str(self.backend.make_url("/")).rstrip("/")
        )))
        await self.client.start_server()

    async def asyncTearDown(self):
        await self.client.close()
        await self.backend.close()
        self.temp.cleanup()

    async def test_view_preserves_graph_without_exposing_credentials_or_external_assets(self):
        response = await self.client.get("/graph/", headers={
            "X-Api-Key": "untrusted-browser-key", "Cookie": "private-browser-cookie"
        })
        html = await response.text()
        self.assertEqual(response.status, 200)
        self.assertIn("synthetic graph", html)
        self.assertIn('src="/graph/d3.js"', html)
        self.assertNotIn("https://", html)
        self.assertNotIn("server-only-key", html)
        self.assertEqual(response.headers["Cache-Control"], "no-store")
        self.assertIn("frame-ancestors 'none'", response.headers["Content-Security-Policy"])
        method, query, headers = self.requests[0]
        self.assertEqual(method, "GET")
        self.assertEqual(query["dataset_id"], DEFAULT_DATASET)
        self.assertEqual(headers["X-Api-Key"], "server-only-key")
        self.assertNotIn("Cookie", headers)

    async def test_no_mutation_or_general_api_proxy(self):
        for method, route in [("POST", "/graph/"), ("DELETE", "/graph/"),
                              ("GET", "/api/v1/forget"), ("GET", "/graph/api/v1/forget")]:
            response = await self.client.request(method, route)
            self.assertIn(response.status, (404, 405))
        self.assertEqual(self.requests, [])

    async def test_untrusted_targets_and_unbounded_options_are_rejected(self):
        for query in ["dataset_id=http://external.invalid", "max_nodes=5001",
                      "max_nodes=0", "full=anything", "url=http://external.invalid"]:
            response = await self.client.get("/graph/?" + query)
            self.assertEqual(response.status, 400)
        self.assertEqual(self.requests, [])

    async def test_backend_errors_do_not_leak_graph_response(self):
        self.backend_status = 403
        response = await self.client.get("/graph/")
        self.assertEqual(response.status, 502)
        self.assertNotIn("synthetic graph", await response.text())

    async def test_d3_asset_does_not_call_backend(self):
        response = await self.client.get("/graph/d3.js")
        self.assertEqual(response.status, 200)
        self.assertIn("synthetic asset", await response.text())
        self.assertEqual(self.requests, [])
