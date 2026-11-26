# Nastart Agent

This directory is reserved for the NAS Agent.

The Agent is intended to run as a Docker container on the user's own NAS or
Linux host. In v1, it primarily enhances Synology DSM coverage when DSM API is
incomplete or unstable for Docker/system discovery. It also reserves the future
compatibility path for other Docker-capable NAS platforms, but deep
non-Synology support is not a v1 requirement.

The Agent uses the Python standard library and the OpenSSL command-line tool
for TLS. The Docker image includes OpenSSL, and no Python packages need to be
installed.

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
- bearer tokens and private keys stay out of logs. The Agent logs an unused
  one-time pairing code at startup so the host administrator can pair.

## Run directly

```sh
NASTART_PAIRING_CODE=123456 python3 nastart_agent.py --data-dir ./data
```

Health check: `GET /healthz`. Pair once with `POST /v1/pair`, then use the
returned Bearer token for `GET /v1/handshake`, `GET /v1/snapshot`, and
`GET /v1/diagnostics`.

Diagnostics includes the current `checks`, `uptimeSeconds` (seconds since Agent
startup), `eventCount` (retained events), and `events` (up to 100 entries, newest
first). Each event has a Unix timestamp in seconds. The history records
`container.state`, `docker.availability`, and `pairing.failed` events. A rejected
pairing code contributes only the client address and timestamp. The history
persists in `events.json` in the Agent data directory.

