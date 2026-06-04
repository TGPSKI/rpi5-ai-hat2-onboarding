# Security Policy

## Supported Versions

| Version | Supported |
|---|---|
| 0.1.x | yes |

## Reporting a Vulnerability

If you discover a potential security vulnerability, please open a GitHub issue
with enough detail to reproduce the problem. Avoid posting real API keys,
private hostnames, or logs that contain secrets.

## Trust Model

This repo is an operator guide and local compatibility shim for a single-user
Raspberry Pi / Hailo lab setup.

- The OpenAI compatibility proxy is intended for loopback or trusted LAN use.
  Bind to `127.0.0.1` unless you intentionally expose it through an
  authenticating reverse proxy.
- The proxy forwards prompts to Hailo-Ollama and does not provide tenant
  isolation, request authentication, or rate limiting.
- Systemd units run as the invoking user. Do not run them as root unless the
  hardware stack explicitly requires it.
- Hailo-Ollama, model files, generated snapshots, and Leather artifacts may
  contain sensitive local operational details. Keep generated files out of git.
- The proxy normalizes prompt text for Hailo compatibility but does not sanitize
  prompts for safety or policy. Treat model input and output as untrusted text.
