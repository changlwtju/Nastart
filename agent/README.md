# Nastart Agent

This directory is reserved for the NAS Agent.

The Agent is intended to run as a Docker container on the user's own NAS or
Linux host. In v1, it primarily enhances Synology DSM coverage when DSM API is
incomplete or unstable for Docker/system discovery. It also reserves the future
compatibility path for other Docker-capable NAS platforms, but deep
non-Synology support is not a v1 requirement.

The first executable implementation is dependency-free Python so it can run on
DSM/Linux hosts and be validated without installing a toolchain. A hardened
Docker image and Compose definition are included.

Initial responsibilities:

- Pair with Nastart app
- Discover Docker containers
- Read NAS/system status
- Detect service endpoints
- Check certificate and domain lifecycle
- Expose a narrow local HTTPS API

Security defaults:

- read-only first
- minimal permissions
- explicit pairing
- scoped tokens stored as one-way SHA-256 digests
- one-time pairing codes with per-client attempt throttling
- no secrets in logs

## Run directly

```sh
NASTART_PAIRING_CODE=123456 python3 nastart_agent.py --data-dir ./data
```

Health check: `GET /healthz`. Pair once with `POST /v1/pair`, then use the
returned Bearer token for `GET /v1/handshake`, `GET /v1/snapshot`, and
`GET /v1/diagnostics`.

A consumed pairing code stays disabled across restarts. Deploying with a new
six-digit code explicitly rotates pairing; failed attempts are limited to five
per client address per minute.

## Role in Nastart

On Synology, Agent enhances a DSM connection rather than replacing it. DSM login
is still the primary path for DSM identity, File Station, package APIs,
session-backed media URLs, and Synology-specific settings. Agent contributes
read-only local observations that DSM may not expose consistently, especially
Docker containers, ports, host metrics, and service discovery.

Agent-only support is reserved for Docker-capable non-Synology hosts and should
be treated as an experimental compatibility path until the app has a dedicated
provider flow for it.

## Run with Docker Compose

```sh
NASTART_PAIRING_CODE=123456 docker compose up -d --build
```

The container is read-only, drops Linux capabilities, uses
`no-new-privileges`, and mounts the Docker socket read-only. The Agent API does
not expose container mutation or arbitrary command execution.

## Smoke Test

From the repository root on a Mac or NAS shell on the same LAN:

```sh
python3 scripts/agent_smoke_test.py --base-url http://NAS_HOST:8787 --pairing-code 123456
```

The smoke test checks `/healthz`, pairs when a code is supplied, validates the
authenticated handshake, and reads a snapshot summary.
