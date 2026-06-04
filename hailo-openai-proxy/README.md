# Hailo OpenAI compatibility proxy

FastAPI shim for Hailo-Ollama.

It exposes:

```text
GET  /health
GET  /v1/models
POST /v1/chat/completions
```

Why this exists:

```text
Hailo-Ollama is Ollama-like, not fully OpenAI-chat-compatible.
Some clients resend system messages every request.
Some prompts contain raw newlines or markdown structures that Hailo prompt rendering rejects.
Some integration paths send an empty model field.
```

The proxy normalizes those cases.

## Run

From the repo root:

```bash
make python
make proxy-run
```

Or manually:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r ../requirements.txt

export HAILO_BASE=http://127.0.0.1:8000
export HAILO_DEFAULT_MODEL=qwen3:1.7b
export HAILO_FLATTEN_MESSAGES=1
export HAILO_MAX_GENERATION_TOKENS=256

uvicorn proxy:app --host 127.0.0.1 --port 8080
# uvicorn proxy:app --host 0.0.0.0 --port 8080
```
