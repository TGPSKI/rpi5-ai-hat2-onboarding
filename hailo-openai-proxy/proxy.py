import os
import time
import uuid
from typing import Any

import requests
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

HAILO_BASE = os.environ.get("HAILO_BASE", "http://127.0.0.1:8000").rstrip("/")
DEFAULT_MODEL = os.environ.get("HAILO_DEFAULT_MODEL", "qwen3:1.7b")
FLATTEN_MESSAGES = os.environ.get("HAILO_FLATTEN_MESSAGES", "1") != "0"
MAX_GENERATION_TOKENS = int(os.environ.get("HAILO_MAX_GENERATION_TOKENS", "256"))

app = FastAPI()


def compact_text(value: Any) -> str:
    if value is None:
        return ""
    if not isinstance(value, str):
        value = str(value)
    return " ".join(value.split())


def normalize_messages(messages: Any) -> list[dict[str, str]]:
    if not isinstance(messages, list):
        messages = []

    cleaned: list[dict[str, str]] = []
    for msg in messages:
        if not isinstance(msg, dict):
            continue
        role = str(msg.get("role") or "user").strip() or "user"
        if role not in {"system", "user", "assistant", "tool"}:
            role = "user"

        content = compact_text(msg.get("content", ""))
        if content:
            cleaned.append({"role": role, "content": content})

    if not cleaned:
        cleaned = [{"role": "user", "content": ""}]

    if FLATTEN_MESSAGES:
        flat = " ".join(f"{m['role'].upper()}: {m['content']}" for m in cleaned)
        return [{"role": "user", "content": compact_text(flat)}]

    return cleaned


@app.get("/health")
def health():
    return {
        "ok": True,
        "hailo_base": HAILO_BASE,
        "default_model": DEFAULT_MODEL,
        "flatten_messages": FLATTEN_MESSAGES,
        "max_generation_tokens": MAX_GENERATION_TOKENS,
    }


@app.get("/v1/models")
def models():
    try:
        r = requests.get(f"{HAILO_BASE}/api/tags", timeout=30)
        r.raise_for_status()
        data = r.json()
        names = [m.get("name") for m in data.get("models", []) if isinstance(m, dict) and m.get("name")]
    except Exception:
        try:
            r = requests.get(f"{HAILO_BASE}/hailo/v1/list", timeout=30)
            r.raise_for_status()
            names = r.json().get("models", [])
        except Exception as exc:
            return JSONResponse(status_code=502, content={"error": {"message": str(exc), "type": "hailo_models_error"}})

    return {
        "object": "list",
        "data": [{"id": name, "object": "model", "created": 0, "owned_by": "hailo"} for name in names],
    }


@app.post("/v1/chat/completions")
async def chat_completions(request: Request):
    body = await request.json()

    model = str(body.get("model") or "").strip() or DEFAULT_MODEL
    messages = normalize_messages(body.get("messages", []))

    temperature = body.get("temperature", 0)
    max_tokens = body.get("max_tokens", body.get("max_completion_tokens", 256))
    try:
        max_tokens = int(max_tokens)
    except Exception:
        max_tokens = 256
    max_tokens = max(1, min(max_tokens, MAX_GENERATION_TOKENS))

    hailo_payload = {
        "model": model,
        "stream": False,
        "messages": messages,
        "options": {"temperature": temperature, "num_predict": max_tokens},
    }

    try:
        r = requests.post(f"{HAILO_BASE}/api/chat", json=hailo_payload, timeout=300)
    except requests.RequestException as exc:
        return JSONResponse(status_code=502, content={"error": {"message": str(exc), "type": "hailo_ollama_request_error"}})

    if r.status_code >= 400:
        return JSONResponse(
            status_code=r.status_code,
            content={"error": {"message": r.text, "type": "hailo_ollama_error", "code": r.status_code}},
        )

    try:
        data = r.json()
    except Exception:
        return JSONResponse(status_code=502, content={"error": {"message": r.text, "type": "hailo_ollama_bad_json"}})

    content = data.get("message", {}).get("content", "")
    completion_tokens = data.get("eval_count", 0)

    return {
        "id": f"chatcmpl-{uuid.uuid4().hex}",
        "object": "chat.completion",
        "created": int(time.time()),
        "model": model,
        "choices": [{"index": 0, "message": {"role": "assistant", "content": content}, "finish_reason": data.get("done_reason", "stop")}],
        "usage": {"prompt_tokens": 0, "completion_tokens": completion_tokens, "total_tokens": completion_tokens},
    }
