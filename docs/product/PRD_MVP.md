# Nastart MVP PRD

Version: 0.1  
Status: Draft  
Last updated: 2026-07-25

## 1. Purpose

This document defines the first shippable product scope for Nastart.

It is based on the strategic documents in this repository and the early product
discussion around building a NAS/HomeLab companion that is more useful than a
simple mobile bookmark grid, while still small enough to prototype and ship.

Detailed Synology DSM v1 coverage is defined in
`docs/product/SYNOLOGY_DSM_V1_COVERAGE.md`.

Competitive positioning and feature-boundary decisions are defined in
`docs/research/NASTART_COMPETITIVE_LANDSCAPE.md`.

Detailed Jellyfin, Emby, Navidrome, media resource, and external app handoff UX
flows are defined in `docs/design/MEDIA_SERVICE_FLOWS.md`.

Post-MVP directions that should be architecturally reserved, such as advanced
media playback, HTTPS/TLS certificate automation, Agent expansion, and
multi-provider NAS support, are tracked in
`docs/product/POST_MVP_ROADMAP.md`.

## 2. MVP Product Thesis

The first version of Nastart should solve one focused workflow:

```text
I want to see, organize, and reliably open my NAS services from iPhone and iPad.
```

The MVP should feel polished and useful because most first-run setup is
automatic on Synology DSM. Manual entry should exist as a fallback, not as the
main product experience.

## 3. Target Users

### 3.1 Primary

- Synology users running DSM and common self-hosted services.
- HomeLab users running Docker services such as Jellyfin, qBittorrent,
  Home Assistant, Portainer, AdGuard Home, Plex, Emby, Immich, and similar
  dashboards.
- Users who access the same service through different URLs depending on
  whether they are at home, on VPN, or outside the LAN.

### 3.2 Secondary

- QNAP, Unraid, TrueNAS, ZimaOS, CasaOS, and generic Linux server users.
- Users who need renewal reminders for domains, certificates, VPS, or paid
  NAS-related services.
- Users who want a calm status overview without using a full server admin app.

## 4. MVP Positioning

MVP positioning:

> A local-first native NAS launchpad for Apple users, optimized for Synology
> DSM, with service cards, lightweight media resource handoff, connection-aware
> opening, basic health checks, and lifecycle reminders.

The MVP should be honest about compatibility:

- Synology DSM is the primary target and best-supported experience.
- V1 should prioritize automatic setup through DSM API, app-side probing, and
  optional Agent.
- Manual device and service entry exists as a fallback when automation cannot
  identify or confirm a service.
- Other NAS compatibility is reserved through Agent/provider interfaces, but
  deep non-Synology support is future work.
- Nastart is a third-party companion app, not an official Synology product.

The MVP is not:

- a full server operations console
- a full Docker management tool
- a full DS One/Lenna-class media player
- a general file manager
- a generic public browser
- a hard-coded Synology-only utility
- a custom-backend-first sync product

The MVP may still include basic media playback and previews where platform
frameworks make them practical. The architecture should assume richer playback
engines can replace or supplement the V1 system-player path later.

## 5. Success Criteria

The MVP is successful if:

- a user can add one NAS and several services in under 5 minutes
- service cards are attractive enough to replace a mobile Homepage/Homarr page
- the app can remember local and remote access URLs for the same service
- credentials and secrets are stored safely in Keychain
- the app can warn about obvious reachability or certificate problems
- the launchpad works well on both iPhone and iPad
- Synology DSM setup can generate useful service cards without requiring users
  to manually enter every service
- the product can be submitted to TestFlight without a custom Nastart Cloud
  backend
- iPhone and iPad configuration can sync through iCloud/CloudKit when enabled
- DS One-overlapping media and file workflows feel polished enough that users do
  not perceive them as rough placeholders
- MyServers-overlapping monitoring and Docker workflows remain understandable
  for NAS users instead of turning into a dense server operations console
- the generated launchpad is attractive enough to be the App Store screenshot
  hero, not just an internal utility page

## 6. Core User Journeys

