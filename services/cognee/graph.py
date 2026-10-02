"""Serve Cognee's built-in graph through nginx's Authentik boundary.

Only the visualization GET is exposed. The account key stays server-side;
the browser receives neither credentials nor a general-purpose API proxy.
"""

import asyncio
import os
import re
from pathlib import Path
from uuid import UUID

import aiohttp
from aiohttp import web

DEFAULT_DATASET = "edc596a4-8460-59c4-bcc6-34bc213c32fa"
HEADERS = {
    "Cache-Control": "no-store",
    "Referrer-Policy": "no-referrer",
    "X-Content-Type-Options": "nosniff",
    "Content-Security-Policy": (
        "default-src 'self'; script-src 'self' 'unsafe-inline'; "
        "style-src 'self' 'unsafe-inline'; img-src 'self' data:; "
        "object-src 'none'; base-uri 'none'; frame-ancestors 'none'; form-action 'none'"
    ),
}


def private_assets(html: str) -> str:
    html = html.replace('src="https://d3js.org/d3.v7.min.js"', 'src="/graph/d3.js"')
    html = re.sub(r'<link\b[^>]*href="https://fonts\.(?:googleapis|gstatic)\.com[^>]*>', "", html)
    # Preserve upstream's theme toggle and saved preference, defaulting to dark.
    html = html.replace('<html lang="en" class="light">', '<html lang="en">')
    html = html.replace("applyTheme(stored ? stored === 'light' : true);", "applyTheme(stored ? stored === 'light' : false);")
    return html


def create_app(api_key: str, d3_file: Path, backend: str = "http://127.0.0.1:8321") -> web.Application:
    app = web.Application()
    busy = asyncio.Lock()

    async def session_context(app):
        async with aiohttp.ClientSession(
            headers={"X-Api-Key": api_key}, timeout=aiohttp.ClientTimeout(total=150)
        ) as session:
            app[session_key] = session
            yield

    async def graph(request):
        try:
            dataset = str(UUID(request.query.get("dataset_id", DEFAULT_DATASET)))
            max_nodes = int(request.query.get("max_nodes", "500"))
            full = request.query.get("full", "false")
            if not 1 <= max_nodes <= 5000 or full not in {"true", "false"}:
                raise ValueError
            if set(request.query) - {"dataset_id", "max_nodes", "full"}:
                raise ValueError
        except ValueError:
            raise web.HTTPBadRequest(text="Invalid graph options", headers=HEADERS)
        if busy.locked():
            raise web.HTTPServiceUnavailable(text="Graph rendering in progress; retry shortly", headers=HEADERS)
        async with busy:
            try:
                async with app[session_key].get(
                    f"{backend}/api/v1/visualize",
                    params={"dataset_id": dataset, "max_nodes": str(max_nodes), "full": full},
                    allow_redirects=False,
                ) as response:
                    if response.status != 200:
                        raise web.HTTPBadGateway(text="Cognee could not render this graph", headers=HEADERS)
                    html = await response.text()
            except (aiohttp.ClientError, TimeoutError):
                raise web.HTTPBadGateway(text="Cognee graph service unavailable", headers=HEADERS)
        return web.Response(text=private_assets(html), content_type="text/html", headers=HEADERS)

    async def d3(request):
        return web.FileResponse(d3_file, headers={**HEADERS, "Content-Type": "application/javascript"})

    session_key = web.AppKey("backend_session", aiohttp.ClientSession)
    app.cleanup_ctx.append(session_context)
    app.router.add_get("/graph/", graph)
    app.router.add_get("/graph/d3.js", d3)
    return app


if __name__ == "__main__":
    web.run_app(
        create_app(os.environ["COGNEE_API_KEY"], Path(os.environ["COGNEE_GRAPH_D3"])),
        path="/run/cognee-graph/http.sock", access_log=None, print=None,
    )
