# Raspberry Pi 5 + AI HAT+ 2 onboarding guide

This guide covers the primary Raspberry Pi 5 + AI HAT+ 2 setup path: hardware assembly, OS imaging, Hailo package selection, Hailo-Ollama, and a local OpenAI-compatible endpoint. It intentionally keeps Leather-specific workflow content in a separate guide: [`docs/leather-hailo-integration.md`](leather-hailo-integration.md).

## 1. System architecture

```text
Raspberry Pi 5
  -> PCIe ribbon cable
  -> AI HAT+ 2 / Hailo-10H
  -> Hailo-10H runtime packages
  -> Hailo-Ollama on localhost:8000
  -> OpenAI-compatible shim on localhost:8080
  -> local clients and agent runtimes
```

The AI HAT+ 2 is different from the earlier AI Kit / AI HAT+ path. It uses the Hailo-10H package family, not the older Hailo-8/Hailo-8L package family.

## 2. Hardware checklist

Use this baseline:

```text
Raspberry Pi 5
official 27W USB-C power supply
Raspberry Pi Active Cooler
AI HAT+ 2
AI HAT+ 2 heatsink
microSD card or NVMe/USB SSD
short PCIe ribbon cable included with the HAT
Phillips screwdriver
```

Raspberry Pi documents that the AI HAT+ and AI HAT+ 2 connect to the Pi 5 PCIe port and provides the official mounting sequence. The AI software docs also call out the AI Kit / AI HAT+ vs AI HAT+ 2 package split.

References:

- Raspberry Pi AI HAT+ docs: https://www.raspberrypi.com/documentation/accessories/ai-hat-plus.html
- Raspberry Pi AI software docs: https://www.raspberrypi.com/documentation/computers/ai.html

## 3. PCIe cable and physical assembly

Power the Pi off before touching the PCIe cable.

Checklist:

```text
Pi unpowered
spacers installed
GPIO stacking header seated
PCIe cable inserted evenly
AI HAT+ 2 mounted on spacers
AI HAT+ 2 heatsink installed
Pi Active Cooler installed
```

Use the official cable orientation instructions from Raspberry Pi. If the card is not detected later, reseat both ends of the cable before chasing software issues.

Quick detection checks after boot:

```bash
ls -l /dev/hailo* 2>/dev/null || true
lspci 2>/dev/null | grep -i hailo || true
dmesg | grep -i hailo | tail -50
```

## 4. Image the OS

Use Raspberry Pi Imager.

Recommended baseline:

```text
Raspberry Pi OS 64-bit
Trixie
SSH enabled
user created
Wi-Fi configured if needed
hostname set, for example hailo-pi or leather-pi
```

After first boot:

```bash
sudo apt update
sudo apt full-upgrade -y
sudo rpi-eeprom-update -a
sudo reboot
```

Enable PCIe Gen 3:

```bash
sudo raspi-config
```

Then:

```text
Advanced Options
  -> PCIe Speed
  -> Yes
  -> Finish
  -> reboot
```

Or edit `/boot/firmware/config.txt`:

```bash
sudoedit /boot/firmware/config.txt
```

Add:

```text
dtparam=pciex1_gen=3
```

Then:

```bash
sudo reboot
```

## 5. Package choice: `hailo-all` vs `hailo-h10-all` vs 5.3.0 manual path

There are three package paths. Choose one and do not mix them.

**Older AI Kit / AI HAT+ (Hailo-8/8L):**

```bash
sudo apt install dkms hailo-all
```

**AI HAT+ 2 / Hailo-10H, apt 5.1.x path:**

```bash
sudo apt install dkms hailo-h10-all
```

`hailo-h10-all` is a metapackage that pulls in the Hailo-10H driver and runtime stack. It is valid for getting started but is pinned to the 5.1.x release in the standard Raspberry Pi OS repos and does not include the latest models.

