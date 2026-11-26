#!/bin/sh
set -eu

agent_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
: "${NASTART_DOCKERHUB_NAMESPACE:?set NASTART_DOCKERHUB_NAMESPACE}"
case "$NASTART_DOCKERHUB_NAMESPACE" in
    *[!abcdefghijklmnopqrstuvwxyz0123456789_-]*|[-_]*|*[-_])
        echo "Invalid Docker Hub namespace." >&2
        exit 2
        ;;
esac

version=$(LC_ALL=C sed -n 's/^AGENT_VERSION[[:space:]]*=[[:space:]]*"\([[:alnum:]_][[:alnum:]_.-]*\)"[[:space:]]*$/\1/p' \
    "$agent_dir/nastart_agent.py")
case "$version" in
    ''|*[!a-zA-Z0-9_.-]*)
        echo "Expected one Docker-compatible AGENT_VERSION in nastart_agent.py." >&2
        exit 1
        ;;
esac

if [ "${1:-}" = "--image" ]; then
    printf '%s/nastart-agent:%s\n' "$NASTART_DOCKERHUB_NAMESPACE" "$version"
    exit 0
fi

export NASTART_AGENT_VERSION="$version"
exec docker compose -f "$agent_dir/compose.yaml" "$@"
