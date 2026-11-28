# Nastart Agent

This directory is reserved for the NAS Agent.

The Agent is intended to run as a Docker container on the user's own NAS or
Linux host. In v1, it primarily enhances Synology DSM coverage when DSM API is
incomplete or unstable for Docker/system discovery. It also reserves the future
compatibility path for other Docker-capable NAS platforms, but deep
non-Synology support is not a v1 requirement.

The Agent uses the Python standard library, the OpenSSL command-line tool
for TLS and a bundled [QR encoder](qrencoder-LICENSE.txt). The Docker image
includes these components. No Python packages need to be installed for the
HTTPS server. The optional discovery image bundles `zeroconf` and `ifaddr`.

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

## Install from the website

On the NAS or Linux host, open an SSH terminal and run:

```sh
curl -fsSL --proto '=https' --proto-redir '=https' https://nastart.lagransun.cn/install.sh -o install-agent.sh && sh install-agent.sh
```

The download is generated from this repository when the Agent's versioned
image is available and the website is deployed. The installer uses the same
`AGENT_VERSION` for the Docker image, the bundled native Python release and
the HTTPS health check. The Synology wizard downloads the package from
`https://nastart.lagransun.cn/nastart-agent.spk`.

- With a reachable local Docker daemon, the installer uses the published
  `changlwtju/nastart-agent` image. It publishes HTTPS on TCP 8787, runs the
  Docker inventory proxy in a separate container, and preserves Agent state in
  `nastart-agent-bootstrap-data`. Agent and proxy use `unless-stopped` when
  the Docker daemon starts. The host's Docker service must start at boot.
- On Linux with systemd and no Docker CLI, the script installs the bundled
  source, enables `nastart-agent-native.service`, and preserves state under
  `/var/lib/nastart-agent`. This path requires an administrator account,
  Python 3.10+, OpenSSL, `flock`, `tar`, `base64` and `curl`. Docker inventory
  is unavailable on a host without Docker.
- DSM can use its supported Container Manager and the SPK. The standalone
  installer checks for the SPK project first when Docker is available. On a
  DSM host without Container Manager, it reports the SPK prerequisite.

Repeat the same version to reuse the existing deployment. If an installed
instance uses another version, or if the port belongs to another service,
the installer reports the conflict. Upgrade with the original deployment
method and keep its data directory or volume. Docker access is checked against
a local Unix socket. On TrueNAS, the supported SSH workflow targets the
Linux-based SCALE edition with Docker. Changes to the base OS of an appliance
may be lost on vendor upgrades.

