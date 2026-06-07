# Raspberry Pi 5 + AI HAT+ 2 onboarding

This repo owns the Raspberry Pi 5 + AI HAT+ 2 side of the local Leather/Hailo
stack: hardware setup, Hailo package validation, Hailo-Ollama, the
OpenAI-compatible proxy, and user systemd units.

Leather itself owns the runnable agent examples:

```text
../leather/examples/rpi-01-hailo-endpoint-canary/
../leather/examples/rpi-02-hailo-local-status-digest/
../leather/examples/rpi-03-hailo-local-status-ingest/
```

Upstream index: <https://github.com/TGPSKI/leather/tree/main/examples#rpihailo-examples>

## Repo contents

```text
docs/                         hardware, package, and Leather handoff guides
hailo-openai-proxy/           FastAPI OpenAI-compatible shim for Hailo-Ollama
scripts/                      validation helpers
systemd/                      user units for Hailo-Ollama and proxy
Makefile                      install, validate, run, and Leather handoff targets
pyproject.toml                uv-compatible Python dependency frame
requirements.txt              pip fallback dependencies
```

## Quick Start

Validate the Pi/Hailo state:

```bash
make doctor
```

Install Python dependencies for the proxy:

```bash
make python
```

Run the proxy in the foreground:

```bash
make proxy-run
```

Install and start user systemd units:

```bash
make systemd-install
make systemd-enable
make systemd-status
```

Validate the Leather examples from the adjacent Leather checkout:

```bash
make leather-validate
make leather-canary
make leather-digest
make leather-ingest
```

Override defaults when the Leather checkout or endpoint lives elsewhere:

```bash
LEATHER_REPO=~/github/tgpski/leather \
HAILO_PROXY=http://rpi-host:8080 \
HAILO_MODEL=qwen3:1.7b \
make leather-canary
```

## Guides

- [`docs/rpi5-ai-hat-plus-2-onboarding.md`](docs/rpi5-ai-hat-plus-2-onboarding.md)
  covers hardware, OS, Hailo runtime packages, Hailo-Ollama, and endpoint setup.
- [`docs/leather-hailo-integration.md`](docs/leather-hailo-integration.md)
  covers the handoff from this repo into Leather RPi/Hailo examples.
- [`docs/lab-freeze-findings.md`](docs/lab-freeze-findings.md)
  summarizes the latest working RPi lab freeze without committing raw logs.

## Repo Controls

- License: [`GPL-3.0`](LICENSE)
- Security policy: [`SECURITY.md`](SECURITY.md)
- Contribution guide: [`CONTRIBUTING.md`](CONTRIBUTING.md)
- Issue template: [`.github/ISSUE_TEMPLATE/agent-work-item.md`](.github/ISSUE_TEMPLATE/agent-work-item.md)
- CI and release workflows: [`.github/workflows/`](.github/workflows/)
