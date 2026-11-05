"""Project captured wire transcripts into readable turns without changing the archive."""

import hashlib
import io
import json
import re
from datetime import datetime, timezone

SECTION = re.compile(r"^=== (.+?) ===$", re.M)


def digest(value):
    return hashlib.sha256(value.encode()).hexdigest()


def sections(text):
    matches = list(SECTION.finditer(text))
    return [(match[1], text[match.end():matches[index + 1].start() if index + 1 < len(matches) else len(text)].strip())
            for index, match in enumerate(matches)
            if match[1] in {"HEADERS", "REQUEST INFO", "REQUEST BODY", "RESPONSE", "WEBSOCKET TIMELINE"}]


def records(text):
    pending = ""
    for line in io.StringIO(text):
        line = line.removeprefix("data:").strip()
        if not pending and not (line.startswith("{") or line == "[" or re.match(r"^\[\s*\{", line)):
            continue
        pending += line + "\n"
        try:
            value = json.loads(pending)
        except json.JSONDecodeError:
            continue
        pending = ""
        for record in value if isinstance(value, list) else [value]:
            if isinstance(record, dict):
                yield record


def content_text(value):
    if isinstance(value, str):
        return value
    if isinstance(value, list):
        return "\n".join(filter(None, (content_text(item) for item in value)))
    if isinstance(value, dict):
        for key in ("text", "content", "parts", "summary"):
            if key in value:
                return content_text(value[key])
        return json.dumps(value, ensure_ascii=False, indent=2)
    return "" if value is None else str(value)


def messages(value, default_role="user"):
    if isinstance(value, str):
        return [{"role": default_role, "kind": "message", "text": value}]
    result = []
    for item in value if isinstance(value, list) else [value]:
        if not isinstance(item, dict):
            continue
        kind = item.get("type", "message")
        if kind in {"function_call", "tool_use"}:
            result.append({"role": "assistant", "kind": "tool_call", "tool": item.get("name", "tool"),
                           "text": content_text(item.get("arguments", item.get("input"))), "call_id": item.get("call_id", item.get("id", ""))})
        elif kind in {"function_call_output", "tool_result"}:
            result.append({"role": "tool", "kind": "tool_result", "text": content_text(item.get("output", item.get("content"))),
                           "call_id": item.get("call_id", item.get("tool_use_id", ""))})
        else:
            text = content_text(item.get("content", item.get("parts", item.get("summary"))))
            if not text and kind not in {"message", "reasoning"}:
                text = content_text(item)
            if text:
                result.append({"role": item.get("role", default_role), "kind": kind, "text": text})
    return result


def normalize_tokens(tokens):
    def first(*names):
        return next((int(tokens[name]) for name in names if name in tokens), None)
    input_count = first("input_tokens", "prompt_tokens", "promptTokenCount")
    output_count = first("output_tokens", "completion_tokens", "candidatesTokenCount")
    reasoning = first("output_tokens_details.reasoning_tokens", "completion_tokens_details.reasoning_tokens", "thoughtsTokenCount")
    cached = first("input_tokens_details.cached_tokens", "prompt_tokens_details.cached_tokens", "cachedContentTokenCount", "cache_read_input_tokens")
    if "promptTokenCount" in tokens and output_count is not None:
        output_count += int(tokens.get("thoughtsTokenCount", 0))
    if input_count is not None and any(key in tokens for key in ("cache_read_input_tokens", "cache_creation_input_tokens")):
        input_count += int(tokens.get("cache_read_input_tokens", 0)) + int(tokens.get("cache_creation_input_tokens", 0))
    total = first("total_tokens", "totalTokenCount")
    if total is None and input_count is not None and output_count is not None:
        total = input_count + output_count
    return {"input_tokens": input_count, "output_tokens": output_count, "cached_tokens": cached,
            "reasoning_tokens": reasoning, "total_tokens": total}


def message_key(message):
    return digest(json.dumps(message, sort_keys=True, ensure_ascii=False))


