#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: NASTART_DOCKERHUB_NAMESPACE=NAME $0 --host HOST --user USER [--port 22] --pairing-code 6_DIGITS [--pull|--build]"
}

host=""
user=""
port="22"
pairing_code=""
image_mode=pull

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host|--user|--port|--pairing-code)
      (( $# >= 2 )) || { usage >&2; exit 2; }
      case "$1" in
        --host) host=$2 ;;
        --user) user=$2 ;;
        --port) port=$2 ;;
        --pairing-code) pairing_code=$2 ;;
      esac
      shift 2
      ;;
    --pull|--build) image_mode=${1#--}; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage; exit 2 ;;
  esac
done

if [[ ! "$host" =~ ^[a-zA-Z0-9][a-zA-Z0-9.:-]*$ || ! "$user" =~ ^[a-zA-Z0-9_][a-zA-Z0-9._-]*$ ]]; then
  echo "Invalid SSH host or user." >&2
  exit 2
fi
if [[ ! "$port" =~ ^[1-9][0-9]{0,4}$ ]] || (( port > 65535 )); then
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
ssh_options=(-T -p "$port" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)
sh "$agent_dir/compose.sh" --image >/dev/null

remote_command=$(cat <<REMOTE
set -eu
umask 077
export NASTART_DOCKERHUB_NAMESPACE='$NASTART_DOCKERHUB_NAMESPACE'
export NASTART_PAIRING_CODE='$pairing_code'
image_mode='$image_mode'
agent_dir="\$HOME/.nastart-agent"
install -d -m 700 "\$agent_dir"
cd "\$agent_dir"
mkdir .upgrade-lock || { echo 'Another Agent deployment is in progress.' >&2; exit 1; }
trap 'rmdir .upgrade-lock' 0
trap 'exit 1' HUP INT TERM
if ! command -v docker >/dev/null 2>&1 && [ -x /Applications/Docker.app/Contents/Resources/bin/docker ]; then
  export PATH="/Applications/Docker.app/Contents/Resources/bin:\$PATH"
fi
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  docker info --format '{{.ServerVersion}}' >/dev/null
  if docker container inspect nastart-agent >/dev/null 2>&1; then
    echo 'A Nastart Agent container already exists. Use the upgrade script for an existing installation.' >&2
    exit 1
  fi
  tar -xf -
  if [ "\$image_mode" = pull ]; then
    sh ./compose.sh pull --policy always nastart-agent
  else
    sh ./compose.sh build nastart-agent
  fi
  sh ./compose.sh up -d --no-build --pull never --wait --wait-timeout 60 nastart-agent
elif [ "\$image_mode" = build ] && command -v python3 >/dev/null 2>&1; then
  tar -xf -
  install -d -m 700 data
  if [ -f agent.pid ] && kill -0 "\$(cat agent.pid)" 2>/dev/null; then kill "\$(cat agent.pid)"; fi
  nohup python3 ./nastart_agent.py --host 0.0.0.0 --port 8787 --data-dir ./data >./agent.log 2>&1 </dev/null &
  echo \$! > agent.pid
else
  echo 'Docker Compose is required for Docker Hub deployment. Use --build for the Python fallback on a host without Compose.' >&2
  exit 69
fi
echo NASTART_AGENT_READY
REMOTE
)
COPYFILE_DISABLE=1 tar -C "$agent_dir" -cf - nastart_agent.py Dockerfile compose.yaml compose.sh |
  ssh "${ssh_options[@]}" "$target" "$remote_command"

echo "Nastart Agent deployed. Pair it in the app at https://$host:8787 using your pairing code."
