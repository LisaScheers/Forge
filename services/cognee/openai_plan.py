"""Cognee's text Chat Completions adapter for OpenAI's ChatGPT plan OAuth flow.

Only the documented public Responses endpoint is used. Credentials are separate
from Codex, refreshes are serialized, and failed/incomplete streams fail closed.
"""

import argparse
import asyncio
import base64
import hashlib
import json
import os
from pathlib import Path
import secrets
import tempfile
import time
import urllib.parse

import aiohttp
from aiohttp import web
import jwt

ISSUER = "https://auth.openai.com"
RESOURCE = "https://api.openai.com/v1"
TOKEN_URL = f"{ISSUER}/api/accounts/oauth/token"
MODEL = "gpt-6-luna"
SCOPES = "openid profile email offline_access resource.invoke chatgpt.tokens.use.direct"


def save_credentials(file_path, record):
    file_path = Path(file_path)
    file_path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(dir=file_path.parent)
    try:
        with os.fdopen(descriptor, "w") as output:
            json.dump(record, output)
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary, file_path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def token_record(tokens, previous):
    scopes = tokens.get("scope", " ".join(previous.get("scopes", []))).split()
    if "chatgpt.tokens.use.direct" not in scopes:
        raise RuntimeError("ChatGPT plan permission was not granted; authorize it in ChatGPT.")
    return {
        **previous,
        **tokens,
        "scopes": scopes,
        "expires_at": time.time() + int(tokens["expires_in"]),
    }


async def exchange(session, fields):
    async with session.post(TOKEN_URL, data=fields, allow_redirects=False) as response:
        if response.status != 200:
            raise RuntimeError("OpenAI token exchange failed; sign in again (credentials withheld).")
        return await response.json()


async def login(file_path, host_id):
    previous = json.loads(file_path.read_text()) if file_path.exists() else {}
    if previous and previous.get("ext_agent_host_id") != host_id:
        raise RuntimeError("Credential host ID differs; use a separate credential file for Nook.")
    state, nonce, verifier = (secrets.token_urlsafe(32) for _ in range(3))
    challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).decode().rstrip("=")
    result = asyncio.get_running_loop().create_future()

    async def callback(request):
        if not secrets.compare_digest(request.query.get("state", ""), state):
            raise web.HTTPBadRequest(text="Invalid OAuth state.")
        if not result.done():
            result.set_result(dict(request.query))
        return web.Response(text="Cognee received the callback. Return to the terminal for validation.")

    app = web.Application()
    app.router.add_get("/auth/callback", callback)
    runner = web.AppRunner(app, access_log=None)
    await runner.setup()
    site = web.TCPSite(runner, "127.0.0.1", 0)
    await site.start()
    port = runner.addresses[0][1]
    redirect_uri = f"http://127.0.0.1:{port}/auth/callback"
    issued_id = previous.get("client_id")
    fields = {
        "client_id": issued_id or "dynamic_agent_client",
        "ext_agent_host_id": host_id,
        "response_type": "code",
        "redirect_uri": redirect_uri,
        "scope": SCOPES,
        "resource": RESOURCE,
        "state": state,
        "nonce": nonce,
        "code_challenge_method": "S256",
        "code_challenge": challenge,
    }
    if not issued_id:
        fields["agent_name_hint"] = "Forge Cognee"
    # Do not print a retained ID token in an authorization URL.
    print("Continue with ChatGPT: open this URL on this computer.")
    print(f"{ISSUER}/api/accounts/authorize?{urllib.parse.urlencode(fields)}", flush=True)
    try:
        callback_data = await asyncio.wait_for(result, 600)
        if "error" in callback_data:
            raise RuntimeError("ChatGPT authorization was declined.")
        client_id = callback_data.get("client_id", issued_id)
        if not client_id or client_id == "dynamic_agent_client" or (issued_id and client_id != issued_id):
            raise RuntimeError("OpenAI returned an invalid client registration.")
        async with aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=30)) as session:
            tokens = await exchange(session, {
                "grant_type": "authorization_code",
                "client_id": client_id,
                "code": callback_data["code"],
                "code_verifier": verifier,
                "redirect_uri": redirect_uri,
                "resource": RESOURCE,
            })
        # PyJWT fetches only the issuer's published JWKS and verifies signature,
        # audience, issuer, expiration and required identity claims.
        key_client = jwt.PyJWKClient(f"{ISSUER}/.well-known/jwks.json")
        signing_key = await asyncio.to_thread(key_client.get_signing_key_from_jwt, tokens["id_token"])
        claims = jwt.decode(tokens["id_token"], signing_key.key, algorithms=["RS256"],
                            audience=client_id, issuer=ISSUER,
                            options={"require": ["exp", "iss", "aud", "sub", "nonce"]})
        if not secrets.compare_digest(claims["nonce"], nonce):
            raise RuntimeError("Invalid OpenAI ID-token nonce.")
        if previous and previous["subject"] != claims["sub"]:
            raise RuntimeError("This registration belongs to a different ChatGPT account.")
        record = token_record(tokens, {
            "client_id": client_id, "ext_agent_host_id": host_id,
            "subject": claims["sub"], "email": claims.get("email"), "issuer": ISSUER,
        })
        save_credentials(file_path, record)
        print(f"Credentials saved privately to {file_path}. Model access still needs verification.")
    finally:
        await runner.cleanup()


