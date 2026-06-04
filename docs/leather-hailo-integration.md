 # Leather + Hailo local endpoint integration

This guide is intentionally separate from the primary Raspberry Pi 5 + AI HAT+ 2 onboarding guide. The primary guide gets the hardware, Hailo runtime, Hailo-Ollama, and OpenAI-compatible endpoint working. This document covers how Leather uses that endpoint.

Primary guide: [`rpi5-ai-hat-plus-2-onboarding.md`](rpi5-ai-hat-plus-2-onboarding.md)

## 1. Working architecture

```text
Leather
  -> OpenAI-compatible endpoint on localhost:8080
  -> compatibility shim
  -> Hailo-Ollama on localhost:8000
  -> Hailo-10H / AI HAT+ 2
```

Leather should not know about Hailo quirks directly. Hailo-specific compatibility belongs in the shim.

## 2. What the shim fixes

Observed Hailo-Ollama compatibility issues:

```text
raw multiline prompt parse failures
repeated system-role failures
empty model field failures
slow or runaway outputs without tight generation caps
```

The shim should:

```text
compact message text
flatten OpenAI chat messages into one user prompt
fallback to qwen3:1.7b when model is empty
bound max_tokens / num_predict
return OpenAI-style Chat Completions JSON
```

Proxy file:

```text
hailo-openai-proxy/proxy.py
```

## 3. Leather endpoint validation

Start Hailo-Ollama and the shim first, then run:

```bash
cd leather/examples/13-rpi-hailo-endpoint-canary

../../leather serve \
  --config config.yaml \
  --llm-endpoint http://localhost:8080 \
  --model qwen3:1.7b \
  --pretty \
  --stats \
  --max-jobs 1 \
  --run-duration 180s
```

Expected output shape:

```text
Subject: Leather agent
Alt subjects: Local agent; Markdown + YAML; OpenAI endpoint
Summary: Leather agent runs locally with Markdown + YAML, tracking token budgets and integrating with local endpoint workflows.
```

## 4. Example 13: RPi Hailo endpoint summarization canary

Purpose:

```text
bounded text -> strict output contract -> local semantic compression
```

This example proves that a tiny endpoint can return useful structured compression when boxed tightly.

Rules learned:

```text
use one sentence, not 3-5 sentences
use exactly 3 fields or lines
avoid code fences, markdown tables, and raw links in the prompt
sanitize hostile delimiters before sending to Hailo-Ollama
use --max-jobs 1 for predictable demos
```

Leather repo files:

```text
../leather/examples/13-rpi-hailo-endpoint-canary/README.md
../leather/examples/13-rpi-hailo-endpoint-canary/config.yaml
../leather/examples/13-rpi-hailo-endpoint-canary/Makefile
../leather/examples/13-rpi-hailo-endpoint-canary/agents/canary.agent.md
../leather/examples/13-rpi-hailo-endpoint-canary/agents/canary.lifecycle.yaml
```

## 5. README chunk fan-out

A larger README can be broken into many `schedule: once` lifecycle instances.

The key result from the session:

```text
19 once-scheduled jobs completed through qwen3:1.7b
quality depended on semantic chunk boundaries and cleanup
```

Do not use raw character chunks for final quality. Use section-aware chunks:

```text
split on ## and ### headings first
avoid splitting tables mid-row
avoid splitting code blocks mid-block
strip fences, backticks, pipes, braces, brackets, and box drawing
remove task wrappers from the text being summarized
```

The freeze used a section-aware lifecycle generator for this canary. Leather
keeps the generated once-scheduled lifecycle content in example 13.

```text
../leather/examples/13-rpi-hailo-endpoint-canary/agents/canary.lifecycle.yaml
```

## 6. Example 14: RPi Hailo local status digest

Purpose:

```text
deterministic local checks -> generated lifecycle prompt -> scheduled digest
```

This is the direct scheduled path from the lab freeze. Shell scripts collect a
local snapshot, reduce it into deterministic facts, render a lifecycle file,
and let Leather run the digest agent.

Leather repo files:

```text
../leather/examples/14-rpi-hailo-local-status-digest/README.md
../leather/examples/14-rpi-hailo-local-status-digest/config.yaml
../leather/examples/14-rpi-hailo-local-status-digest/Makefile
../leather/examples/14-rpi-hailo-local-status-digest/agents/local-status.agent.md
../leather/examples/14-rpi-hailo-local-status-digest/scripts/collect-snapshot.sh
../leather/examples/14-rpi-hailo-local-status-digest/scripts/build-facts.sh
../leather/examples/14-rpi-hailo-local-status-digest/scripts/render-lifecycle.sh
```

Run:

```bash
cd ../leather/examples/14-rpi-hailo-local-status-digest
make doctor
make run
```

Generated files are intentionally ignored:

```text
.snapshot/
agents/local-status.lifecycle.yaml
```

## 7. Example 15: RPi Hailo local status ingest

Purpose:

```text
deterministic local checks -> Leather hide -> queue -> curing worker -> artifact
```

This is the real value path. The model is not the source of truth. The shell collector creates evidence; Leather ingests and cures it; the tiny model compresses it.

Leather repo files:

```text
../leather/examples/15-rpi-hailo-local-status-ingest/README.md
../leather/examples/15-rpi-hailo-local-status-ingest/config.yaml
../leather/examples/15-rpi-hailo-local-status-ingest/tannery.yaml
../leather/examples/15-rpi-hailo-local-status-ingest/Makefile
../leather/examples/15-rpi-hailo-local-status-ingest/agents/local-status.agent.md
../leather/examples/15-rpi-hailo-local-status-ingest/curings/local-status-digest.curing.yaml
../leather/examples/15-rpi-hailo-local-status-ingest/scripts/collect-status.sh
```

Run:

```bash
cd ../leather/examples/15-rpi-hailo-local-status-ingest
make doctor
make run
```

Important Makefile detail:

```text
leather ingest must use --config config.yaml
```

Without that, ingest may write hides but not queue items in the same local state root used by `serve`.

Correct ingest shape:

```bash
../../leather ingest \
  --config config.yaml \
  --tannery tannery.yaml \
  --kind local.status \
  --source local \
  --curing local-status-digest \
  --queue default \
  sample/status.snapshot.txt
```

Success condition after ingest:

```text
.state/queues/default.jsonl exists
.state/hides/<id>/content exists
.state/hides/<id>/meta.json exists
```

Then `serve` should dequeue and cure the hide.

## 8. Output-contract guidance for tiny models

Good:

```text
Return exactly three lines.
Subject: <1-5 words>
Alt subjects: <item 1>; <item 2>; <item 3>
Summary: <one sentence, total < 60 words>
```

Bad:

```text
Summarize in 3-5 sentences.
Return a list of alternative subjects, max=3.
Analyze this README chunk.
```

The tiny model follows mechanical constraints better than abstract constraints.

## 9. Final split

Use the primary onboarding guide for:

```text
hardware
OS imaging
PCIe setup
Hailo package selection
5.1.x vs 5.3.0
Hailo-Ollama
OpenAI endpoint shim
model selection
```

Use this Leather guide for:

```text
Leather endpoint validation
scheduled summarization canary
README chunk fan-out
local status ingest / curing artifact example
Leather-specific Makefile and config pitfalls
```
