#!/bin/sh
# Transaction run on the Docker host. The SSH wrapper supplies a private staging directory.
set -eu

service=nastart-agent
active_dir=$1
source_dir=$2
token_file=$3
container_name=$4
health_timeout=$5
image_mode=$6
files="nastart_agent.py Dockerfile compose.yaml compose.sh"
lock_dir="$active_dir/.upgrade-lock"
rollback_needed=0

if ! command -v docker >/dev/null 2>&1 && [ -x /Applications/Docker.app/Contents/Resources/bin/docker ]; then
    export PATH="/Applications/Docker.app/Contents/Resources/bin:$PATH"
fi

fail() {
    printf '%s\n' "$*" >&2
    exit 1
}

mount_name() {
    docker inspect --format '{{range .Mounts}}{{if and (eq .Destination "/data") (eq .Type "volume") .RW}}{{.Name}}{{end}}{{end}}' "$1"
}

wait_healthy() {
    check_container=$1
    phase=$2
    deadline=$(($(date +%s) + health_timeout))
    last_state=
    while :; do
        state=$(docker inspect --format '{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}' "$check_container") || return 1
        if [ "$state" != "$last_state" ]; then
            printf '%s docker inspect %s: %s\n' "$phase" "$check_container" "$state"
            last_state=$state
        fi
        [ "$state" = "running healthy" ] && return 0
        if [ "$(date +%s)" -ge "$deadline" ]; then
            printf '%s did not become healthy within %ss.\n' "$phase" "$health_timeout" >&2
            return 1
        fi
        sleep 1
    done
}

verify_endpoints() {
    check_container=$1
    expected=$2
    phase=$3
    docker exec -i "$check_container" python3 -c '
import http.client
import json
import os
import ssl
import sys

version, phase = sys.argv[1:]
token = sys.stdin.read().strip()
if not token or not all(c.isascii() and (c.isalnum() or c in "-_") for c in token):
    sys.exit("Expected an existing Agent bearer token on stdin.")
port = int(os.environ.get("NASTART_PORT", "8787"))

def request(path, headers, use_tls):
    # Both transports stay on loopback inside the selected container.
    if use_tls:
        connection = http.client.HTTPSConnection("127.0.0.1", port, timeout=3,
                                                 context=ssl._create_unverified_context())
    else:
        connection = http.client.HTTPConnection("127.0.0.1", port, timeout=3)
    try:
        connection.request("GET", path, headers=headers)
        response = connection.getresponse()
        return response.status, response.read(65536)
    finally:
        connection.close()

use_tls = True
for path, key in [("/healthz", "version"), ("/v1/handshake", "agentVersion")]:
    headers = {"Authorization": f"Bearer {token}"} if path == "/v1/handshake" else {}
    try:
        try:
            status, payload = request(path, headers, use_tls)
        except (OSError, http.client.HTTPException):
            if path != "/healthz":
                raise
            use_tls = False
            status, payload = request(path, headers, use_tls)
        if status != 200:
            sys.exit(f"{phase} GET {path} HTTP {status}")
        data = json.loads(payload)
        fields = ("ok", "version") if path == "/healthz" else ("agentVersion", "apiVersion", "permissionLevel", "agentId")
        print(f"{phase} GET {path} HTTP 200 " + json.dumps({k: data.get(k) for k in fields}, sort_keys=True), flush=True)
        if data.get(key) != version or (path == "/healthz" and data.get("ok") is not True):
            sys.exit(f"{phase} GET {path} did not report expected version {version}")
    except (OSError, ValueError, http.client.HTTPException):
        sys.exit(f"{phase} GET {path} failed")
' "$expected" "$phase" < "$token_file"
}

compose_active() {
    active_namespace=$1
    active_version=$2
    shift 2
    NASTART_DOCKERHUB_NAMESPACE="$active_namespace" NASTART_AGENT_VERSION="$active_version" \
        docker compose -p "$project" -f "$active_dir/compose.yaml" "$@"
}

compose_staged() {
    sh "$source_dir/compose.sh" -p "$project" "$@"
}

validate_config() {
    # Resolve the planned Docker volume before any container is stopped.
    printf '%s' "$1" | docker exec -i "$old_container" python3 -c '
import json
import sys

config = json.load(sys.stdin)
volume, container, image = sys.argv[1:]
service = config["services"]["nastart-agent"]
mounts = [m for m in service.get("volumes", []) if m["target"] == "/data"]
if service.get("container_name") != container or service.get("image") != image:
    sys.exit("Unexpected Compose container name or image.")
if len(mounts) != 1:
    sys.exit("Expected exactly one /data mount.")
mount = mounts[0]
if mount["type"] != "volume" or mount["source"] != "nastart-agent-data" or mount.get("read_only", False):
    sys.exit("Expected the writable nastart-agent-data volume at /data.")
if config["volumes"]["nastart-agent-data"]["name"] != volume:
    sys.exit("Compose volume does not match the existing container volume.")
' "$old_volume" "$container_name" "$2"
}

verify_running() {
    check_container=$1
    expected_version=$2
    image_id=$3
    phase=$4
    [ "$(mount_name "$check_container")" = "$old_volume" ] || return 1
    [ "$(docker inspect --format '{{.Image}}' "$check_container")" = "$image_id" ] || return 1
    wait_healthy "$check_container" "$phase" && verify_endpoints "$check_container" "$expected_version" "$phase"
}

