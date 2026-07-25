# Nastart Agent

This directory is reserved for the future NAS Agent.

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

