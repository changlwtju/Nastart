#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 --host HOST --user USER [--port 22] --pairing-code 6_DIGITS"
}

host=""
user=""
port="22"
pairing_code=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) host="${2:-}"; shift 2 ;;
    --user) user="${2:-}"; shift 2 ;;
    --port) port="${2:-}"; shift 2 ;;
    --pairing-code) pairing_code="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage; exit 2 ;;
  esac
done

if [[ ! "$host" =~ ^[A-Za-z0-9._:-]+$ ]] || [[ ! "$user" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "Invalid SSH host or user." >&2
  exit 2
fi
if [[ ! "$port" =~ ^[0-9]{1,5}$ ]] || (( port < 1 || port > 65535 )); then
  echo "Invalid SSH port." >&2
  exit 2
fi
if [[ ! "$pairing_code" =~ ^[0-9]{6}$ ]]; then
  echo "Pairing code must contain exactly six digits." >&2
  exit 2
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "$script_dir/.." && pwd)"
agent_dir="$project_dir/agent"
target="$user@$host"
ssh_options=(-p "$port" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)

ssh "${ssh_options[@]}" "$target" "install -d -m 700 \"\$HOME/.nastart-agent\""
tar -C "$agent_dir" -cf - nastart_agent.py Dockerfile compose.yaml | \
  ssh "${ssh_options[@]}" "$target" "tar -xf - -C \"\$HOME/.nastart-agent\""

remote_command=$(cat <<REMOTE
set -eu
agent_dir="\$HOME/.nastart-agent"
install -d -m 700 "\$agent_dir/data"
cd "\$agent_dir"
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  NASTART_PAIRING_CODE=$pairing_code docker compose -f compose.yaml up -d --build
elif command -v python3 >/dev/null 2>&1; then
  if [ -f agent.pid ] && kill -0 "\$(cat agent.pid)" 2>/dev/null; then kill "\$(cat agent.pid)"; fi
  nohup env NASTART_PAIRING_CODE=$pairing_code python3 ./nastart_agent.py --host 0.0.0.0 --port 8787 --data-dir ./data >./agent.log 2>&1 </dev/null &
  echo \$! > agent.pid
else
  echo 'Docker Compose or Python 3 is required.' >&2
  exit 69
fi
echo NASTART_AGENT_READY
REMOTE
)
ssh "${ssh_options[@]}" "$target" "$remote_command"

echo "Nastart Agent deployed. Pair it in the app with code $pairing_code at http://$host:8787."
