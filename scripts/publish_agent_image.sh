#!/usr/bin/env bash
set -euo pipefail

agent_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../agent" && pwd)"
image="$(sh "$agent_dir/compose.sh" --image)"
latest="${image%:*}:latest"
if [[ "$image" == "$latest" ]]; then
    echo "AGENT_VERSION must be a version tag distinct from latest." >&2
    exit 2
fi

# The publishing engine must support loading a multi-platform image locally.
docker buildx build --platform linux/amd64,linux/arm64 --load --tag "$image" "$agent_dir"
docker tag "$image" "$latest"
docker push "$image"
docker push "$latest"
