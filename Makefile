# Raspberry Pi 5 AI HAT+ 2 onboarding helpers.

ROOT := $(CURDIR)
PROXY_DIR := $(ROOT)/hailo-openai-proxy
SYSTEMD_USER_DIR ?= $(HOME)/.config/systemd/user
LEATHER_REPO ?= $(shell if test -d ../leather/examples; then cd ../leather && pwd; elif test -d ../examples; then cd .. && pwd; else printf '%s\n' ../leather; fi)

HAILO_BASE ?= http://127.0.0.1:8000
HAILO_PROXY ?= http://127.0.0.1:8080
HAILO_MODEL ?= qwen3:1.7b
HAILO_PROXY_HOST ?= 127.0.0.1
HAILO_PROXY_PORT ?= 8080

.PHONY: help doctor validate validate-tools validate-packages validate-systemd connectors \
	python proxy-run systemd-install systemd-enable systemd-disable systemd-status systemd-logs \
	leather-validate leather-canary leather-digest leather-ingest leather-status clean

help:
	@echo "rpi5-ai-hat2-onboarding"
	@echo ""
	@echo "Validation:"
	@echo "  doctor             run local tool, package, unit, and connector checks"
	@echo "  validate           alias for doctor"
	@echo "  validate-tools     check required commands"
	@echo "  validate-packages  print Hailo/RPi package versions and device identity"
	@echo "  validate-systemd   verify user systemd unit syntax"
	@echo "  connectors         check Hailo-Ollama and proxy HTTP endpoints"
	@echo ""
	@echo "Proxy:"
	@echo "  python             install shim deps with uv, or venv + pip fallback"
	@echo "  proxy-run          run the OpenAI compatibility proxy in the foreground"
	@echo ""
	@echo "systemd user units:"
	@echo "  systemd-install    copy units into ~/.config/systemd/user and reload"
	@echo "  systemd-enable     enable and start Hailo-Ollama + proxy"
	@echo "  systemd-disable    disable and stop both units"
	@echo "  systemd-status     show user service status"
	@echo "  systemd-logs       follow both service logs"
	@echo ""
	@echo "Leather handoff:"
	@echo "  leather-validate   validate Leather examples 13, 14, and 15"
	@echo "  leather-canary     run Leather example 13 against this proxy"
	@echo "  leather-digest     run Leather example 14 against this proxy"
	@echo "  leather-ingest     run Leather example 15 against this proxy"
	@echo ""
	@echo "HAILO_BASE=$(HAILO_BASE)"
	@echo "HAILO_PROXY=$(HAILO_PROXY)"
	@echo "HAILO_MODEL=$(HAILO_MODEL)"
	@echo "LEATHER_REPO=$(LEATHER_REPO)"

doctor: validate-tools validate-packages validate-systemd connectors
validate: doctor

validate-tools:
	@missing=0; \
	for cmd in python3 curl systemctl; do \
	  if command -v "$$cmd" >/dev/null 2>&1; then echo "ok: $$cmd"; else echo "missing: $$cmd"; missing=1; fi; \
	done; \
	for cmd in hailortcli hailo-ollama; do \
	  if command -v "$$cmd" >/dev/null 2>&1; then echo "ok: $$cmd"; else echo "watch: $$cmd not found in PATH"; fi; \
	done; \
	exit $$missing

validate-packages:
	@bash scripts/validate-current-package-versions.sh

validate-systemd:
	@systemd-analyze verify --user systemd/hailo-ollama-serve.service systemd/hailo-openai-proxy.service

connectors:
	@echo "Hailo-Ollama: $(HAILO_BASE)"
	@curl -fsS "$(HAILO_BASE)/api/tags" >/dev/null && echo "ok: /api/tags" || echo "action: Hailo-Ollama /api/tags not reachable"
	@echo "OpenAI proxy: $(HAILO_PROXY)"
	@curl -fsS "$(HAILO_PROXY)/health" >/dev/null && echo "ok: /health" || echo "action: proxy /health not reachable"
	@curl -fsS "$(HAILO_PROXY)/v1/models" >/dev/null && echo "ok: /v1/models" || echo "action: proxy /v1/models not reachable"

python:
	@if command -v uv >/dev/null 2>&1; then \
	  uv sync; \
	else \
	  python3 -m venv .venv; \
	  . .venv/bin/activate; \
	  python -m pip install --upgrade pip; \
	  python -m pip install -r requirements.txt; \
	fi

proxy-run: python
	@cd "$(PROXY_DIR)" && \
	  HAILO_BASE="$(HAILO_BASE)" \
	  HAILO_DEFAULT_MODEL="$(HAILO_MODEL)" \
	  HAILO_FLATTEN_MESSAGES=1 \
	  HAILO_MAX_GENERATION_TOKENS=256 \
	  PATH="$(ROOT)/.venv/bin:$$PATH" \
	  uvicorn proxy:app --host "$(HAILO_PROXY_HOST)" --port "$(HAILO_PROXY_PORT)"

systemd-install:
	@install -d -m 0755 "$(SYSTEMD_USER_DIR)"
	@install -m 0644 systemd/hailo-ollama-serve.service "$(SYSTEMD_USER_DIR)/hailo-ollama-serve.service"
	@install -m 0644 systemd/hailo-openai-proxy.service "$(SYSTEMD_USER_DIR)/hailo-openai-proxy.service"
	@systemctl --user daemon-reload
	@echo "installed user units into $(SYSTEMD_USER_DIR)"

systemd-enable: systemd-install
	@systemctl --user enable --now hailo-ollama-serve.service
	@systemctl --user enable --now hailo-openai-proxy.service

systemd-disable:
	@systemctl --user disable --now hailo-openai-proxy.service hailo-ollama-serve.service

systemd-status:
	@systemctl --user --no-pager status hailo-ollama-serve.service hailo-openai-proxy.service

systemd-logs:
	@journalctl --user -u hailo-ollama-serve.service -u hailo-openai-proxy.service -f

leather-validate:
	@$(MAKE) -C "$(LEATHER_REPO)/examples" validate-13 validate-14 validate-15

leather-canary:
	@$(MAKE) -C "$(LEATHER_REPO)/examples" LEATHER_RPI_LLM_ENDPOINT="$(HAILO_PROXY)" LEATHER_RPI_MODEL="$(HAILO_MODEL)" 13

leather-digest:
	@$(MAKE) -C "$(LEATHER_REPO)/examples" LEATHER_RPI_LLM_ENDPOINT="$(HAILO_PROXY)" LEATHER_RPI_MODEL="$(HAILO_MODEL)" 14

leather-ingest:
	@$(MAKE) -C "$(LEATHER_REPO)/examples" LEATHER_RPI_LLM_ENDPOINT="$(HAILO_PROXY)" LEATHER_RPI_MODEL="$(HAILO_MODEL)" 15

leather-status: leather-ingest

clean:
	@rm -rf .venv
