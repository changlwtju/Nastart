# Nastart Agent

This directory is reserved for the NAS Agent.

The Agent is intended to run as a Docker container on the user's own NAS or
Linux host. In v1, it primarily enhances Synology DSM coverage when DSM API is
incomplete or unstable for Docker/system discovery. It also reserves the future
compatibility path for other Docker-capable NAS platforms, but deep
non-Synology support is not a v1 requirement.

Recommended language: Go.

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
- scoped tokens
- no secrets in logs
