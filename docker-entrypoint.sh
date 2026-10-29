#!/usr/bin/env bash
set -euo pipefail

seed_pi() {
  if [[ ! -d /opt/pi-seed/.pi ]]; then
    return 0
  fi
  mkdir -p /home/orca/.pi
  if [[ ! -e /home/orca/.pi/agent ]]; then
    cp -a /opt/pi-seed/.pi/. /home/orca/.pi/
    return 0
  fi
  if ! pi list >/dev/null 2>&1 || ! pi list 2>/dev/null | grep -qi 'pi-profile'; then
    pi install git:https://github.com/SquidCorp/pi-profile || true
  fi
}

# Persist OpenRouter into Pi's auth.json (takes priority over env).
# Equivalent to interactive `/login openrouter` with an API key.
write_openrouter_auth() {
  if [[ -z "${OPENROUTER_API_KEY:-}" ]]; then
    return 0
  fi
  mkdir -p /home/orca/.pi/agent
  node <<'NODE'
const fs = require("fs");
const path = require("path");
const file = path.join(process.env.HOME, ".pi/agent/auth.json");
fs.mkdirSync(path.dirname(file), { recursive: true });
let auth = {};
try {
  auth = JSON.parse(fs.readFileSync(file, "utf8"));
} catch {
  auth = {};
}
if (!auth || typeof auth !== "object" || Array.isArray(auth)) auth = {};
auth.openrouter = { type: "api_key", key: process.env.OPENROUTER_API_KEY };
fs.writeFileSync(file, JSON.stringify(auth, null, 2) + "\n", { mode: 0o600 });
NODE
}

seed_pi
write_openrouter_auth

if [[ "${1:-}" != "serve" && "${1:-}" != "" ]]; then
  exec "$@"
fi

shift || true

PORT="${ORCA_PORT:-6768}"
PAIRING_ADDRESS="${ORCA_PAIRING_ADDRESS:-127.0.0.1}"
# shellcheck disable=SC2206
EXTRA_ARGS=(${ORCA_SERVE_ARGS:-})

if [[ -z "${DISPLAY:-}" ]]; then
  export DISPLAY=:99
  Xvfb :99 -screen 0 1280x720x24 -nolisten tcp >/tmp/xvfb.log 2>&1 &
fi

exec /opt/orca/AppRun --no-sandbox serve --port "$PORT" --pairing-address "$PAIRING_ADDRESS" "${EXTRA_ARGS[@]}" "$@"
