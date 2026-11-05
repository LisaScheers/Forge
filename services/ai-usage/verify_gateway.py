"""Exercise the real gateway against a local fake provider, without credentials or billing."""

import asyncio
import json
import os
from pathlib import Path
import subprocess


async def exercise(root):
    from aiohttp import ClientSession, web

    requests = []
    usage = {"prompt_tokens": 20, "completion_tokens": 7, "total_tokens": 27,
             "prompt_tokens_details": {"cached_tokens": 8},
             "completion_tokens_details": {"reasoning_tokens": 3}, "future_tokens": 2}

    async def complete(request):
        body = await request.json()
        requests.append(body)
        response_id = f"chatcmpl-{len(requests)}"
        base = {"id": response_id, "created": 1700000000, "model": "fixture"}
        if not body.get("stream"):
            return web.json_response({**base, "object": "chat.completion", "usage": usage,
                "choices": [{"index": 0, "message": {"role": "assistant", "content": "gateway-answer"},
                             "finish_reason": "stop"}]})
        response = web.StreamResponse(headers={"Content-Type": "text/event-stream"})
        await response.prepare(request)
        chunks = [
            {**base, "object": "chat.completion.chunk", "choices": [
                {"index": 0, "delta": {"role": "assistant", "content": "gateway-answer"}, "finish_reason": None}]},
            {**base, "object": "chat.completion.chunk", "choices": [
                {"index": 0, "delta": {}, "finish_reason": "stop"}]},
            {**base, "object": "chat.completion.chunk", "choices": [], "usage": usage},
        ]
        for chunk in chunks:
            await response.write(f"data: {json.dumps(chunk)}\n\n".encode())
        await response.write(b"data: [DONE]\n\n")
        await response.write_eof()
        return response

    async def codex_complete(request):
        await request.json()
        fixture = Path(__file__).with_name("codex_completion_fixture.jsonl")
        events = [json.loads(line) for line in fixture.read_text().splitlines()]
        events[-1]["response"]["usage"]["future_tokens"] = 2
        response = web.StreamResponse(headers={"Content-Type": "text/event-stream"})
        await response.prepare(request)
        for event in events:
            await response.write(f"event: {event['type']}\ndata: {json.dumps(event)}\n\n".encode())
        await response.write_eof()
        return response

    application = web.Application(client_max_size=8 * 1024 * 1024)
    application.router.add_post("/v1/chat/completions", complete)
    application.router.add_post("/v1/responses", codex_complete)
    runner = web.AppRunner(application, access_log=None)
    await runner.setup()
    server = web.TCPSite(runner, "127.0.0.1", 0)
    await server.start()
    provider_port = server._server.sockets[0].getsockname()[1]
    from test_integration import free_port
    proxy_port = free_port()
    config = root / "proxy.json"
    (root / "logs").mkdir()
    config.write_text(json.dumps({
        "host": "127.0.0.1", "port": proxy_port, "auth-dir": str(root / "auth"),
        "api-keys": ["fixture-client"], "request-log": True, "commercial-mode": False,
        "logs-max-total-size-mb": 0, "error-logs-max-files": 0, "ws-auth": True,
        "remote-management": {"secret-key": "", "disable-control-panel": True},
        "openai-compatibility": [{"name": "fixture", "base-url": f"http://127.0.0.1:{provider_port}/v1",
            "api-key-entries": [{"api-key": "fixture-provider"}],
            "models": [{"name": "fixture", "alias": "fixture"}]}],
        "codex-api-key": [{"api-key": "fixture-codex", "base-url": f"http://127.0.0.1:{provider_port}/v1",
                           "models": [{"name": "gpt-6.1-sol", "alias": "fixture-native"}]}],
    }))
    with (root / "proxy-output.txt").open("w+") as output:
        process = subprocess.Popen([os.environ["CLIPROXY_BINARY"], "-config", str(config)],
                                   cwd=root, stdout=output, stderr=output)
        try:
            async with ClientSession(headers={"Authorization": "Bearer fixture-client"}) as client:
                base_url = f"http://127.0.0.1:{proxy_port}"
                for _ in range(200):
                    try:
                        async with client.get(f"{base_url}/v1/models") as response:
                            if response.status == 200:
                                break
                    except OSError:
                        pass
                    if process.poll() is not None:
                        output.seek(0)
                        raise AssertionError(output.read())
                    await asyncio.sleep(0.05)
                else:
                    raise AssertionError("Gateway did not start")
                # Exceeds the upstream error-only logger's 1 MiB limit.
                prompt = "gateway-prompt-" + "🦊" * 300000
                async with client.post(f"{base_url}/v1/chat/completions", json={"model": "fixture",
                    "messages": [{"role": "user", "content": prompt}]}) as response:
                    assert response.status == 200, await response.text()
                    assert (await response.json())["choices"][0]["message"]["content"] == "gateway-answer"
                async with client.post(f"{base_url}/v1/responses", json={"model": "fixture",
                    "input": "gateway-stream", "stream": True}) as response:
                    assert response.status == 200, await response.text()
                    text = await response.text()
                    assert "response.completed" in text, text
                    assert "gateway-answer" in text, text
                async with client.ws_connect(f"{base_url}/v1/responses") as connection:
                    await connection.send_json({"type": "response.create", "model": "fixture", "input": [{"role": "user", "content": "gateway-websocket"}]})
                    for _ in range(100):
                        event = await connection.receive_json(timeout=10)
                        assert event.get("type") != "error", event
                        if event.get("type") == "response.completed":
                            break
                    else:
                        raise AssertionError("WebSocket did not complete")
                assert len(requests) == 3, len(requests)
                assert prompt in json.dumps(requests, ensure_ascii=False)
                async with client.post(f"{base_url}/v1/responses", json={"model": "fixture-native", "input": "native-capture"}) as response:
                    assert response.status == 200, await response.text()
                    native = await response.json()
                    assert native["output"][0]["content"][0]["text"], native
                async with client.post(f"{base_url}/v1/responses", json={"model": "fixture-native", "input": "native-stream", "stream": True}) as response:
                    assert response.status == 200, await response.text()
                    assert "response.completed" in await response.text()
                async with client.ws_connect(f"{base_url}/v1/responses") as connection:
                    await connection.send_json({"type": "response.create", "model": "fixture-native", "input": [{"role": "user", "content": "native-websocket"}]})
                    for _ in range(100):
                        event = await connection.receive_json(timeout=10)
                        assert event.get("type") != "error", event
                        if event.get("type") == "response.completed":
                            break
                    else:
                        raise AssertionError("Native Codex WebSocket did not complete")
            # Request logs are assembled as the HTTP/WS handlers finish.
            for _ in range(100):
                captures = list((root / "logs").glob("*.log"))
                if sum("API RESPONSE" in f.read_text() for f in captures) >= 6:
                    break
                await asyncio.sleep(0.05)
            else:
                raise AssertionError("Gateway failed to write all six captures")
        finally:
            process.terminate()
            await asyncio.to_thread(process.wait, timeout=15)
            await runner.cleanup()
    return captures


def verify(root):
    return asyncio.run(exercise(Path(root)))
