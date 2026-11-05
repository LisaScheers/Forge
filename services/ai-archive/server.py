"""Private, read-only conversation browser. Nginx supplies the authenticated user."""

import asyncio
from contextlib import closing, suppress
import logging
import os
from pathlib import Path
import re

from aiohttp import web

from store import ClickHouse, Store

ROOT = Path(__file__).parent / "public"
SECURITY = {
    "Cache-Control": "private, no-store",
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "no-referrer",
    "Content-Security-Policy": "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'; form-action 'self'",
}
IDENTITY = re.compile(r"[a-f0-9]{64}")


def filters(request):
    allowed = {"days", "model", "client", "provider", "status", "q", "offset"}
    if set(request.query) - allowed:
        raise web.HTTPBadRequest(text="Unknown filter")
    result = {}
    try:
        days = int(request.query.get("days", "7"))
        if days not in {0, 1, 7, 30, 90, 365}:
            raise ValueError
        result["days"] = days
        for key in ("model", "client", "provider", "status", "q"):
            value = request.query.get(key, "")
            if len(value) > 200:
                raise ValueError
            result[key] = value
    except ValueError:
        raise web.HTTPBadRequest(text="Invalid filter")
    return result


def integer(request, key, default=0):
    try:
        value = int(request.query.get(key, default))
        if not 0 <= value <= 10000000:
            raise ValueError
        return value
    except (ValueError, TypeError):
        raise web.HTTPBadRequest(text="Invalid pagination")


def identity(request):
    value = request.match_info["identity"]
    if not IDENTITY.fullmatch(value):
        raise web.HTTPNotFound()
    return value


def create_app(store, user="lisa", sync=True):
    @web.middleware
    async def boundary(request, handler):
        try:
            if request.path != "/health" and request.headers.get("X-AI-User") != user:
                return web.json_response({"error": "Sign in required"}, status=401, headers=SECURITY)
            response = await handler(request)
        except KeyError:
            response = web.json_response({"error": "Not found"}, status=404)
        except web.HTTPException as error:
            response = web.json_response({"error": error.reason}, status=error.status)
        except Exception:
            logging.exception("AI archive request failed")
            response = web.json_response({"error": "Archive unavailable; retry shortly"}, status=503)
        response.headers.update(SECURITY)
        return response

    app = web.Application(middlewares=[boundary], client_max_size=1024)

    async def health(request):
        return web.json_response({"status": "ok"})

    async def status(request):
        return web.json_response(await asyncio.to_thread(store.status))

    async def conversations(request):
        options = filters(request)
        offset = integer(request, "offset")
        return web.json_response(await asyncio.to_thread(store.conversations, options, offset))

    async def conversation(request):
        if set(request.query) - {"before"}:
            raise web.HTTPBadRequest()
        before = integer(request, "before") if "before" in request.query else None
        return web.json_response(await asyncio.to_thread(store.conversation, identity(request), before))

    async def detail(request):
        return web.json_response(await asyncio.to_thread(store.request, identity(request)))

    async def raw(request):
        capture = identity(request)
        with closing(store.connect()) as db:
            if not db.execute("SELECT 1 FROM captures WHERE id=?", (capture,)).fetchone():
                raise web.HTTPNotFound()
        transcript = await asyncio.to_thread(store.backend.transcript, capture)
        return web.Response(text=transcript, content_type="text/plain", headers={
            "Content-Disposition": f'attachment; filename="capture-{capture}.log"'})

    async def analytics(request):
        return web.json_response(await asyncio.to_thread(store.analytics, filters(request)))

    async def asset(request):
        name = request.match_info.get("asset", "index.html")
        if name not in {"index.html", "app.js", "style.css", "favicon.svg"}:
            raise web.HTTPNotFound()
        return web.FileResponse(ROOT / name)

    async def indexing(application):
        async def loop():
            while True:
                try:
                    await asyncio.to_thread(store.sync)
                except Exception:
                    logging.exception("ClickHouse archive indexing failed")
                await asyncio.sleep(3 if store.pending else 15)
        worker = asyncio.create_task(loop())
        yield
        worker.cancel()
        with suppress(asyncio.CancelledError):
            await worker

    if sync:
        app.cleanup_ctx.append(indexing)
    app.router.add_get("/health", health)
    app.router.add_get("/api/status", status)
    app.router.add_get("/api/conversations", conversations)
    app.router.add_get("/api/conversations/{identity}", conversation)
    app.router.add_get("/api/requests/{identity}", detail)
    app.router.add_get("/api/captures/{identity}/raw", raw)
    app.router.add_get("/api/analytics", analytics)
    app.router.add_get("/", asset)
    app.router.add_get("/{asset}", asset)
    return app


if __name__ == "__main__":
    # The socket is shared with nginx; the index is inside a mode-0700 state directory.
    os.umask(0o007)
    logging.basicConfig(level=logging.INFO)
    backend = ClickHouse(os.environ.get("AI_ARCHIVE_CLICKHOUSE", "http://127.0.0.1:8123"), os.environ["AI_USAGE_CLICKHOUSE_PASSWORD"])
    state = Path(os.environ.get("STATE_DIRECTORY", "/var/lib/ai-archive"))
    archive = Store(state / "index.sqlite", backend)
    socket = Path(os.environ.get("AI_ARCHIVE_SOCKET", "/run/ai-archive/http.sock"))
    socket.unlink(missing_ok=True)
    web.run_app(create_app(archive), path=str(socket), access_log=None, print=None)
