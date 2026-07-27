# Nastart Post-MVP Roadmap

Version: 0.1
Status: Draft
Last updated: 2026-07-27

## 1. Purpose

This document records important post-MVP directions so they are not forgotten
while V1 stays focused.

The goal is not to expand V1 until it becomes impossible to ship. The goal is
to make V1 architecture leave room for the features Nastart is likely to need
in V1.5, V2, and later versions.

Guiding rule:

```text
Do not build every advanced feature in V1, but do not block them with V1
architecture.
```

## 2. V1 Foundation Requirements

V1 should reserve interfaces for future depth in these areas:

- media library providers
- playback engines
- external app handoff
- Agent providers
- NAS provider adapters
- certificate and domain records
- diagnostics tasks
- Launchpad card widgets
- theme tokens and layout presets
- file/resource providers
- entitlement-gated advanced features

V1 may ship simpler implementations behind these interfaces.

## 3. Media And Playback Roadmap

### 3.1 V1: Basic Media Loop

V1 should provide a real but constrained media loop:

```text
Launchpad media service card
-> Media Service Detail
-> Library / resource list
-> Item detail
-> play with system player or hand off to external app
```

V1 playback scope:

- Jellyfin and Emby library connection where feasible.
- Navidrome/Subsonic-style music library connection where feasible.
- Basic video playback through system player for common formats.
- Basic audio playback with background/lock-screen controls if practical.
- Image, text, PDF, and common file previews through system frameworks.
- External handoff to Infuse, VidHub, VLC, Jellyfin/Emby apps, audio players,
  and share/open-in fallback.

V1 should avoid:

- custom full video engine
- complex subtitle management
- transcoding controls
- offline downloads
- advanced metadata scraping
- full watch-progress ecosystem
- full Apple TV media-player experience

### 3.2 V1 Architecture To Reserve

The implementation should avoid binding UI directly to a single API or player.

Recommended abstractions:

```text
MediaLibraryProvider
PlaybackRouter
PlaybackEngine
MediaResourceRepository
ExternalAppHandoffRegistry
```

Candidate provider implementations:

- `JellyfinLibraryProvider`
- `EmbyLibraryProvider`
- `NavidromeLibraryProvider`
- `SubsonicLibraryProvider`
- `DSMFileProvider`
- `WebDAVProvider`
- `AgentPathProvider`

Candidate playback engines:

- `SystemAVPlaybackEngine` for V1
- `ExternalPlayerEngine` for V1
- `AdvancedVideoPlaybackEngine` for V2+
- `AdvancedAudioPlaybackEngine` for V2+

### 3.3 V2: Fuller Media Experience

Later versions should move toward a DS One/Lenna-class media experience:

- richer video library browsing
- poster grids and detail pages
- recently added and continue watching
- playback progress sync where service APIs allow it
- subtitle track selection
- audio track selection
- quality/stream selection
- better codec and container handling
- more complete audio queue and playlist behavior
- iPad-optimized media browsing
- Apple TV media surface when product maturity supports it

This should be treated as a major product track, not a small enhancement.

## 4. HTTPS/TLS Certificate Automation

### 4.1 V1: Observe And Remind

V1 should focus on certificate visibility:

- inspect HTTPS/TLS certificate expiry
- detect certificate changes
- warn about expired or soon-expiring certificates
- pin or remember trusted self-signed certificate fingerprints
- attach certificate records to services/domains
- create Tasks for certificate problems

### 4.2 V2+: Assist Renewal

Later versions can add certificate automation, but only after security and
provider boundaries are mature.

Possible features:

- ACME account management
- DNS provider integrations
- certificate renewal scheduling
- certificate deployment through Agent
- reverse-proxy certificate mapping
- renewal history
- failure diagnostics

Important boundary:

- This refers to HTTPS/SSL/TLS certificates, not SSH host keys or SSH login
  credentials.
- V1 should not store DNS provider secrets casually.
- Any certificate automation should prefer local-first Agent execution and
  Keychain-protected credentials.
- High-risk operations need explicit confirmation and clear logs.

## 5. Agent Roadmap

### 5.1 V1: Optional Enhancement

Agent should improve discovery and monitoring without becoming required for the
first Synology experience.

V1 Agent candidates:

- Docker container discovery
- port mapping discovery
- richer CPU/memory/disk/network metrics
- service process mapping
- local health checks
- Agent online/offline status

### 5.2 V2+: Multi-Provider Bridge

Agent should become the compatibility bridge for:

- QNAP
- Unraid
- TrueNAS SCALE
- ZimaOS
- CasaOS
- generic Linux servers
- Docker-capable hosts

Post-MVP Agent features:

- guided Docker Compose installation
- pairing QR code or one-time code
- read-only mode
- permission model
- update channel
- diagnostics export
- optional controlled actions
- local certificate deployment support

## 6. NAS Provider Expansion

V1 is Synology-first. Later versions should add provider adapters without
changing the app's top-level IA.

Provider roadmap:

```text
Synology DSM
-> Agent-backed generic Docker host
-> QNAP / Unraid / TrueNAS / CasaOS / ZimaOS provider adapters
```

V1 should define provider protocols for:

- identity
- storage
- packages/apps
- containers
- metrics
- shared folders
- certificates
- network endpoints

Non-Synology support should be marketed cautiously until tested.

## 7. Launchpad Evolution

Launchpad remains Nastart's visual and product center.

### 7.1 V1

- 3 polished built-in themes.
- Service groups.
- Card sizes.
- Status indicators.
- Optional top device summary.
- Basic card display density presets.
- Basic background modes.
- Long-press actions.

### 7.2 Post-MVP

- custom background images
- automatic background readability treatment
- manual opacity, blur, and dim controls
- richer service widgets
- per-service card display-item settings
- collapsible groups
- saved layout presets
- iCloud-synced layouts
- iPad dashboard inspector
- future Apple TV status-wall layout
- eventually user-designed dashboard templates

Quality rule:

```text
Add customization only when the default themes already feel excellent.
```

## 8. Files And Resource Management

### 8.1 V1

- browse DSM shared folders lightly
- preview common file types
- open files in external apps
- play common audio/video through system player
- avoid destructive file operations

### 8.2 Post-MVP

- favorites and recents
- richer folder search
- upload/download queue
- safe rename/move/copy/delete
- conflict handling
- transfer progress
- offline cache
- WebDAV/SFTP/Agent-backed provider expansion

File management should grow slowly because mistakes can be destructive.

Settings that should be reserved under Mine:

- cache size limit
- clear cache
- temporary file retention
- upload/download Wi-Fi or cellular policy
- background transfer behavior
- transfer queue visibility
- failed transfer retry behavior

## 9. Diagnostics And Automation

V1 diagnostics should explain common failures:

- endpoint unreachable
- certificate expired or changed
- local URL unavailable
- remote URL unavailable
- service HTTP status abnormal
- Agent offline

Post-MVP diagnostics can add:

- DNS checks
- reverse proxy path checks
- NAT loopback hints
- port reachability from Agent
- service dependency checks
- backup freshness checks
- structured repair suggestions
- optional automation scripts

Automation should produce Tasks and require explicit confirmation for risky
actions.

## 10. Widgets And Platform Expansion

Post-MVP platform work:

- iOS Home Screen widgets
- Lock Screen widgets
- Live Activities for long checks or transfers if useful
- iPad dashboard refinements
- macOS menu bar/status window
- Apple TV read-only Launchpad/status wall
- Apple Watch critical alerts later

These should reuse the same service, task, and status models.

## 11. Plus And Entitlement Evolution

Plus should unlock advanced value without making basic V1 feel broken.

Possible Plus features:

- iCloud/CloudKit sync
- multiple NAS/devices
- advanced Launchpad themes
- custom backgrounds
- richer card widgets
- more reminders and task rules
- advanced diagnostics
- Agent convenience features
- platform widgets
- future media enhancements

Avoid making core security or basic local access dependent on Plus.

## 12. Open Decisions

These should be revisited before implementation milestones:

- Which system-playable video/audio formats are realistic enough for V1?
- Which Jellyfin/Emby/Navidrome APIs are reliable enough for V1?
- Which external player URL schemes are stable and verifiable?
- Whether Agent is stable enough for the first meaningful TestFlight, or should
  be staged behind a feature flag shortly after.
- Which certificate automation path is safest: app-only, Agent-assisted, or
  external tool handoff.
- When a Media tab becomes justified, if ever.