**AI HAT+ 2 / Hailo-10H, manual 5.3.0 path (required for latest models):**

`hailo-h10-all` is not available for 5.3.0 and is not required. The 5.3.0 manual path installs `hailort`, `hailort-pcie-driver`, and `hailo-gen-ai-model-zoo` directly from `.deb` files. See section 6 for the full procedure.

Verify whichever path you used:

```bash
hailortcli fw-control identify
dmesg | grep -i hailo | tail -50
```

Expected shape:

```text
Executing on device: 0000:01:00.0
Device Architecture: HAILO10H
/dev/hailo0 exists
```

## 6. apt 5.1.x path vs 5.3.0 manual path

Treat these as two different tracks. The 5.3.0 manual path is required to run the latest models (qwen3, deepseek-r1, qwen2.5-coder, llama3.2).

### Track A: apt 5.1.x path

Quick to install, but limited to older models available in the apt repos.

```bash
sudo apt update
sudo apt install dkms hailo-h10-all
sudo reboot
hailortcli fw-control identify
```

### Track B: 5.3.0 manual path

Use this for `hailort 5.3.0` with the full current model zoo. This is the recommended path for running Hailo-Ollama with current models.

`hailo-h10-all` is not part of this path and should not be installed alongside it.

A 2026 Hailo community report described a `hailo-gen-ai-model-zoo_5.3.0_arm64.deb` dependency issue on Raspberry Pi 5 with Hailo-10H when mixing 5.1.x apt packages with a partial 5.3.0 set. The practical rule is: start from a clean state.

References:

- Hailo community 5.3.0 Hailo-10H dependency issue: https://community.hailo.ai/t/bug-report-hailo-gen-ai-model-zoo-5-3-0-uninstallable-on-raspberry-pi-with-hailo-10h/19226
- Raspberry Pi forum discussion on 5.3 support: https://forums.raspberrypi.com/viewtopic.php?t=397487

Clean-start inspection:

```bash
dpkg -l | grep -Ei 'hailo|h10|tappas|rpi-camera-assets|hailort'
```

If you have apt 5.1.x packages installed, remove them before proceeding:

```bash
sudo apt remove --purge 'hailo*' 'h10-*' 'python3-h10-*' 'python3-hailo*'
sudo apt autoremove --purge
sudo reboot
```

Download the complete matching Hailo-10H / arm64 5.3.0 package set from Hailo Developer Zone. Do not install only one `.deb` and assume the stack is coherent.

Install from a local directory:

```bash
mkdir -p ~/Downloads/hailo-5.3
cd ~/Downloads/hailo-5.3

# copy/download the full matched 5.3.0 package set here
sudo apt install ./*.deb
sudo reboot
```

Verify:

```bash
dpkg -l | grep -Ei 'hailo|h10|tappas'
hailortcli fw-control identify
ldconfig -p | grep hailort
```

If apt proposes removing `h10-hailort` and installing generic `hailort`, stop.

## 7. Hailo apps vs GenAI / Ollama

There are two different setup successes:

```text
vision demos working
local LLM / Hailo-Ollama working
```

Vision demos usually depend on the camera stack, TAPPAS, model zoo assets, and post-processing configuration. The local LLM path depends on the Hailo GenAI / Hailo-Ollama pieces.

The Hailo GenAI Model Zoo project describes Hailo-Ollama as an Ollama-compatible API built on HailoRT.

Reference:

- Hailo GenAI Model Zoo: https://github.com/hailo-ai/hailo_model_zoo_genai

## 8. Stand up Hailo-Ollama

Discover what was installed:

```bash
command -v hailo-ollama || true
systemctl list-unit-files | grep -i hailo || true
dpkg -L hailo-gen-ai-model-zoo 2>/dev/null | grep -E 'ollama|bin' || true
```

Manual run shape:

```bash
hailo-ollama
```

Expected server:

```text
Hailo-Ollama listening on localhost:8000 or 0.0.0.0:8000
```