class PlanClient:
    def __init__(self, credentials, session):
        self.credentials = Path(credentials)
        self.session = session
        self.lock = asyncio.Lock()

    async def access_token(self):
        async with self.lock:
            try:
                record = json.loads(self.credentials.read_text())
            except FileNotFoundError:
                raise web.HTTPServiceUnavailable(text="Cognee's ChatGPT plan has not been authorized.") from None
            if "chatgpt.tokens.use.direct" not in record["scopes"]:
                raise web.HTTPServiceUnavailable(text="ChatGPT plan permission is missing.")
            if record["expires_at"] <= time.time() + 60:
                tokens = await exchange(self.session, {
                    "grant_type": "refresh_token", "client_id": record["client_id"],
                    "refresh_token": record["refresh_token"], "resource": RESOURCE,
                })
                record = token_record(tokens, record)
                save_credentials(self.credentials, record)
            return record["access_token"]

    async def complete(self, body, max_output_tokens=None):
        token = await self.access_token()
        async with self.session.post(f"{RESOURCE}/responses", json=body,
                                     headers={"Authorization": f"Bearer {token}",
                                              "User-Agent": "forge-cognee/1.0"},
                                     allow_redirects=False) as response:
            if response.status != 200:
                if response.status == 429:
                    raise web.HTTPTooManyRequests(text="ChatGPT plan usage limit reached.")
                raise web.HTTPBadGateway(text="OpenAI rejected Cognee inference; check plan access.")
            return await completed_response(response.content, max_output_tokens)


async def completed_response(content, max_output_tokens=None):
    data_lines = []
    final_items = {}
    async for raw_line in content:
        line = raw_line.decode("utf-8").rstrip("\r\n")
        if line.startswith("data:"):
            data_lines.append(line[5:].lstrip())
        elif not line and data_lines:
            payload = "\n".join(data_lines)
            data_lines.clear()
            if payload == "[DONE]":
                continue
            event = json.loads(payload)
            if event.get("type") == "response.output_item.done":
                final_items[event["output_index"]] = event["item"]
            if event.get("type") == "response.completed":
                response = event["response"]
                if response.get("status") != "completed":
                    raise web.HTTPBadGateway(text="OpenAI response did not complete.")
                if max_output_tokens is not None and response.get("usage", {}).get("output_tokens", 0) > max_output_tokens:
                    raise web.HTTPBadGateway(text="OpenAI output exceeded Cognee's requested token budget.")
                # Plan streams finalize each item separately; response.completed
                # may carry an empty output list. Never release items before it.
                if not response.get("output"):
                    response = {**response, "output": [final_items[index] for index in sorted(final_items)]}
                return response
            if event.get("type") in {"response.failed", "response.incomplete", "error"}:
                code = (event.get("response", {}).get("error") or event).get("code")
                if code in {"subscription_sharing_usage_limit_exceeded", "subscription_sharing_usage_unavailable"}:
                    raise web.HTTPTooManyRequests(text="ChatGPT plan usage is unavailable or exhausted.")
                raise web.HTTPBadGateway(text="OpenAI inference failed or was incomplete.")
    raise web.HTTPBadGateway(text="OpenAI stream ended without response.completed.")


