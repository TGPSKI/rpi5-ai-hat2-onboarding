# Contributing

Thanks for helping improve the Raspberry Pi 5 + AI HAT+ 2 onboarding path.

## Scope

This repo owns:

- Raspberry Pi 5 + AI HAT+ 2 setup notes
- Hailo-10H package validation
- Hailo-Ollama and OpenAI proxy operation
- user systemd units
- handoff into Leather RPi/Hailo examples

Leather runtime code and Leather examples live in the adjacent Leather repo.

## Local Checks

Run the non-hardware checks before opening a PR:

```bash
python3 -m py_compile hailo-openai-proxy/proxy.py
python3 -c 'import tomllib; tomllib.load(open("pyproject.toml", "rb"))'
bash -n scripts/validate-current-package-versions.sh
systemd-analyze verify systemd/hailo-ollama-serve.service systemd/hailo-openai-proxy.service
make -n python proxy-run systemd-install leather-validate leather-canary leather-digest leather-ingest
```

On a Raspberry Pi with the HAT installed, also run:

```bash
make doctor
make connectors
```

## Generated Files

Do not commit:

- `.venv/`
- `__pycache__/`
- `.snapshot/`
- `.state/`
- generated lifecycle files
- sample status snapshots
- debug logs
- raw HailoRT logs

## Pull Requests

Keep PRs small and concrete. Update docs when changing setup behavior, Makefile
targets, systemd units, or the proxy contract.