The first Docker sample establishes a baseline. Set
`NASTART_SAMPLE_INTERVAL_SECONDS` in the Agent process environment (under the
Agent service's `environment` in Compose) to change the sampling interval. The
default is 30 seconds. Values below 10 use 10 seconds, and invalid values use
the default.

A consumed pairing code stays disabled across restarts. Deploying with a new
six-digit code explicitly rotates pairing; failed attempts are limited to five
per client address per minute.

## TLS

Agent 0.4.0 serves HTTPS by default. On first startup it uses OpenSSL to create a
self-signed RSA-2048 certificate valid for 3,650 days. Its common name is the
Agent hostname, with subject alternative names for the hostname, `localhost`,
and `127.0.0.1`. The data directory holds `tls-cert.pem` (0644) and
`tls-key.pem` (0600). The Agent checks the certificate on each startup and
replaces an automatically managed certificate when it has 30 days or less
remaining. Keep the data volume across container recreation to retain the
certificate.

Supply both `--tls-cert /path/to/cert.pem` and `--tls-key /path/to/key.pem`
(or `NASTART_TLS_CERT` and `NASTART_TLS_KEY`) to use your own certificate.
For Compose, mount the files into the Agent container and configure the paths
inside that container. The Agent leaves renewal of an explicitly supplied
certificate to its owner. If OpenSSL is unavailable or automatic setup fails,
the Agent logs a warning to stderr and serves plain HTTP.

`/v1/handshake` returns `certificate.fingerprintSha256` (lowercase DER SHA-256
hex), `notAfter` (Unix seconds), and `subject` (common name). On HTTP the
`certificate` field is null. The `certificate` diagnostics check reports
`ok`, `expiring`, `expired`, or `unavailable`, with the remaining days or a
reason.

After upgrading an existing `http://` App connection, pair once with
`https://` and enable **Skip SSL Verification** for the self-signed certificate.
The App pins the fingerprint on first connection and logs a pin rotation when
the certificate changes. Start the Agent with a fresh six-digit pairing code
if the previous code was consumed.

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
export NASTART_DOCKERHUB_NAMESPACE=YOUR_DOCKER_HUB_NAMESPACE
export NASTART_PAIRING_CODE=123456
sh ./compose.sh pull --policy always nastart-agent &&
    sh ./compose.sh up -d --no-build --pull never --wait
```

Run these commands from the `agent` directory. The Docker Hub namespace is
required. `compose.sh` reads `AGENT_VERSION` from `nastart_agent.py` and
supplies the version for `<namespace>/nastart-agent:<version>`. The command
`sh ./compose.sh --image` prints that reference.

Compose uses `pull_policy: missing` for ordinary startup. The commands above
explicitly fetch the versioned tag and start from the fetched image. For a
local development build, run `sh ./compose.sh build nastart-agent` in place of the pull and
use the same startup command.

Both containers use read-only root filesystems, drop Linux capabilities,
and use `no-new-privileges`. The root-run proxy alone mounts the host Docker
socket. The unprivileged Agent uses a read-only shared volume for its
filtered socket. The proxy accepts only `GET /v1.41/containers/json?all=1`
and has no published port. Compose checks the Agent's `/healthz` over
container loopback every five seconds.

From the repository root, run the isolated Docker healthcheck verification on a
local Docker engine:

```sh
python3 scripts/verify_agent_docker.py
```

Add `--pull` with `NASTART_DOCKERHUB_NAMESPACE` set to verify the published
image with a disposable project and fresh data volume.

## Install on Synology with Package Center

From the repository root, build the SPK with Bash and Python 3:

```sh
scripts/build_spk.sh /path/to/nastart-agent-0.4.0-0008.spk
```

The SPK contains deployment files, metadata and icons. Installation downloads
`changlwtju/nastart-agent:0.4.0` from Docker Hub. The build derives the image
tag and package feature version from `AGENT_VERSION`. DSM requires a numeric
package build suffix. Set `SPK_BUILD_NUMBER` to the next four-digit build number
when preparing a newer SPK. [Synology INFO version fields](https://help.synology.com/developer-guide/synology_package/INFO_necessary_fields.html)

| Host | Requirement and coverage |
| --- | --- |
| DS918+ (apollolake, x86_64) | DSM 7.4.1-90080 Update 1 with Container Manager 24.0.2-1706 meets the package requirements. |
| Other x86_64 and armv8 models | DSM 7.2.1 or later and Container Manager 20.10.23-1437 or later. The image is published for amd64 and arm64. |

Container Manager must be able to reach Docker Hub, and TCP 8787 must be free.
The Docker Project Worker manages the Compose project. The lifecycle scripts
run as the DSM package account and prepare its project configuration. The
Agent and its proxy run under that account's numeric identity. Only the proxy
mounts the Docker socket and receives the socket's existing group inside its
container. [Synology Docker Project Worker](https://help.synology.com/developer-guide/resource_acquisition/docker-project.html)

If an older Compose or SSH installation already owns the port, stop it
separately. A fresh SPK uses DSM's persistent package directory at
`/var/packages/nastart-agent/var/container-data`.
[Synology Container Manager release notes](https://www.synology.com/en-global/releaseNote/ContainerManager)

1. Open **Package Center → Manual Install**, select the SPK, and review and
   confirm DSM's third-party installation warning. The package uses DSM's
   package user model because DSM 7 rejects unsigned packages requesting root.
   The Agent runs as an unprivileged container user, and the filtered proxy
   alone mounts the Docker socket. [Synology root package restrictions](https://help.synology.com/developer-guide/getting_started/system_requirement.html)
2. Open **Container Manager → Container**, select the container for the
   `nastart-agent-spk` project's `agent` service, then open **Details → Log**.
   Find `One-time pairing code:` in the startup output. The Agent also keeps a
   mode-0600 copy in the persistent package directory as `spk-pairing-code`.
   [Synology container details and logs](https://kb.synology.com/en-me/DSM/help/ContainerManager/docker_container?version=7)
3. In Nastart, pair using `https://<NAS LAN address>:8787` and enable **Skip SSL
   Verification** for the self-signed certificate. After the code is used,
   restart and reinstall preserve the existing pairing. Already-used codes in
   old logs cannot be used again.

Use Package Center to start and stop the stack. To upgrade, manually upload a
newer SPK for the same package. Upgrade stops the old stack and starts the new
image using the same external `nastart-agent-spk-data` volume. Pairing state,
tokens, certificates and event history stay in that volume. An existing App
connection should continue with its original token and certificate.

Uninstall from Package Center to remove both containers, their network and the
proxy socket volume. The Agent data volume and shared cached image remain.
To permanently clear the saved pairing, tokens, certificate and event history,
uninstall first, then run this on the NAS with administrator Docker access:

```sh
sudo docker volume rm nastart-agent-spk-data
```

The disposable lifecycle test requires Docker Desktop and Python 3.12+ on
the Mac. From the repository root, pass the built package or omit the path to
build a temporary one:

```sh
scripts/test_spk_lifecycle.sh /path/to/nastart-agent-0.4.0-0001.spk
```

## Install on a Linux Docker host with systemd

On a Linux host booted with systemd, start Docker Engine (`docker.service`) and
install Docker Compose v2 with `--wait-timeout`. With TCP 8787 available, run
from the repository root:

```sh
sudo scripts/install_agent_systemd.sh
sudo systemctl status nastart-agent.service
sudo docker logs nastart-agent
```

The installer pulls the versioned image and copies the existing
`agent/compose.yaml` into `/opt/nastart-agent` with a root-only `.env`. The
systemd unit starts the stack after Docker and checks readiness. The Agent logs
the first-use pairing code. Pair with `https://<Linux LAN address>:8787`.
To install a newer version, rerun the installer from the newer checkout.
The `.env` pairing code and both Compose volumes survive this update.

To remove the service while keeping its configuration and data:

```sh
sudo systemctl disable --now nastart-agent.service
sudo rm /etc/systemd/system/nastart-agent.service
sudo systemctl daemon-reload
```

## Publish to Docker Hub

Sign in to Docker Hub on the publishing Mac and run this from the repository
root with Docker Buildx and the containerd image store enabled.

```sh
NASTART_DOCKERHUB_NAMESPACE=YOUR_DOCKER_HUB_NAMESPACE scripts/publish_agent_image.sh
```

The script builds `linux/amd64` and `linux/arm64` in one image and pushes the
versioned tag followed by `latest`. Deployment uses the versioned tag.

## Install over SSH

```sh
NASTART_DOCKERHUB_NAMESPACE=YOUR_DOCKER_HUB_NAMESPACE \
  scripts/install_agent_via_ssh.sh --host NAS_HOST --user NAS_USER --pairing-code 123456
```

The default mode (`--pull`) requires Docker Compose on the target and waits
for the downloaded image to become healthy. The SSH `--build` upload still
uses the earlier four-file bundle, which lacks the proxy source required by
the Dockerfile. Use the repository Compose commands above for a local image
build. An existing Compose installation uses the upgrade script.

## Upgrade a Compose installation

From the repository root, use a checkout that resolves to a different
versioned image reference than the running container. Legacy local image
references such as `nastart-agent:<version>` can be migrated to a namespaced
image. Give the script a private file containing the existing Agent Bearer
token from the original pairing.

```sh
NASTART_DOCKERHUB_NAMESPACE=YOUR_DOCKER_HUB_NAMESPACE \
  bash scripts/upgrade_agent_via_ssh.sh --host NAS_HOST --user NAS_USER \
    --token-file /path/to/private/agent-token
```

The remote account needs Docker Compose access and the installed files in
`~/.nastart-agent`. The default mode (`--pull`) fetches the candidate from
Docker Hub while the existing container runs. The same four-file upload
limit applies to SSH upgrades with `--build`. The script carries forward
the pairing configuration and the named data volume. It verifies health
and both HTTP endpoints with the existing token before reporting success.
`--timeout` sets the health wait in seconds and defaults to 60.

On a failed switch or endpoint check, the script restores the previous
deployment files, starts the previously verified local image with pulling
disabled, and confirms health,
version and token access. Exit status 1 after the rollback message indicates
that the old version is running. If rollback fails, exit status 2 identifies
the recovery files in `~/.nastart-agent/.upgrade-lock`.

On a Mac with Docker Desktop running, exercise success and automatic rollback
using temporary release copies, a loopback SSH server and an isolated Compose
project:

```sh
export PATH="/Applications/Docker.app/Contents/Resources/bin:$PATH"
python3 -u scripts/verify_agent_upgrade.py
```

## Smoke Test

From the repository root, use the Agent's certificate as a trust anchor and
connect using a name from its subject alternative names. For example, on the
Agent host with the default published port:

```sh
SSL_CERT_FILE=/path/to/tls-cert.pem \
  python3 scripts/agent_smoke_test.py --base-url https://localhost:8787 --pairing-code 123456
```

The smoke test checks `/healthz`, pairs when a code is supplied, validates the
authenticated handshake, and reads a snapshot summary.