def responses_request(body):
    if not isinstance(body, dict):
        raise web.HTTPBadRequest(text="A JSON object is required.")
    if body.get("model") != MODEL:
        raise web.HTTPBadRequest(text=f"Only {MODEL} is configured.")
    if body.get("stream") or body.get("tools"):
        raise web.HTTPBadRequest(text="This adapter serves Cognee's non-streaming text extraction only.")
    messages = body.get("messages")
    if not isinstance(messages, list) or not messages:
        raise web.HTTPBadRequest(text="A non-empty messages list is required.")
    if any(not isinstance(message, dict) or message.get("role") not in {"system", "developer", "user", "assistant"}
           or not isinstance(message.get("content"), str) for message in messages):
        raise web.HTTPBadRequest(text="Only text messages are supported.")
    request = {"model": MODEL, "input": messages, "store": False, "stream": True,
               "reasoning": {"effort": "low"}}
    response_format = body.get("response_format", {"type": "text"})
    if response_format["type"] == "json_schema":
        request["text"] = {"format": {"type": "json_schema", **response_format["json_schema"]}}
    elif response_format["type"] in {"json_object", "text"}:
        request["text"] = {"format": response_format}
    else:
        raise web.HTTPBadRequest(text="Unsupported structured output format.")
    maximum = body.get("max_completion_tokens", body.get("max_tokens"))
    if maximum is not None and (isinstance(maximum, bool) or not isinstance(maximum, int) or maximum <= 0):
        raise web.HTTPBadRequest(text="The output token budget must be a positive integer.")
    # The subscription endpoint rejects max_output_tokens. Check the completed
    # usage against Cognee's budget instead; this cannot cap provider consumption.
    return request


def chat_response(response):
    blocks = [block for item in response.get("output", []) if item.get("type") == "message"
              for block in item.get("content", [])]
    if any(block.get("type") == "refusal" for block in blocks):
        raise web.HTTPBadGateway(text="OpenAI refused the extraction request.")
    text = "".join(block["text"] for block in blocks if block.get("type") == "output_text")
    if not text:
        raise web.HTTPBadGateway(text="OpenAI completed without text output.")
    usage = response.get("usage", {})
    return {"id": response["id"], "object": "chat.completion", "created": int(time.time()), "model": MODEL,
            "choices": [{"index": 0, "message": {"role": "assistant", "content": text}, "finish_reason": "stop"}],
            "usage": {"prompt_tokens": usage.get("input_tokens", 0), "completion_tokens": usage.get("output_tokens", 0),
                      "total_tokens": usage.get("total_tokens", 0)}}


def application(credentials, api_key, session):
    client = PlanClient(credentials, session)

    @web.middleware
    async def authenticate(request, handler):
        if not secrets.compare_digest(request.headers.get("Authorization", ""), f"Bearer {api_key}"):
            raise web.HTTPUnauthorized()
        try:
            return await handler(request)
        except web.HTTPException:
            raise
        except (aiohttp.ClientError, TimeoutError, RuntimeError):
            raise web.HTTPBadGateway(text="ChatGPT plan connection failed; check authorization.") from None
        except (KeyError, TypeError, ValueError):
            raise web.HTTPBadRequest(text="Invalid request or credential record.") from None

    async def complete(request):
        body = await request.json()
        inference = responses_request(body)
        maximum = body.get("max_completion_tokens", body.get("max_tokens"))
        return web.json_response(chat_response(await client.complete(inference, maximum)))

    async def models(request):
        await client.access_token()
        # Report the adapter's configured model. The plan catalog can omit a
        # working model; a completed inference is the actual entitlement check.
        return web.json_response({"object": "list", "data": [{"id": MODEL, "object": "model", "owned_by": "openai"}]})

    app = web.Application(middlewares=[authenticate], client_max_size=4 * 1024 * 1024)
    app.router.add_post("/v1/chat/completions", complete)
    app.router.add_get("/v1/models", models)
    return app


async def serve(credentials, api_key, port):
    async with aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=600)) as session:
        runner = web.AppRunner(application(credentials, api_key, session), access_log=None)
        await runner.setup()
        await web.TCPSite(runner, "127.0.0.1", port).start()
        try:
            await asyncio.Event().wait()
        finally:
            await runner.cleanup()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["login", "serve"])
    parser.add_argument("--credentials", type=Path, required=True)
    parser.add_argument("--host-id")
    parser.add_argument("--port", type=int, default=8320)
    args = parser.parse_args()
    if args.mode == "login":
        if not args.host_id:
            parser.error("--host-id is required for Nook's stable registration")
        asyncio.run(login(args.credentials, args.host_id))
    else:
        asyncio.run(serve(args.credentials, os.environ["LLM_API_KEY"], args.port))
