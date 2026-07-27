# Nastart Product Blueprint

Version: 0.1  
Status: Draft  
Last updated: 2026-07-25

## 1. Product Vision

Nastart helps NAS and HomeLab users turn scattered services, devices, domains,
certificates, containers, and status signals into one beautiful, secure, native
Apple experience.

The product should feel less like a server control panel and more like a calm,
designed home base for a personal digital infrastructure.

Product design motto:

```text
简约而不简单
```

Nastart should look clean and approachable on every top-level page, while still
revealing rich capability through subpages, details, sheets, and settings when
the user needs them.

## 2. One-Sentence Positioning

Nastart is a local-first Synology-first NAS launchpad and lightweight
operations assistant for Apple users.

## 3. Target Users

Primary users:

- Synology DSM users
- HomeLab users
- Docker self-hosting users
- Users who maintain Jellyfin, qBittorrent, Home Assistant, Portainer, AdGuard
  Home, Plex, Emby, and similar services

Secondary users:

- QNAP, Unraid, TrueNAS, and Linux server users
- Small teams or families sharing local services
- Advanced users who want monitoring and lifecycle reminders

## 4. Core Product Pillars

### 4.1 Automatic Discovery

Nastart should automatically identify services from:

- Docker containers
- Docker labels
- Docker Compose projects
- Known image names
- Exposed ports
- HTTP page fingerprints
- Synology DSM packages
- User-confirmed service metadata

The app should not pretend detection is perfect. If confidence is low, it
should present a clear candidate list and let the user confirm.

For v1, discovery should be optimized around Synology DSM and common Docker
services. The preferred order is DSM API, app-side probing, optional Agent, then
manual correction. Other NAS platforms should be architecturally reserved
through Agent/provider interfaces, but deep support can wait until later
versions.

When installed, the local Agent may provide Docker and system discovery. In v1
it should primarily strengthen Synology coverage where DSM API is incomplete.
For non-Synology NAS or Linux hosts, Agent support should be treated as a future
compatibility path until tested hardware is available.

### 4.2 Intelligent Access

The product should understand that NAS access is context-dependent:

- local IP
- LAN hostnames
- public domain names
- reverse proxy paths
- VPN-only addresses
- HTTP
- HTTPS
- self-signed certificates
- expired or changed certificates

The app should help users reach the correct service URL depending on network
environment and security state.

### 4.3 Native Launchpad

The launchpad should be beautiful, fast, and personal.

It should support:

- service cards
- categories
- card sizes
- a small set of polished built-in themes
- wallpaper-like immersive modes
- compact status summaries
- iPhone and iPad layouts
- internal or external browser opening

Cards should gradually move beyond shortcuts into live service surfaces.

V1 theme direction should be quality-first:

- ship roughly three excellent themes, not many superficial skins
- treat Clean Grid, Command Center, and Glass Deck as candidate directions until
  low-fidelity launchpad sketches are reviewed
- keep the surrounding app shell stable; theme switching should affect the
  launchpad surface, not make the whole app feel like a different product
- include a calm native default, an information-dense operations view, and a
  premium glass-oriented showcase theme
- adapt themes for classic iOS-style surfaces below iOS 26 and Liquid
  Glass-style surfaces on iOS/iPadOS/macOS/tvOS 26+ where supported
- design launchpad components with future macOS and Apple TV layouts in mind,
  even if those platforms are not first-release targets
- defer full user-designed dashboards until after the core templates feel
  excellent

### 4.4 Status Monitoring

Nastart should surface important NAS and service health:

- CPU
- memory
- storage
- temperature
- disk and SMART status
- Docker health
- service reachability
- certificate validity
- domain expiration
- backup and subscription reminders

The first version does not need every metric, but the data model should support
future depth.

### 4.5 Lifecycle Guardian

The product should remember what users usually forget:

- domain expiration
- certificate expiration
- NAS subscription or service renewal
- backup task freshness
- storage thresholds
- container failures
- external access breakage

This is a key differentiator from generic launchers.

## 5. Major Modules

| Module | Purpose | Priority |
|---|---|---:|
| Device Center | Manage NAS and Agent connections | P0 |
| Service Discovery | Detect Docker, DSM packages, and web services | P0 |
| Launchpad | Native service dashboard and navigation | P0 |
| Browser Router | Internal/Safari opening and network-aware URL choice | P0 |
| External App Handoff | Open NAS media, file, and service resources in user-selected third-party apps | P0/P1 |
| Health Monitor | NAS and service status summaries | P0 |
| Reminder Center | Domains, certificates, subscriptions, backups | P1 |
| Theme System | Three polished themes, platform-adaptive cards, and future customization foundation | P1 |
| Widget System | Home Screen and Lock Screen summaries | P1 |
| Diagnostics | Explain why a service is unreachable | P1 |
| Agent Console | Pairing, permissions, and Agent status | P1 |
| iCloud Sync | Apple-device configuration sync through CloudKit | P0/P1 |
| Future Nastart Cloud | Optional server-backed sync, push, backup, and cross-platform continuity | P2 |
| Automation | ACME, scripts, and controlled operations | P2 |

