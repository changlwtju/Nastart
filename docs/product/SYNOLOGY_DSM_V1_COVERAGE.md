# Nastart Synology DSM V1 Coverage

Version: 0.1  
Status: Draft  
Last updated: 2026-07-25

## 1. Purpose

This document defines what "high completion for Synology DSM" means for
Nastart v1.

V1 should focus on making Synology DSM feel complete, automatic, and reliable.
Other NAS platforms should be prepared through Provider and Agent interfaces,
but deep compatibility for those platforms is not a v1 goal.

## 2. V1 Coverage Principle

Preferred implementation order:

```text
DSM API
-> App-side probe
-> Optional Nastart Agent
-> Manual correction fallback
```

Manual entry should only exist for corrections, unsupported services, unusual
network setups, or user customization. It should not be the normal setup path.

## 3. V1 Must-Have Synology Scope

| Area | V1 Requirement | Preferred Source | Agent Fallback |
|---|---|---|---:|
| NAS login | DSM address, session login, logout, session refresh | DSM API | No |
| Login security | HTTPS warning, self-signed certificate approval, fingerprint change warning | App-side probe | No |
| Credential storage | Store DSM credentials/tokens securely | Keychain | No |
| NAS identity | Device name, DSM version, model, serial-safe display data | DSM API | Optional |
| System overview | CPU, memory, uptime, network status | DSM API | Yes |
| Storage overview | Volumes, disk usage, available capacity, storage warnings | DSM API | Yes |
| Disk health | Disk temperature and SMART summary where available | DSM API | Yes |
| Network overview | LAN IP, gateway/DNS hints, basic traffic data where available | DSM API | Yes |
| Package list | Installed DSM packages and running state where available | DSM API | Optional |
| Docker containers | Container list, status, image name, container name | DSM/Container Manager API | Yes |
| Docker ports | Port mappings and candidate service endpoints | DSM/Container Manager API | Yes |
| Docker health | Running/stopped/restarting/unhealthy where available | DSM/Container Manager API | Yes |
| Service discovery | Generate candidate service cards from containers, packages, ports, HTTP fingerprints | DSM API + probe | Yes |
| Launchpad | Confirm, hide, edit, sort, categorize generated cards | Local app | No |
| Service opening | Local/remote URL selection, in-app browser, Safari | Local app | No |
| Reachability | HTTP/HTTPS availability, latency, last checked time | App-side probe | Optional |
| Certificate validity | Expiration date, issuer/subject summary, days remaining | App-side probe | Optional |
| Certificate change | Store fingerprint and warn when changed | App-side probe + Keychain/local store | Optional |
| Reminders | Domain, VPS, subscription, certificate, backup, custom reminders | Local app | Optional |
| Local notifications | Reminder notifications without Cloud | iOS notifications | No |
| External handoff | Video, audio, file, reader, remote/service client handoff | Local app | No |
| Media roots | User-confirmed DSM shared folders and supported media libraries | DSM API | Yes |
| Media browser | Lightweight folder/file listing for video/audio handoff | DSM API | Yes |
| Theme selection | Three polished Launchpad styles with classic and Liquid-ready presentation branches | Local app | No |
| iPad layout | Native iPad layout, not stretched iPhone UI | Local app | No |

## 4. DSM API Feasibility Spike

Before full UI development, build a small internal proof-of-concept that checks:

1. DSM login and session refresh.
2. HTTPS/self-signed certificate handling.
3. Device identity and DSM version.
4. CPU, memory, uptime, and network summary.
5. Volume and disk usage.
6. Disk temperature and SMART summary.
7. Installed packages and running states.
8. Container Manager availability.
9. Docker/container list.
10. Container status and image names.
11. Container port mappings.
12. Required DSM account permissions.
13. Behavior with 2FA-enabled accounts.
14. Behavior across DSM 7.x versions available for testing.

If items 8-11 are unstable or unavailable through DSM API, Agent becomes the
official enhanced path for Docker discovery and monitoring.

## 5. App-Side Probe Scope

The iOS app can directly implement these checks when it can reach the endpoint:

- HTTP/HTTPS reachability.
- Response latency.
- Redirect target.
- HTTP status code.
- TLS certificate expiration.
- TLS certificate fingerprint.
- Certificate chain warning.
- Page title.
- Favicon.
- Common service fingerprint hints.
- Local URL versus remote URL availability.

App-side probe should avoid becoming a port-scanning tool that feels invasive.
V1 should probe only endpoints discovered from DSM/Agent or confirmed by the
user.

## 6. Agent V1 Scope

Agent is not mandatory for first use, but it is part of v1 as the reliable
enhancement path when DSM API is incomplete. It should be included in the first
meaningful TestFlight if pairing and read-only discovery are stable enough.

V1 Agent should be read-only:

- pair with Nastart app
- perform capability handshake
- report Agent heartbeat and data freshness
- expose a narrow local HTTPS API
- list Docker containers
- read container status
- read container port mappings
- identify common service endpoints
- read basic host metrics
- read disk/temperature summary where permissions allow
- run safe diagnostics without modifying system state

V1 Agent should not:

- start, stop, restart, or delete containers
- modify Docker Compose files
- execute arbitrary shell commands
- change DSM/system settings
- expose Docker socket directly to the app
- act as a remote relay

Agent-backed compatibility:

- Synology remains the first-class v1 target.
- On Synology, Agent enriches DSM cards instead of replacing DSM.
- On other Docker-capable NAS or servers, Agent can create `Agent-only` cards
  for early testing, but the UI should label compatibility as experimental if
  the platform has not been verified.
- Launchpad should use capability flags rather than brand-specific assumptions
  when deciding whether to show container details, metric summaries, port
  mappings, or diagnostic actions.
- If Agent becomes unavailable, existing cards remain visible, Agent-only fields
  become stale/hidden, and a task asks the user to reconnect or review.

Testing boundary:

- The first hardware validation target is DS918+ / DSM 7.2.x and compatible
  Synology DSM environments.
- Without QNAP, TrueNAS, Unraid, TerraMaster, UGREEN, or other NAS hardware,
  those brands should not receive dedicated v1 UI paths or compatibility claims.
- Non-Synology Agent testing can start with generic Linux/Docker environments,
  but that validates the Agent protocol more than the NAS brand experience.
- Brand-specific storage, package, user, permission, app-store, or system-health
  views should wait until real hardware is available.
- V1 should keep provider abstractions and Agent-only mode ready, while public
  product language remains Synology-first.

## 7. Lifecycle and Reminder Scope

V1 should support local reminders for:

- domain expiration
- TLS certificate expiration
- VPS renewal
- paid subscription renewal
- backup freshness
- NAS-related license or service renewal
- custom reminder

Recommended V1 behavior:

- manual reminder creation is acceptable here, because many subscriptions do not
  expose stable APIs
- certificate reminders can be automatically suggested from known HTTPS
  endpoints
- domain reminders can be attached to remote URLs or manually entered domains
- local notifications should work without Cloud

## 8. iCloud Sync Position

iCloud/CloudKit sync is valuable for the iPhone + iPad product experience and
should be considered part of the preferred V1 direction if implementation risk
is acceptable.

Recommended position:

- V1 should prioritize local-first behavior plus iCloud/CloudKit sync.
- A custom Nastart Cloud backend is not required for V1.
- Membership should use a single user-facing tier, such as Nastart Plus.
- Sync should be implemented as a capability, not as a separate Cloud membership
  tier.
- Plaintext DSM credentials, DSM tokens, Agent tokens, and private keys must not
  be synced.

iCloud/CloudKit V1 sync candidates:

- service cards
- Launchpad layout and theme
- categories
- endpoint metadata without secrets
- reminders
- external app preferences
- certificate metadata and warning state when safe

Future custom Nastart Cloud capabilities:

- cloud backup and restore
- push notifications
- membership server validation
- cross-device continuity
- cross-platform sync beyond Apple devices

## 9. Deep Diagnostics

V1 should include lightweight diagnostics:

- endpoint reachable/unreachable
- local URL versus remote URL status
- HTTP/HTTPS warning
- certificate expired or changed
- DNS resolution hint
- DSM session expired
- Agent unavailable
- container stopped or unhealthy where available

Future deep diagnostics:

- reverse proxy path analysis
- DNS and DDNS mismatch explanation
- gateway/NAT loopback hints
- VPN/Tailscale/WireGuard context
- external port exposure checks
- backup task freshness
- container log redaction and summary
- AI-assisted explanation after explicit user opt-in

## 10. Additional Synology Features To Consider

These are worth evaluating during the DSM API feasibility spike:

- QuickConnect awareness, without depending on it as the main access model.
- Synology DDNS status.
- Resource Monitor data parity.
- Notification Center warnings.
- Security Advisor summary if exposed safely.
- Backup task freshness from Hyper Backup or Active Backup where available.
- Shared folder overview without browsing user files.
- Wake-on-LAN for known devices.
- DSM package update notices.
- Low-permission DSM account guidance.
- Exportable diagnostic report with secrets redacted.

## 11. V1 Definition of Done

Synology DSM v1 is considered complete enough when:

- a fresh user can connect DSM and get a useful Launchpad without manually
  entering every service
- Docker services can become cards through DSM API or Agent
- selected media roots can be browsed enough to hand video/audio files to
  external players
- CPU, memory, storage, network, and Docker state are visible at a glance
- certificates and service reachability produce clear warnings
- local reminders cover renewals the app cannot automatically know
- manual entry exists but feels like correction, not setup
- iPad layout feels intentional
- sensitive credentials are stored in Keychain
- no custom Cloud server is required for core local use
- iCloud/CloudKit sync keeps iPhone and iPad configuration aligned when enabled
