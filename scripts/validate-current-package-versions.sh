#!/usr/bin/env bash
set -u

status=0

echo "== commands =="
for cmd in hailortcli hailo-ollama dpkg-query lspci; do
  if command -v "$cmd" >/dev/null 2>&1; then
    printf 'ok: %s -> %s\n' "$cmd" "$(command -v "$cmd")"
  else
    printf 'watch: %s not found\n' "$cmd"
    [ "$cmd" = "hailortcli" ] && status=1
  fi
done

echo
echo "== hailo device =="
if [ -e /dev/hailo0 ]; then
  echo "ok: /dev/hailo0 exists"
else
  echo "action: /dev/hailo0 missing"
  status=1
fi

if command -v hailortcli >/dev/null 2>&1; then
  hailortcli fw-control identify || status=1
fi

if command -v lspci >/dev/null 2>&1; then
  lspci 2>/dev/null | grep -i hailo || echo "watch: lspci did not show Hailo"
fi

echo
echo "== installed packages =="
if command -v dpkg-query >/dev/null 2>&1; then
  dpkg-query -W -f='${binary:Package}\t${Version}\n' 2>/dev/null \
    'hailo*' 'h10-*' 'python3-h10-*' 'python3-hailo*' 'rpi-*' \
    | sort || true

  if dpkg-query -W hailo-h10-all >/dev/null 2>&1; then
    echo "ok: hailo-h10-all installed"
  else
    echo "action: hailo-h10-all not installed"
    status=1
  fi
else
  echo "watch: dpkg-query unavailable"
fi

echo
echo "== endpoint defaults =="
echo "Hailo-Ollama: http://127.0.0.1:8000"
echo "OpenAI proxy: http://127.0.0.1:8080"

exit "$status"