After `HTTPS` self-check succeeds, run the printed `show-config` command with
your NAS LAN address to view the code or QR. The HTTPS check is local and sends
no credentials. For mDNS, see [Advertise the Agent on the LAN](#advertise-the-agent-on-the-lan).

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

Each Agent startup issues a new six-digit code. Use [the Web page or CLI](#view-the-current-pairing-code)
to pair one more device. Startup still logs `One-time pairing code:`. A restart invalidates
the previous code even if it went unused. The CLI option and
`NASTART_PAIRING_CODE` can choose the first code for a fresh data directory.
Existing Compose and systemd configurations can keep that setting as-is.
Failed attempts are limited to five per client address per minute.

Pairing another device adds a Bearer token alongside the existing tokens.
The private (0600) `pairing-tokens.json` file is a JSON array. Each entry has
`id` (unique UUID), `sha256` (lowercase hex digest of the Bearer token), and
`createdAt` (Unix seconds, or `null` for a migrated token whose creation time
is unknown). No device name is needed. To revoke one token, stop the Agent,
remove its object by `id` from the array, preserve the file's owner and mode,
and start the Agent. Use `[]` to revoke all and keep the file in place.
The legacy `pairing-token` file is retained for rollback to 0.4.0 and is
imported only if the new file does not exist. If you revoke the migrated
token, a rollback to 0.4.0 using that legacy file still recognizes it.

Keep `pairing-code-history.json` in the data directory across upgrades and
restarts. It records the digest of every code issued since 0.5.0, as well as
the legacy last-used digest and any legacy SPK install code. Versions before
0.5.0 that overwrote a digest leave no record of those earlier codes. If all
one million possible codes have been issued, the Agent continues serving
paired devices and stops issuing codes. Run one Agent per data directory.

## View the current pairing code

Use an Agent image built from source that includes `show-config`. Both views
read the same running Agent. After a successful pairing they show that no code
is active. Restart the Agent to issue another code. The page refreshes every
10 seconds while open. Reload it if the restart interrupts the connection.

### Web page

On the same LAN, open `https://NAS_LAN_HOST:8787/pairing-info`. In the browser
prompt use the username `nastart`. Retrieve the display password once on the
Agent host and keep it private. It persists in the Agent data directory as
`pairing-view-key` (0600) across restarts and is separate from the six-digit
code and the API tokens.

```sh
docker exec nastart-agent python3 /app/nastart_agent.py show-config --web-key
```

The page requires HTTPS and a browser-trusted certificate matching the address.
With the default self-signed certificate, use the CLI below or configure a
trusted certificate for the NAS hostname. The route accepts local source
addresses only. Keep the page off public reverse proxies, which can make
requests appear local to the Agent. Use the deployment's LAN address when
opening the page so the QR contains the reachable address.

### Terminal

```sh
docker exec nastart-agent python3 /app/nastart_agent.py show-config \
  --address https://NAS_LAN_HOST:8787
```

Replace `NAS_LAN_HOST` with the reachable NAS hostname or IP. Without
`--address`, the command shows the local address used by the CLI, which is
typically container loopback. The command prints the address, live code and an
ASCII QR, and verifies the Agent's certificate against the locally stored
certificate before fetching the code. Pairing display requires the running
Agent's HTTPS listener. For a direct Python installation, run
`python3 nastart_agent.py show-config` with the same `--data-dir`, `--host`,
`--port` and custom `--tls-cert` as the running Agent, where applicable.

The QR encodes UTF-8 JSON with `v` (format version `1`), `address` (HTTPS
origin) and `code` (a six-character string that retains leading zeros). A
generic QR reader can display the JSON. On Nastart builds with QR import,
choose **Scan Agent pairing QR code** on the pairing page. Check the filled
address before tapping **Pair Agent**. Manual entry remains available.

```json
{"v":1,"address":"https://nas.local:8787","code":"012345"}
```

## Advertise the Agent on the LAN

The `advertise` command publishes `_nastart-agent._tcp.local.` using the
configured LAN IPv4 address and HTTPS port. Its service instance shows the
host label, and the TXT record contains only `host` and `version`. The
publisher probes the Agent's existing HTTPS `/healthz` without credentials.
It announces a healthy Agent and withdraws the record if the probe fails.
The iOS pairing page resolves the record to its LAN IPv4 and port, then waits
for you to enter a code. The existing certificate setting still applies.

### Docker Compose, DSM SPK and Linux systemd

Keep the Agent and its proxy running with their existing ports and volumes.
Run a separate publisher on the same NAS or Linux host. Linux host networking
puts multicast on the host LAN while preserving the Agent's existing Docker
bridge. Build the publisher for the target NAS architecture, or use a publisher
image already built for it. The default Docker build still produces the Agent
image. [Docker host networking](https://docs.docker.com/engine/network/drivers/host/)

From the repository root on the target build host:

```sh
docker build --target discovery -t nastart-agent-discovery:local agent
```

On the Agent host, after its HTTPS port is reachable:

```sh
docker run -d --name nastart-agent-discovery --restart unless-stopped \
  --network host --read-only --cap-drop ALL --security-opt no-new-privileges:true \
  nastart-agent-discovery:local advertise \
  --mdns-address 192.168.1.10 --mdns-name MyNAS --port 8787
```

Replace `192.168.1.10` with the Agent host's LAN IPv4 address and use the
host-side HTTPS port. For DSM, run this on the NAS over SSH with Docker
access. The publisher is a separate Container Manager container from the SPK
project. For a systemd Docker installation, first start `nastart-agent.service`;
Docker restarts the publisher independently. A publisher outside the Agent
bridge cannot use the private Docker container IP as the advertised endpoint.

On bare Linux with Python, install the optional `zeroconf==0.154.0` and
`ifaddr==0.2.0` in a virtual environment and run `python3 nastart_agent.py
advertise --mdns-address 192.168.1.10 --mdns-name MyNAS --port 8787` there.

Discovery requires local multicast UDP 5353, a reachable HTTPS service and
the app's Local Network permission. Keep the phone and NAS on a multicast-
capable LAN. Guest Wi-Fi, client isolation, routed VLANs, IPv6-only networks
and Docker Desktop can require manual entry or QR import instead. If the
advertised address changes, recreate the publisher with the new address. The
IP selected for pairing also needs updating after a DHCP address change.

## TLS

Agent serves HTTPS by default as of 0.4.0. On first startup it uses OpenSSL to create a
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
the certificate changes. Restart the Agent and use the latest logged code to
pair another device.

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
SPK_BUILD_NUMBER=0009 scripts/build_spk.sh /path/to/nastart-agent-0.5.0-0009.spk
```

The SPK contains deployment files, metadata and icons. Installation downloads
`changlwtju/nastart-agent:0.5.0` from Docker Hub. The build derives the image
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
2. In **Container Manager → Container**, identify the `agent` container in
   the `nastart-agent-spk` project. Over DSM SSH, or in the Agent container's
   terminal, use the command below. In the container terminal, omit
   `sudo docker exec AGENT_CONTAINER`. Use `--web-key` in place of `--address …`
   to get the password for the browser view. Restart the `agent` container
   in Container Manager when you need a code for another device.

   ```sh
   sudo docker exec AGENT_CONTAINER python3 /app/nastart_agent.py show-config \
     --data-dir /data/container-data --address https://NAS_LAN_HOST:8787
   ```

3. In Nastart, pair using `https://<NAS LAN address>:8787` and enable **Skip SSL
   Verification** for the self-signed certificate. Keep the package data
   directory when restarting or upgrading to preserve existing pairings.

### Upgrade a Synology 0.4.0 SPK to 0.5.0

1. Confirm that Docker Hub has the 0.5.0 tag for the NAS architecture. Build
   `nastart-agent-0.5.0-0009.spk` with the command above.
2. In **Package Center → Manual Install**, select the new SPK to upgrade the
   existing Nastart Agent package in place. The Worker switches images for the
   same project and reuses `/var/packages/nastart-agent/var/container-data`.
3. In Container Manager, confirm the Agent is healthy and use the existing
   iPhone 13 App profile to refresh its connection. Once the service has
   restarted, the original token, Agent ID and certificate remain usable.
   Confirm `GET /healthz` reports version `0.5.0`.
4. Copy the latest code into the iPhone 18 App. Use the display instructions
   above for an image that includes `show-config`, or **Details → Log** for
   earlier 0.5.0 images. Refresh on both phones to confirm both pairings work.

The disposable lifecycle test requires Docker Desktop and Python 3.12+ on
the Mac. From the repository root, pass the built package or omit the path to
build a temporary one:

```sh
scripts/test_spk_lifecycle.sh /path/to/nastart-agent-0.5.0-0009.spk
```

## Install on a Linux Docker host with systemd

On a Linux host booted with systemd, start Docker Engine (`docker.service`) and
install Docker Compose v2 with `--wait-timeout`. With TCP 8787 available, run
from the repository root:

```sh
sudo scripts/install_agent_systemd.sh
sudo systemctl status nastart-agent.service
sudo docker exec nastart-agent python3 /app/nastart_agent.py show-config \
  --address https://LINUX_LAN_HOST:8787
```

The installer pulls the versioned image and copies the existing
`agent/compose.yaml` into `/opt/nastart-agent` with a root-only `.env`. The
systemd unit starts the stack after Docker and checks readiness. Add `sudo`
to the Web password command above if Docker requires it. Restart with
`sudo systemctl restart nastart-agent.service` to issue a new code.
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
for the downloaded image to become healthy. The SSH `--build` installer
uploads the Agent, proxy and bundled QR encoder for a local build. An existing
Compose installation uses the upgrade script.

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