### 6.1 First Launch

1. User opens Nastart.
2. User chooses "Connect Synology DSM".
3. User enters DSM address and signs in with a DSM account.
4. Nastart checks reachability and connection security.
5. Nastart discovers available DSM data, packages, Docker/container data when
   available, web service candidates, certificates, and endpoints.
6. User confirms, hides, or edits discovered service cards.
7. Nastart creates the first launchpad.

### 6.2 Add Agent Enhancement

1. User chooses "Enhance with Agent" if DSM API discovery is incomplete or the
   user wants richer Docker/system data.
2. Nastart shows a guided local Docker deployment path.
3. User pairs the Agent with a one-time code or QR code.
4. Nastart merges Agent-discovered containers, ports, services, and metrics into
   the launchpad.

Agent should be included in v1 and exercised during the first meaningful
TestFlight, but it must remain optional. DSM API is still the primary Synology
onboarding path. Agent's first role is to improve
Docker/container/package/port/metric coverage and validate the future
multi-provider bridge.

Agent detection and capability rules:

- The app knows an Agent exists only after successful pairing, token validation,
  and a fresh capability handshake.
- A paired Agent should report a stable `agentId`, host identity, provider hint,
  supported API version, and capability flags.
- Capability flags should drive UI depth, not brand names alone.
- A Synology DSM device can be `DSM-only` or `DSM + Agent`.
- A non-Synology host can be `Agent-only` in v1 preview builds, with clear copy
  that compatibility is experimental unless tested.
- If Agent goes offline, the Launchpad should keep existing cards, mark Agent
  data as stale, and fall back to DSM/probe/manual data where available.

Discovery merge rules:

1. Use DSM identity as the primary device identity for Synology.
2. Match Agent-reported services to DSM/probe-discovered services by endpoint,
   container name, port mapping, package name, and normalized service type.
3. Do not duplicate a service card when Agent only enriches an existing DSM card.
4. Prefer Agent data for Docker/container/port/metric fields when the Agent data
   is fresher and successfully verified.
5. Keep user edits such as card name, icon, category, hidden state, and favorite
   state above all auto-discovered metadata.
6. When matching is uncertain, create a "review discovery" task instead of
   silently adding duplicate cards.

Agent impact surfaces:

- Launchpad: service card depth, generated service count, status confidence,
  container-linked badges, port-derived endpoints, and stale-data warnings.
- Device tab: connection mode, Agent health, host metrics, Docker/container
  details, package/service source labels, diagnostics, and permission warnings.
- Tasks: Agent offline, Agent permission changes, discovery conflicts,
  container warnings, stale metrics, and diagnostics that need user review.
- Mine / Settings: Agent setup guide, paired Agent management, privacy/security
  explanation, logs export for support, and experimental compatibility toggles.
- Onboarding: DSM remains the recommended first path for Synology. Agent can be
  offered after DSM setup, after weak discovery, or from Device Detail.

Non-Synology V1 boundary:

- Because v1 testing hardware is Synology DSM-focused, non-Synology support
  should not be marketed as a complete v1 feature.
- The app can keep an `Agent-only` experimental path for internal/TestFlight
  validation and future-proofing.
- Public App Store copy should say Synology is the first-class supported target.
- Untested NAS brands should be described as experimental or manual/Agent-based
  compatibility only.
- Any brand-specific card layout, device metric, storage view, or package view
  must wait until the platform has real-device validation.

### 6.3 Manual Correction Fallback

1. User taps "Add Service" or edits an auto-discovered card.
2. User fills only the fields automation could not infer.
3. Nastart checks the URL and stores service metadata.
4. Service appears on the launchpad.

### 6.4 Open Service

1. User taps a service card.
2. Nastart evaluates network context.
3. Nastart selects local, VPN, or remote URL based on rules and availability.
4. Nastart opens the service in the chosen browser mode.
5. If unavailable, Nastart shows a short diagnosis and alternative URL.

### 6.5 Open NAS Resource in External App