Validate:

```bash
curl -s http://127.0.0.1:8000/api/tags | jq
curl -s http://127.0.0.1:8000/hailo/v1/list | jq
```

## 9. Add an OpenAI-compatible shim

Most agent frameworks expect OpenAI Chat Completions. Hailo-Ollama is Ollama-like and may not behave exactly like OpenAI chat.

The compatibility shim in this repo is here:

```text
hailo-openai-proxy/proxy.py
```

Start it:

```bash
cd hailo-openai-proxy
python3 -m venv .venv
source .venv/bin/activate
pip install fastapi uvicorn requests

export HAILO_BASE=http://127.0.0.1:8000
export HAILO_DEFAULT_MODEL=qwen3:1.7b
export HAILO_FLATTEN_MESSAGES=1

uvicorn proxy:app --host 127.0.0.1 --port 8080
```

Validate:

```bash
curl -s http://127.0.0.1:8080/health | jq
curl -s http://127.0.0.1:8080/v1/models | jq
```

OpenAI-style chat test:

```bash
curl -s http://127.0.0.1:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "qwen3:1.7b",
    "messages": [
      {"role": "system", "content": "You are concise. No markdown."},
      {"role": "user", "content": "Say one sentence about local agents."}
    ],
    "temperature": 0,
    "max_tokens": 64
  }' | jq
```

## 10. 1.7B vs 1.5B and tools

Use this split:

```text
qwen3:1.7b through Hailo-Ollama:
  better for generic local endpoint testing
  useful for bounded summarization, classification, and digesting
  external runtime should own tools

1.5B function-calling HEF path:
  better for native Hailo tool demos
  useful for curated tool-call examples
  less convenient as a generic OpenAI-compatible endpoint
```

The strongest local pattern is not “tiny model controls everything.” It is:

```text
deterministic scripts collect facts
runtime queues/schedules/persists work
tiny model summarizes or classifies bounded evidence
```

## 11. Known failure modes

### Raw newline parse failures

Symptom:

```text
invalid string: control character U+000A must be escaped
```

Fix:

```text
compact message content before forwarding to Hailo-Ollama
```

### Repeated system-role failures

Symptom:

```text
System role messages can only be provided on the first prompt
```

Fix:

```text
flatten OpenAI system/user/assistant messages into one user message
```

### Empty model failures

Symptom:

```text
model '' not found
```

Fix in the proxy:

```python
model = str(body.get("model") or "").strip() or DEFAULT_MODEL
```

### Slow or no output

Fix:

```text
short output contracts
max_tokens / num_predict around 64-256 for first tests
single sentence, small JSON, or 3-line output
larger run-duration for demos
```

## 12. Recommended onboarding sequence

The sequence below uses the 5.3.0 manual path, which is required for the latest models. For the apt 5.1.x path, replace the package installation step with `sudo apt install dkms hailo-h10-all`.

```bash
# OS and firmware
sudo apt update
sudo apt full-upgrade -y
sudo rpi-eeprom-update -a
sudo reboot

# 5.3.0 manual path: install full matched .deb set from Hailo Developer Zone
# (hailo-h10-all is not used on this path)
mkdir -p ~/Downloads/hailo-5.3
cd ~/Downloads/hailo-5.3
# copy .deb files here, then:
sudo apt install ./*.deb
sudo reboot

# Verify device
hailortcli fw-control identify
dmesg | grep -i hailo | tail -50

# Start Hailo-Ollama
hailo-ollama

# Validate Hailo-Ollama
curl -s http://127.0.0.1:8000/api/tags | jq

# Start OpenAI shim
cd hailo-openai-proxy
source .venv/bin/activate
uvicorn proxy:app --host 127.0.0.1 --port 8080

# Validate shim
curl -s http://127.0.0.1:8080/health | jq
curl -s http://127.0.0.1:8080/v1/models | jq
```