def merge_messages(existing, incoming):
    """Replayed context overlaps the history; repeated new user messages remain distinct."""
    if not incoming:
        return existing
    previous = [message_key(item) for item in existing]
    following = [message_key(item) for item in incoming]
    for size in range(min(len(previous), len(following)), 0, -1):
        if previous[-size:] == following[:size]:
            return existing + incoming[size:]
    if previous and previous[-1] in following:
        last = len(following) - 1 - following[::-1].index(previous[-1])
        return existing + incoming[last + 1:]
    return existing + incoming


def title_for(items):
    for item in reversed(items):
        if item["role"] != "user":
            continue
        text = re.sub(r"<(environment_context|external_browser_tabs|external_codex_apps_open_page)\b.*?</\1>", "", item["text"], flags=re.S).strip()
        if text and not text.startswith(("<environment_context", "<external_", "# AGENTS.md", "<INSTRUCTIONS>")):
            return re.sub(r"\s+", " ", text)[:120]
    return "Captured request"


def parse_capture(row, usage):
    parts = sections(row["transcript"])
    headers = {}
    for name, body in parts:
        if name in {"HEADERS", "REQUEST INFO"}:
            for line in body.splitlines():
                key, separator, value = line.partition(":")
                if separator:
                    headers[key.lower()] = value.strip()
    timestamp = headers.get("timestamp", "")
    try:
        started = datetime.fromisoformat(timestamp.replace("Z", "+00:00")).astimezone(timezone.utc).isoformat()
    except ValueError:
        started = row["observed_at"].replace(" ", "T") + "Z"
    agent = headers.get("user-agent", "").lower()
    client = "Codex" if "codex" in agent else "Antigravity" if "antigravity" in agent else "Python client" if "python" in agent else "API client"
    body = next((body for name, body in parts if name == "REQUEST BODY"), "")
    request = next(records(body), {})
    websocket = next((body for name, body in parts if name == "WEBSOCKET TIMELINE"), None)
    turns = []
    current = None

    def new_turn(payload):
        metadata = payload.get("client_metadata") or {}
        if not isinstance(metadata, dict):
            metadata = {}
        identity = metadata.get("thread_id") or metadata.get("session_id") or payload.get("conversation_id")
        if not identity:
            identity = next((headers[key] for key in ("session_id", "session-id", "conversation-id", "x-session-id") if headers.get(key)), None)
        session = str(identity) if identity else ""
        model = str(payload.get("model") or request.get("model") or "")
        if not model:
            match = re.search(r"models/(.+?):(?:streamGenerateContent|generateContent)", headers.get("url", ""))
            model = match[1] if match else "Unknown model"
        inputs = messages(payload.get("input", payload.get("messages", payload.get("contents", []))))
        system = payload.get("systemInstruction", payload.get("instructions"))
        if system:
            inputs.insert(0, {"role": "system", "kind": "message", "text": content_text(system)})
        provider = "OpenRouter" if model.startswith("openrouter/") else "Antigravity" if model.startswith("gemini") else "Codex" if model.startswith(("gpt-", "o3", "o4")) else "Other"
        return {"session_id": session, "conversation_id": digest("session:" + session) if session else digest("capture:" + row["capture_id"]),
                "grouping": "session" if session else "request", "started_at": started, "model": model,
                "client": client, "provider": provider, "title": title_for(inputs), "input": inputs, "output": [],
                "response_id": "", "status": "unknown", "items": {}, "delta": ""}

    def apply_event(turn, event):
        kind = event.get("type", "")
        # Non-streaming Responses return the response object without an event envelope.
        if event.get("object") == "response" and isinstance(event.get("output"), list):
            event = {"type": {"failed": "response.failed", "incomplete": "response.incomplete"}.get(event.get("status"), "response.completed"), "response": event}
            kind = event["type"]
        response = event.get("response", {})
        if isinstance(response, dict) and response.get("id"):
            turn["response_id"] = str(response["id"])
        if kind == "response.output_item.done" and isinstance(event.get("item"), dict):
            item = event["item"]
            turn["items"][item.get("id", str(len(turn["items"])))] = item
        elif kind == "response.output_text.delta":
            turn["delta"] += str(event.get("delta", ""))
        elif kind == "message_start":
            turn["response_id"] = str(event.get("message", {}).get("id", ""))
        elif kind == "content_block_start" and isinstance(event.get("content_block"), dict):
            block = event["content_block"]
            turn["items"][str(event.get("index", len(turn["items"])))] = block
        elif kind == "content_block_delta":
            delta = event.get("delta", {})
            turn["delta"] += content_text(delta.get("text", delta.get("thinking")))
        elif kind == "message_stop":
            turn["output"] = messages(list(turn["items"].values()), "assistant")
            turn["status"] = "success"
        elif kind in {"response.completed", "response.done", "response.incomplete", "response.failed"}:
            output = response.get("output") or list(turn["items"].values())
            turn["output"] = messages(output, "assistant")
            turn["status"] = "error" if kind == "response.failed" else "incomplete" if kind == "response.incomplete" else "success"
        elif kind == "error" or "error" in event:
            turn["status"] = "error"
            turn["error"] = content_text(event.get("error", event))
        if isinstance(event.get("choices"), list):
            turn["response_id"] = str(event.get("id", turn["response_id"]))
            for choice in event["choices"]:
                if choice.get("message"):
                    turn["output"] += messages([choice["message"]], "assistant")
                turn["delta"] += content_text(choice.get("delta", {}).get("content"))
                if choice.get("finish_reason"):
                    turn["status"] = "success"
        if isinstance(event.get("candidates"), list):
            for candidate in event["candidates"]:
                for part in candidate.get("content", {}).get("parts", []):
                    if "text" in part:
                        turn["output"].append({"role": "assistant", "kind": "reasoning" if part.get("thought") else "message", "text": part["text"]})
                    elif part:
                        turn["output"].append({"role": "assistant", "kind": "tool_call", "text": content_text(part)})
                if candidate.get("finishReason"):
                    turn["status"] = "success"

    if websocket is not None:
        for event in records(websocket):
            if event.get("type") in {"response.create", "response.append"}:
                if current:
                    turns.append(current)
                current = new_turn(event)
            elif current:
                apply_event(current, event)
        if current:
            turns.append(current)
    else:
        current = new_turn(request)
        downstream = next((body for name, body in parts if name == "RESPONSE"), "")
        for event in records(downstream):
            apply_event(current, event)
        turns.append(current)
    if not turns:
        turns.append(new_turn(request))
    used_usage = set()
    for index, turn in enumerate(turns):
        turn["id"] = digest(f"{row['capture_id']}:{index}")
        turn["capture_id"] = row["capture_id"]
        turn["file_name"] = row["file_name"]
        turn["ordinal"] = index
        key = turn["response_id"]
        tokens = usage.get(key, {})
        if key in used_usage:
            tokens = {}
        else:
            used_usage.add(key)
        turn["tokens"] = tokens
        turn.update(normalize_tokens(tokens))
        if not turn["output"] and turn["delta"]:
            turn["output"] = [{"role": "assistant", "kind": "message", "text": turn["delta"]}]
        if turn["status"] == "unknown" and turn["output"]:
            turn["status"] = "success"
        for field in ("items", "delta", "payload"):
            turn.pop(field, None)
    # Keep billed upstream retries and usage-only responses visible and counted once.
    for key, tokens in usage.items():
        if key in used_usage:
            continue
        index = len(turns)
        extra = {**turns[0], "id": digest(f"{row['capture_id']}:{index}"), "ordinal": index,
                 "title": "Upstream response / attempt", "response_id": key, "input": [], "output": [],
                 "status": "upstream", "tokens": tokens, **normalize_tokens(tokens)}
        turns.append(extra)
    return turns
