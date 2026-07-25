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

## 2. One-Sentence Positioning

Nastart is a local-first NAS launchpad and lightweight operations assistant for
Apple users.

## 3. Target Users

Primary users:

- Synology users
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
- themes
- wallpaper-like immersive modes
- compact status summaries
- iPhone and iPad layouts
- internal or external browser opening

Cards should gradually move beyond shortcuts into live service surfaces.

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
| Health Monitor | NAS and service status summaries | P0 |
| Reminder Center | Domains, certificates, subscriptions, backups | P1 |
| Theme System | Visual styles and card layouts | P1 |
| Widget System | Home Screen and Lock Screen summaries | P1 |
| Diagnostics | Explain why a service is unreachable | P1 |
| Agent Console | Pairing, permissions, and Agent status | P1 |
| Cloud Sync | Optional encrypted sync | P2 |
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
- Cloud must not receive plaintext NAS credentials.
- HTTP should be limited to explicit local or user-approved services.
- Self-signed certificates should be pinned by fingerprint after user approval.
- High-risk Agent operations require explicit confirmation.

## 8. Differentiation

Nastart should not compete mainly as:

- a full SSH terminal
- a server admin suite
- a media player
- a basic bookmark launcher

Its most defensible space is:

```text
automatic discovery
+ intelligent access
+ native Apple launchpad
+ connection diagnosis
+ lifecycle reminders
+ local-first security
```

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