rollback() {
    printf 'Rolling back to %s.\n' "$old_image" >&2
    for file in $files; do cp -p "$lock_dir/$file" "$active_dir/$file" || return 1; done
    compose_active "$old_namespace" "$old_version" stop -t 5 "$service" || return 1
    [ "$(docker image inspect --format '{{.Id}}' "$old_image")" = "$old_image_id" ] || return 1
    compose_active "$old_namespace" "$old_version" up -d --no-build --pull never --force-recreate "$service" || return 1
    verify_running "$container_name" "$old_version" "$old_image_id" rollback
}

finish() {
    result=$?
    trap - 0
    trap '' HUP INT TERM
    if [ "$rollback_needed" -eq 1 ]; then
        if rollback; then
            printf 'Upgrade failed. Rolled back to %s with the existing token verified.\n' "$old_image" >&2
            result=1
        else
            printf 'Upgrade and rollback failed. Recovery files are in %s.\n' "$lock_dir" >&2
            exit 2
        fi
    fi
    for file in $files; do rm -f "$lock_dir/$file"; done
    rmdir "$lock_dir"
    exit "$result"
}

for file in $files; do
    [ -f "$active_dir/$file" ] && [ -f "$source_dir/$file" ] || fail "Missing Agent deployment file: $file"
done
[ -s "$token_file" ] || fail "An existing Agent token file is required."
(umask 077; mkdir "$lock_dir") || fail "An upgrade lock already exists at $lock_dir."
trap finish 0
trap 'exit 1' HUP INT TERM

old_container=$(docker inspect --format '{{.Id}}' "$container_name")
old_image=$(docker inspect --format '{{.Config.Image}}' "$old_container")
old_image_id=$(docker inspect --format '{{.Image}}' "$old_container")
case "$old_image" in
    nastart-agent:*) old_namespace= ;;
    */nastart-agent:*) old_namespace=${old_image%/nastart-agent:*} ;;
    *) fail "Expected a versioned Nastart Agent image." ;;
esac
old_version=${old_image##*:}
[ "$(docker image inspect --format '{{.Id}}' "$old_image")" = "$old_image_id" ] || fail "The old image tag no longer identifies the running image."
project=$(docker inspect --format '{{index .Config.Labels "com.docker.compose.project"}}' "$old_container")
compose_service=$(docker inspect --format '{{index .Config.Labels "com.docker.compose.service"}}' "$old_container")
[ -n "$project" ] && [ "$compose_service" = "$service" ] || fail "Expected an existing Compose deployment."
old_volume=$(mount_name "$old_container")
[ -n "$old_volume" ] || fail "Expected an existing writable named volume at /data."
docker volume inspect "$old_volume" >/dev/null
environment=$(docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$old_container")
NASTART_PAIRING_CODE=$(printf '%s\n' "$environment" | sed -n 's/^NASTART_PAIRING_CODE=//p')
NASTART_PROVIDER_HINT=$(printf '%s\n' "$environment" | sed -n 's/^NASTART_PROVIDER_HINT=//p')
unset environment
case "$NASTART_PAIRING_CODE" in
    [0-9][0-9][0-9][0-9][0-9][0-9]) ;;
    *) fail "The existing Compose container has no valid pairing configuration." ;;
esac
export NASTART_PAIRING_CODE NASTART_PROVIDER_HINT

new_image=$(sh "$source_dir/compose.sh" --image)
new_version=${new_image##*:}
[ "$new_image" != "$old_image" ] || fail "The candidate uses the running image tag $old_image. A distinct tag is required for rollback."
validate_config "$(compose_active "$old_namespace" "$old_version" config --format json)" "$old_image"
validate_config "$(compose_staged config --format json)" "$new_image"
[ "$(compose_active "$old_namespace" "$old_version" ps -q "$service")" = "$old_container" ] || fail "The active Compose project does not own the selected container."
verify_running "$old_container" "$old_version" "$old_image_id" baseline || fail "The existing Agent did not pass preflight."
for file in $files; do cp -p "$active_dir/$file" "$lock_dir/$file"; done

case "$image_mode" in
    pull) compose_staged pull --policy always "$service" ;;
    build) compose_staged build "$service" ;;
    *) fail "Expected pull or build mode." ;;
esac
new_image_id=$(docker image inspect --format '{{.Id}}' "$new_image")
[ "$(docker image inspect --format '{{.Id}}' "$old_image")" = "$old_image_id" ] || fail "Preparing the candidate changed the rollback image tag."
[ "$(docker inspect --format '{{.Id}}' "$container_name")" = "$old_container" ] || fail "The active container changed while preparing the candidate."
rollback_needed=1
for file in $files; do cp -p "$source_dir/$file" "$active_dir/$file"; done
docker stop -t 10 "$old_container"
compose_active "$NASTART_DOCKERHUB_NAMESPACE" "$new_version" up -d --no-build --pull never --force-recreate "$service"
verify_running "$container_name" "$new_version" "$new_image_id" upgrade || fail "The upgraded Agent did not pass verification."
rollback_needed=0
printf 'Upgraded to %s with the existing token verified.\n' "$new_image"
