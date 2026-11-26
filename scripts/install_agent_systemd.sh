#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
stack=/opt/nastart-agent
docker=/usr/bin/docker
service=nastart-agent.service
namespace=changlwtju

if [ "$(id -u)" -ne 0 ] || [ ! -d /run/systemd/system ]; then
    echo "Run with sudo on a Linux host booted with systemd." >&2
    exit 1
fi
"$docker" compose version >/dev/null
if ! "$docker" compose up --help | grep -q -- '--wait-timeout'; then
    echo "Docker Compose v2 with --wait-timeout is required." >&2
    exit 1
fi
"$docker" info --format '{{.ServerVersion}}' >/dev/null

if project=$("$docker" inspect --type container --format '{{index .Config.Labels "com.docker.compose.project"}}' nastart-agent 2>/dev/null); then
    if [ "$project" != nastart-agent-linux ]; then
        echo "A container named nastart-agent is already managed outside this systemd installation." >&2
        exit 1
    fi
fi

image=$(NASTART_DOCKERHUB_NAMESPACE=$namespace sh "$root/agent/compose.sh" --image)
"$docker" pull "$image"
umask 077
install -d -m 0700 "$stack"
if [ -f "$stack/.env" ]; then
    pairing_code=$(sed -n 's/^NASTART_PAIRING_CODE=//p' "$stack/.env")
else
    # Restrict to a multiple of one million to avoid modulo bias.
    while :; do
        number=$(od -An -N4 -tu4 /dev/urandom | tr -d '[:space:]')
        [ "$number" -lt 4294000000 ] && break
    done
    pairing_code=$(printf '%06d' "$((number % 1000000))")
fi
case "$pairing_code" in
    [0-9][0-9][0-9][0-9][0-9][0-9]) ;;
    *) echo "Invalid pairing code in $stack/.env." >&2; exit 1 ;;
esac

pending=$(mktemp "$stack/.env.XXXXXX")
trap 'rm -f "$pending"' EXIT
printf 'NASTART_DOCKERHUB_NAMESPACE=%s\nNASTART_AGENT_VERSION=%s\nNASTART_PAIRING_CODE=%s\n' \
    "$namespace" "${image##*:}" "$pairing_code" > "$pending"
install -m 0644 "$root/agent/compose.yaml" "$stack/compose.yaml"
mv -f "$pending" "$stack/.env"
install -m 0644 "$root/systemd/$service" "/etc/systemd/system/$service"
systemctl daemon-reload
systemctl restart "$service"
systemctl enable "$service"
printf 'Nastart Agent started. Read the first-use code with: sudo docker logs nastart-agent\n'