1. User taps a media service card such as Jellyfin, Emby, Plex, Navidrome, or
   Audio Station.
2. If the media service is web-only, a normal tap opens the service web UI.
3. If the media service is connected at library level, a normal tap opens Media
   Service Detail, whose first quick action remains "Open Web UI".
4. A long press, secondary action, or detail-page button opens "Open in..."
   actions for compatible external apps.
5. If the user opens a configured media library or shared folder, Nastart lists
   folders and playable files in a lightweight media browser.
6. User chooses a third-party app such as a video player, audio player, file
   manager, reader, or remote access client.
7. Nastart opens the target app through a supported URL scheme, universal link,
   or the iOS share/open-in flow.
8. If the target app is unavailable, Nastart offers App Store lookup, copy URL,
   or Safari fallback.

### 6.6 Add Lifecycle Reminder

1. User adds a domain, certificate, VPS, or subscription reminder.
2. User sets expiration date, renewal period, and alert timing.
3. Nastart stores the reminder locally.
4. Nastart surfaces upcoming renewals in the dashboard and notification center.

### 6.7 iPad Use

1. User opens Nastart on iPad.
2. User sees a wider dashboard rather than a stretched iPhone layout.
3. User can scan NAS status, services, and reminders in parallel.

## 7. MVP Features

### 7.1 Device Center

Required:

- Add, edit, and delete NAS/device profiles.
- Support Synology DSM as the primary device type.
- Support DSM API connection as the primary v1 path.
- Support optional Agent pairing as the richer discovery/monitoring path.
- Support manual generic NAS entry as fallback only.
- Show NAS identity, DSM version, and basic health summary where available.
- Store device display name, provider type, local address, optional remote
  address, and notes.
- Show reachability state.

Deferred:

- Deep non-Synology provider APIs.
- QNAP/Unraid/TrueNAS deep provider APIs.
- Automatic LAN discovery across all protocols.
 
Optional but strongly recommended for v1:

- DSM connection flow for Synology users.
- DSM API feasibility spike for system state, packages, and Container Manager
  data before full UI implementation.
- Optional local Agent path for Docker discovery and richer monitoring when DSM
  API is incomplete. Include this in the first TestFlight scope if the basic
  pairing and read-only discovery flow is stable enough.
- Agent/provider interfaces reserved for future non-Synology NAS support.

### 7.2 Launchpad

Required:

- Native SwiftUI service cards.
- Categories and simple ordering.
- Auto-generated service cards from DSM API, app-side probing, and optional
  Agent data.
- Manual service entry and editing as fallback.
- Local URL and remote URL per service.
- In-app browser and Safari opening options.
- Basic status badge: unknown, reachable, unreachable, warning.
- iPhone and iPad layouts.
- Three polished built-in launchpad themes rather than many shallow skins.
- Theme support should adapt between classic iOS-style surfaces and iOS 26+
  Liquid Glass-style surfaces when platform support is available.

Deferred:

- Full theme designer, theme marketplace, and advanced wallpaper modes.
- Live widgets inside cards.
- Shared dashboards.
- Plugin metadata ecosystem.

### 7.3 Connection-Aware Opening

Required:

- Store multiple access endpoints for a service.
- Prefer local URL when local network reachability is positive.
- Fall back to remote URL when local URL is unavailable.
- Clearly show HTTP, invalid certificate, or certificate-change warnings.

Deferred:

- Full VPN detection.
- Reverse proxy path diagnostics.
- NAT loopback detection.
- AI-assisted diagnosis.

### 7.4 External App Handoff

Required:

- Include basic system playback for common video and audio resources where
  platform frameworks make it practical.
- Do not build a full custom DS One/Lenna-class playback engine in v1.
- Allow supported service cards and resource endpoints to expose "Open in..."
  actions.
- Support media-service card actions from Jellyfin, Emby, Plex, Navidrome,
  Audio Station, Video Station, and similar discovered services.
- Support generic iOS share/open-in fallback.
- Maintain a metadata registry for known external apps.
- Allow users to choose a default external app per service or resource type.
- Fall back gracefully when a target app is not installed.