## 6. First Product Experience

The ideal first-run flow:

1. User adds a NAS or installs Nastart Agent.
2. Nastart verifies connection security.
3. Nastart discovers services and asks for confirmation.
4. Nastart generates a launchpad.
5. User chooses a theme.
6. Nastart detects local/public access options.
7. User opens qBittorrent, Jellyfin, DSM, Home Assistant, or other services.
8. Nastart begins basic health and lifecycle reminders.

## 7. Security-Driven Product Requirements

Product design must follow these assumptions:

- App clients can be modified or cracked.
- Membership verification cannot be trusted to protect user NAS security.
- NAS credentials must be stored in Keychain.
- iCloud/CloudKit or future Cloud sync must not receive plaintext NAS
  credentials.
- HTTP should be limited to explicit local or user-approved services.
- Self-signed certificates should be pinned by fingerprint after user approval.
- High-risk Agent operations require explicit confirmation.

## 8. Differentiation

Nastart should not compete mainly as:

- a full SSH terminal
- a server admin suite
- a media player
- a basic bookmark launcher

DS One and MyServers should be treated as the two most important practical
benchmarks:

- DS One is the quality benchmark for NAS media, file access, Apple-platform
  polish, and user-facing simplicity.
- MyServers is the reference for server monitoring, Docker visibility,
  Agent-assisted data collection, widgets, and power-user workflows.

Nastart should match the baseline expectations these apps create where features
overlap, but it should not try to become a larger version of either. Its own
product center is the Apple-native NAS launchpad: automatic discovery,
beautiful card generation, service opening, status, handoff, and lifecycle
reminders in one coherent workflow.

Nastart must also avoid feeling like a bundle of unrelated features. Many
individual capabilities overlap with existing NAS apps, media apps, server
tools, and dashboard projects. The product should win by turning those pieces
into one coherent Apple-native NAS experience.

Post-MVP directions and required V1 extension points are tracked in
`docs/product/POST_MVP_ROADMAP.md`. In particular, V1 should leave room for a
future DS One/Lenna-class playback experience, Agent-backed multi-provider NAS
support, HTTPS/TLS certificate automation, richer Launchpad widgets, and safer
file/resource management without making the first release unshippable.

Its most defensible space is:

```text
automatic discovery
+ intelligent access
+ native Apple launchpad
+ lightweight media resource browser
+ external handoff to best-in-class specialist apps
+ connection diagnosis
+ lifecycle reminders
+ local-first security
```

The proprietary product hook should be:

```text
From NAS detection to a beautiful working launchpad in minutes.
```

This hook should guide prioritization:

- automatic Synology/Docker/service discovery is the starting point
- Launchpad themes are a core product surface, not decoration
- service cards should combine opening, health, endpoint choice, and handoff
  actions in one native pattern
- lifecycle reminders should live beside services so users remember domains,
  certificates, VPS, subscriptions, and backup freshness
- media, file preview, external app handoff, and diagnostics should feel like
  extensions of the service card model, not separate mini-apps

If a feature cannot connect back to the launchpad, device health, lifecycle
guardian, or trusted local-first model, it should be deferred.

Nastart should not become a media player, general file manager, terminal, or
remote desktop client, but it should make specialist apps feel well integrated.
For media workflows, Nastart should be able to discover or let users confirm
media roots, list folders and playable files, and hand those resources to
external apps. When a service exposes a playable media URL, supported library
endpoint, file URL, or remote access endpoint, Nastart can hand off to external
apps through documented schemes, universal links, or the iOS share/open-in flow.

V1 media handoff should have two trigger levels:

- Service-card level: tapping Jellyfin, Emby, Plex, Navidrome, Audio Station,
  Video Station, or similar cards opens the service; long press or a detail-page
  action opens external player choices.
- Resource level: opening a media root lets users browse folders/files and hand
  a selected video or audio file to a compatible player.

Early handoff categories:

- video players: Infuse, VidHub, Lenna, VLC, Fileball, nPlayer, SenPlayer,
  zFuse, NetEase Popcorn, DS video
- audio players: Stream Music / 音流, Finamp, Amperfy, play:Sub, Evermusic,
  Flacbox, foobar2000, VLC, Plexamp, DS audio
- files and readers: Documents, FileBrowser, FE File Explorer, Owlfiles,
  YACReader, Panels, Chunky, PDF Expert
- remote access: Termius, Blink Shell, ShellFish, Jump Desktop, Microsoft
  Remote Desktop
- service clients: Home Assistant, Jellyfin, Emby, Plex, Immich

Only verified integrations should be enabled by default. Unverified apps should
fall back to the share sheet or user-configured schemes.

## 9. Long-Term Direction

Long-term possibilities:

- Plugin metadata ecosystem
- Service integration marketplace
- Open Agent protocol
- Community service fingerprints
- Family or team shared dashboards
- macOS dashboard mode
- Apple Watch health alerts
- Apple TV status wall
- Optional AI-assisted diagnosis
