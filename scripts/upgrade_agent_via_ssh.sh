#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: NASTART_DOCKERHUB_NAMESPACE=NAME $0 --host HOST --user USER --token-file FILE [--port 22] [--timeout 60] [--container nastart-agent] [--pull|--build]"
}

host=
user=
port=22
token_file=
health_timeout=60
container_name=nastart-agent
image_mode=pull
while (( $# )); do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        --pull|--build) image_mode=${1#--}; shift ;;
        --host|--user|--token-file|--port|--timeout|--container)
            (( $# >= 2 )) || { usage >&2; exit 2; }
            case "$1" in
                --host) host=$2 ;;
                --user) user=$2 ;;
                --token-file) token_file=$2 ;;
                --port) port=$2 ;;
                --timeout) health_timeout=$2 ;;
                --container) container_name=$2 ;;
            esac
            shift 2
            ;;
        *) usage >&2; exit 2 ;;
    esac
done
if [[ ! "$host" =~ ^[a-zA-Z0-9][a-zA-Z0-9.:-]*$ || ! "$user" =~ ^[a-zA-Z0-9_][a-zA-Z0-9._-]*$ ||
      ! "$port" =~ ^[1-9][0-9]{0,4}$ || "$port" -gt 65535 ||
      ! "$container_name" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ||
      ! "$health_timeout" =~ ^[1-9][0-9]{0,3}$ || ! -f "$token_file" || ! -s "$token_file" ]]; then
    usage >&2
    exit 2
fi

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
sh "$script_dir/../agent/compose.sh" --image >/dev/null
target="$user@$host"
ssh_options=(-T -p "$port" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)
stage=$(ssh "${ssh_options[@]}" "$target" 'umask 077; mktemp -d .nastart-agent-upgrade.XXXXXXXX')
if [[ ! "$stage" =~ ^\.nastart-agent-upgrade\.[a-zA-Z0-9]{8}$ ]]; then
    echo "SSH returned an invalid staging directory." >&2
    exit 1
fi

cleanup_stage() {
    local result=$?
    if ! ssh "${ssh_options[@]}" "$target" "rm -rf './$stage'"; then
        echo "Could not remove the private staging directory $stage on $target." >&2
        if (( result == 0 )); then result=1; fi
    fi
    exit "$result"
}
trap cleanup_stage EXIT

COPYFILE_DISABLE=1 tar -C "$script_dir/../agent" -cf - nastart_agent.py Dockerfile compose.yaml compose.sh |
    ssh "${ssh_options[@]}" "$target" "umask 077; mkdir './$stage/source' && tar -xf - -C './$stage/source'"
ssh "${ssh_options[@]}" "$target" "umask 077; cat > './$stage/token'" < "$token_file"
ssh "${ssh_options[@]}" "$target" \
    "NASTART_DOCKERHUB_NAMESPACE='$NASTART_DOCKERHUB_NAMESPACE' sh -s -- \"\$HOME/.nastart-agent\" './$stage/source' './$stage/token' '$container_name' '$health_timeout' '$image_mode'" \
    < "$script_dir/upgrade_agent_on_host.sh"