Recommended first video registry:

- Infuse
- VidHub
- Lenna
- VLC
- Fileball
- nPlayer
- SenPlayer
- zFuse
- NetEase Popcorn
- DS video as a legacy Synology option when available

Recommended first audio registry:

- Stream Music / 音流
- Finamp
- Amperfy
- play:Sub
- Evermusic
- Flacbox
- foobar2000
- VLC
- Plexamp
- DS audio as a legacy Synology option when available

Other handoff categories to consider:

- file managers: Documents, FileBrowser, FE File Explorer, Owlfiles, DS file
- ebook/comic readers: YACReader, Panels, Chunky, PDF Expert
- remote access clients: Termius, Blink Shell, ShellFish, Jump Desktop,
  Microsoft Remote Desktop
- smart home and service clients: Home Assistant, Jellyfin, Emby, Plex, Immich
- download and media automation clients: LunaSea, NZB360-equivalent iOS clients
  where available, qBittorrent or Transmission remote clients

Plex v1 rule:

- include Plex in first-class media browsing only if API/auth feasibility is
  verified early
- otherwise ship Plex as a high-quality web-service card with external app
  handoff

Implementation notes:

- Prefer documented URL schemes or universal links when available.
- Do not assume every external app can accept every protocol or library
  endpoint.
- Store integration metadata remotely or in a versioned local registry so the
  app can adapt when third-party URL schemes change.
- Direct media handoff requires a playable URL or supported library endpoint.
  If Nastart only knows a web UI URL, it should open the service instead.
- External clients for SSH, remote desktop, or file management should be
  presented as handoff targets only; Nastart should not ask for or proxy those
  credentials in v1 unless the security model is explicitly designed.

Deferred:

- Full custom video playback engine.
- Full custom audio playback engine.
- Advanced subtitle/audio-track/quality controls.
- Media scraping.
- Watch progress sync.
- Subtitle management.
- App-specific advanced automation.

### 7.5 Lightweight Media Browser

Required:

- Let users add or confirm media roots from DSM shared folders, WebDAV/HTTP
  endpoints, or supported service/library endpoints.
- Show a simple folder/file list for video and audio resources.
- Detect common playable file extensions and basic file metadata where DSM API
  provides it.
- Open common playable files through basic system playback when feasible.
- Open complex or unsupported media through the external app handoff flow.
- Provide quick actions: play, open with default app, choose app, copy URL/path,
  share.
- Keep this feature focused on "find media, play common formats, and hand off
  complex cases"; do not add full player-engine or full file-management
  operations.

Recommended v1 media roots:

- DSM shared folders selected by the user, such as `video`, `music`,
  `downloads`, or custom media directories.
- WebDAV/HTTP file endpoints when the user or DSM setup exposes them safely.
- Jellyfin, Emby, Plex, Navidrome, Subsonic-compatible, Audio Station, and Video
  Station library endpoints when a stable handoff URL can be produced.

Implementation notes:

- DSM API should be the first path for browsing Synology shared folders.
- Optional Agent can improve path discovery, file URL generation, and permission
  checks when DSM API is insufficient.
- Manual path selection should be a fallback or confirmation step, not the
  default setup burden.
- If Nastart cannot produce a playable URL for an external app, it should open
  the parent service or copy/share the resource instead of pretending playback
  is available.

Deferred:

- Upload, move, rename, delete, or batch file operations.
- Full NAS file manager.
- Media scraping, posters, metadata matching, subtitles, and watch progress.
- Transcoding, streaming proxy, or in-app player.

### 7.6 Basic Health Checks

Required:

- Lightweight HTTP reachability check for service URLs.
- Last checked timestamp.
- Simple service health state.
- Manual refresh.
- Certificate expiration checks for known HTTPS endpoints.
- Certificate fingerprint change warning for approved services.

Optional for MVP:

- Basic NAS reachability.
- DSM-backed CPU, memory, storage, disk, and network summary where feasible.

Deferred:

