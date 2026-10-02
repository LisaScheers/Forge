"""Provision the private MCP backend user and reuse its persisted API key."""

import asyncio
import json
import os
from pathlib import Path
import tempfile

import aiohttp

BASE = "http://127.0.0.1:8321/api/v1"


async def main():
    key_file = Path(os.environ["COGNEE_MCP_KEY_FILE"])
    async with aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=30)) as session:
        for attempt in range(120):
            try:
                async with session.get("http://127.0.0.1:8321/health") as response:
                    if response.status == 200:
                        break
            except aiohttp.ClientError:
                pass
            await asyncio.sleep(2)
        else:
            raise RuntimeError("Cognee API did not become healthy.")

        if key_file.exists():
            key = key_file.read_text().strip().removeprefix("COGNEE_API_KEY=")
            async with session.get(f"{BASE}/auth/me", headers={"X-Api-Key": key}) as response:
                if response.status != 200:
                    raise RuntimeError("Persisted MCP API key was revoked; re-provision it deliberately.")
            return

        email = os.environ["COGNEE_MCP_EMAIL"]
        password = os.environ["COGNEE_MCP_PASSWORD"]
        async with session.post(f"{BASE}/auth/register", json={"email": email, "password": password}) as response:
            if response.status not in {200, 201}:
                payload = await response.json()
                if response.status != 400 or payload.get("detail") != "REGISTER_USER_ALREADY_EXISTS":
                    raise RuntimeError("Could not register the MCP backend account.")
        async with session.post(f"{BASE}/auth/login", data={"username": email, "password": password}) as response:
            if response.status != 200:
                raise RuntimeError("Could not authenticate the MCP backend account.")
            token = (await response.json())["access_token"]
        async with session.post(f"{BASE}/auth/api-keys", json={"name": "nook-mcp"},
                                headers={"Authorization": f"Bearer {token}"}) as response:
            if response.status != 200:
                raise RuntimeError("Could not issue the MCP backend key.")
            key = (await response.json())["key"]
        descriptor, temporary = tempfile.mkstemp(dir=key_file.parent)
        try:
            with os.fdopen(descriptor, "w") as output:
                output.write(f"COGNEE_API_KEY={key}\n")
                output.flush()
                os.fsync(output.fileno())
            os.replace(temporary, key_file)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)


if __name__ == "__main__":
    asyncio.run(main())
