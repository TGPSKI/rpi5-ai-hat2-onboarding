# RPi Lab Freeze Findings

Source: `../leather/rpi-lab-freeze/src/leather-rpi-lab-freeze/`

The freeze is the latest working source of truth from the Raspberry Pi before
the Leather release pivot.

Validated in the freeze:

- Hailo-Ollama served on `127.0.0.1:8000`.
- The OpenAI compatibility proxy served on `127.0.0.1:8080`.
- Leather example 13 ran once-scheduled tiny endpoint summarization.
- README fanout produced 19 once-scheduled summarization jobs through
  `qwen3:1.7b`.
- Direct local status digest worked by collecting shell facts, rendering a
  lifecycle prompt, and running a scheduled Leather agent.
- Tannery local status ingest reached hide, queue, dequeue, and DLQ validation;
  artifact proofing remained the next step.

Compatibility fixes retained in `hailo-openai-proxy/proxy.py`:

- Compact multiline message text before forwarding to Hailo-Ollama.
- Flatten repeated OpenAI chat messages into a single Hailo user prompt.
- Fall back to `qwen3:1.7b` when clients send an empty model.
- Bound generation length with `HAILO_MAX_GENERATION_TOKENS`.

Not committed from the freeze:

- `.venv/`
- `__pycache__/`
- `.snapshot/`
- `.state/`
- generated lifecycle files
- sample status snapshots
- debug logs
- raw HailoRT logs