- Background continuous monitoring.

Agent-backed v1 enhanced checks:

- CPU, memory, storage, and temperature summary where available.
- Docker container state and mapped endpoint discovery.
- Basic Docker health status if exposed by the container runtime.
- SMART summary only if available without broad privileges.

Automation priority for v1:

1. DSM API for Synology account, system, package, storage, and available
   container data.
2. App-side probes for service reachability, TLS certificates, title/favicon,
   and endpoint fingerprints.
3. Optional Agent for Docker details, metrics, and diagnostics that DSM API
   cannot reliably expose.
4. Manual entry only for corrections and unsupported services.

### 7.6 Reminder Center

Required:

- Manual lifecycle reminders for domains, certificates, VPS, subscriptions,
  and backups.
- Expiration date, renewal cadence, alert lead time, and notes.
- Local notifications if technically available and permission is granted.

Deferred:

- API integrations with cloud vendors.
- Automatic domain WHOIS lookup.
- Automatic certificate scanning across all services.
- server-triggered push notifications.

### 7.7 Security and Privacy

Required:

- Keychain storage for credentials and tokens.
- No mandatory account.
- No ads.
- No cross-app tracking.
- No global ATS disable.
- Explicit user approval for HTTP and self-signed certificates.
- Privacy policy and support link before App Store submission.

Deferred:

- App Attest integration unless Cloud exists.
- Biometric lock.

### 7.8 Monetization

MVP implementation can ship without paywall, but architecture should support:

- Free: one NAS, limited cards, basic DSM connection, manual fallback.
- Nastart Plus: multiple NAS, more cards, themes, diagnostics, reminders, and
  iCloud sync.
- Future server Cloud: push notifications, cloud backup, cross-platform sync,
  membership server validation.

StoreKit 2 should be planned before public release if Nastart Plus features are
included.

Pricing posture:

- Keep Nastart Plus inexpensive relative to nearby NAS utilities.
- Offer monthly, annual, and lifetime purchase options if App Store review and
  implementation constraints allow.
- Treat annual as the primary plan and lifetime as a user-friendly option for
  NAS hobbyists who dislike subscriptions.
- Candidate V1 pricing: USD 0.99 monthly, USD 7.99-9.99 annual, USD 14.99
  lifetime; China storefront candidates: CNY 6-8 monthly, CNY 38-48 annual,
  CNY 88-98 lifetime.
- Do not create separate Pro, Cloud, Theme, or Media tiers in V1.

## 8. MVP Non-Goals

- No custom Nastart Cloud backend in first prototype.
- No mandatory Agent requirement for first usable prototype.
- No guarantee of full Agent compatibility on untested non-Synology NAS
  platforms.
- No deep non-Synology NAS support in v1.
- No SSH terminal.
- No general-purpose SFTP/file manager.
- No media playback.
- No first-party video decoder or media library scraper in v1.
- No full Docker control.
- No public web search or general-purpose browser.
- No automation that modifies NAS state.
- No Apple Watch, Apple TV, or Vision Pro native app.

## 9. Release Milestones

### M0: Documentation Baseline

- MVP PRD
- iOS architecture
- data model
- information architecture
- first security checklist

### M1: Local Prototype

- SwiftUI app shell
- device list
- DSM connection prototype
- automatic service card generation prototype
- launchpad cards
- in-app browser/Safari opening

### M2: Trustworthy Local App

- Keychain integration
- endpoint security warnings
- reachability checks
- reminder center
- iPad layout

### M3: TestFlight Candidate

- onboarding polish
- settings and export
- local notification permissions
- privacy policy/support website
- App Store metadata draft

## 10. Open Questions

- Should the first Xcode project use SwiftData or a repository layer over
  SQLite from day one?
- Should Nastart Plus monetization exist in the first public TestFlight build?
- How much Synology DSM integration should be attempted before Agent exists?
- Should Agent be open source from the first Agent preview?
- Which DSM/Container Manager APIs are stable enough for v1 automatic discovery?
- What is the final app name, icon, and brand system?
