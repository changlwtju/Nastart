# Nastart Competitive Landscape

Version: 0.3
Status: Draft
Last updated: 2026-07-27

## 1. Purpose

This document records the competitive framing for Nastart before detailed UI
design and implementation.

The goal is not to avoid all feature overlap. NAS and HomeLab apps inevitably
share connection, file, media, Docker, and monitoring workflows. The goal is to
decide where Nastart should match basic expectations, where it should stay
deliberately lighter, and where it must feel meaningfully better.

Primary benchmark apps:

- DS One
- MyServers

Secondary reference categories:

- Synology official apps
- Jellyfin, Emby, Plex, Navidrome clients
- Infuse, VidHub, VLC, Stream Music, and other specialist players
- Homepage, Homarr, Dashy, CasaOS, and other self-hosted dashboards
- ServerCat, NeoServer, WebSSH-style server tools

## 2. Competitive Thesis

Nastart should not try to become a larger DS One or a larger MyServers.

The product should use them as quality references, then win through a more
specific workflow:

```text
Connect Synology DSM
-> automatically discover apps, containers, services, ports, certificates, and reminders
-> generate a beautiful native Apple launchpad
-> open, monitor, hand off, and remember lifecycle events from one place.
```

DS One proves that an independent NAS app can feel polished and useful for
media-heavy users. MyServers proves that mobile server monitoring, Docker, and
Agent-assisted operations have real demand. Nastart should combine the most
relevant lessons from both while avoiding the risk of looking like a stitched
bundle of tools.

## 3. DS One Comparison

### 3.1 Public Positioning

Based on App Store public information, DS One positions itself as an all-in-one
NAS cloud tool and emphasizes video, music, and file management. The listing
mentions support for Synology and Emby, broad media playback formats, subtitles,
picture-in-picture, audio formats, playlist/song management, and file browsing.
It is available for iPhone, iPad, and Apple TV.

### 3.2 Apparent Strengths

- Strong media-first identity.
- Built-in video playback is a major attraction.
- Audio, subtitle, picture-in-picture, and media-library handling deepen the
  product beyond a simple NAS browser.
- Apple TV support makes the media direction more coherent.
- The app appears visually polished enough that users mention appearance as a
  positive signal.
- DS One has enough maturity that Nastart should treat it as a serious quality
  benchmark, not as a simple feature checklist.

### 3.3 Nastart Should Learn

- Media workflows must be smooth even if Nastart is not primarily a player.
- NAS resources should not feel like raw files only; they need meaningful entry
  points such as media service cards, folder previews, and "open with" actions.
- App Store screenshots and first-run flows should communicate quality quickly.
- iPhone, iPad, and Apple TV layouts should be planned early, even if not all
  platforms ship at the same depth in v1.

### 3.4 Nastart Should Not Copy Blindly

- Do not try to outbuild DS One as a full video/audio player in v1.
- Do not make scraping, subtitle management, and advanced playback the center of
  the product.
- Do not turn the file browser into a full file manager before the launchpad
  workflow is excellent.
- Do not let media features hide the product's main value: automatic service
  discovery and launchpad generation.

### 3.5 Nastart Opportunities Against DS One

Nastart can be more differentiated if it is better at:

- Synology-first automatic service discovery.
- Docker/package/service-card generation.
- Beautiful NAS launchpad themes.
- Service reachability and certificate status.
- Domain, VPS, certificate, backup, and subscription reminders.
- Context-aware opening between local, VPN, and remote URLs.
- External handoff to specialist players instead of forcing every media use
  case into the app.

## 4. MyServers Comparison

### 4.1 Public Positioning

Based on App Store public information, MyServers positions itself as an
all-in-one server monitoring and management tool. Its listing emphasizes SSH,
Docker, monitoring, widgets, AI assistant, multi-platform compatibility,
one-click installation through SSH, encrypted communication, service health
checks, download managers, Proxmox, file management, and Frp topology.

The listing states that the free version supports managing one server and two
applications, while the paid version unlocks all features.

### 4.2 Apparent Strengths

- Broad operations feature set.
- Server and application monitoring are central.
- Docker management is deeper than a simple status badge.
- Agent/server-side component allows richer data collection.
- Supports many non-NAS and cloud-server scenarios.
- Widgets and alerts align with server-owner daily workflows.

### 4.3 Apparent Risks To Learn From

Broad feature coverage can create product risk:

- The app may feel complex to new users.
- Many modules can make the product feel less focused.
- Onboarding and language quality become more important when the product has
  many technical paths.
- A server operations app can drift toward a power-user console instead of a
  calm daily launchpad.

These are product risks, not judgments about the app. They are exactly the
risks Nastart should avoid because Nastart is being built by a small team and
must feel refined before it feels large.

### 4.4 Nastart Should Learn

- Optional Agent is a practical way to get reliable server/container data.
- Service health checks and notifications are real user needs.
- Widgets can become a strong retention feature later.
- Free limits and paid unlocks can be simple and understandable.
- SSH-based setup can be powerful, but the first-run path must make the user
  feel guided rather than dropped into an operations console.

### 4.5 Nastart Should Not Copy Blindly

- Do not make SSH terminal, SFTP, Proxmox, Frp, and download management the v1
  core.
- Do not expose destructive Docker controls early unless the safety model is
  mature.
- Do not build many shallow modules to look comprehensive.
- Do not make Agent mandatory for the Synology-first experience if DSM API plus
  app-side probing can provide a useful first result.

### 4.6 Nastart Opportunities Against MyServers

Nastart can be more differentiated if it is:

- More approachable for Synology NAS owners who are not server operators.
- More Apple-native and design-led.
- More automatic after DSM login.
- More focused on service launch, access, and lifecycle reminders rather than
  server administration.
- Better at turning raw technical signals into an attractive, usable launchpad.

## 5. Feature-by-Feature Direction

| Area | DS One | MyServers | Nastart Direction |
|---|---|---|---|
| Core identity | NAS media/file tool | Server monitoring/admin tool | Synology-first NAS launchpad and lightweight operations assistant |
| First-run value | Add NAS/media source and play/browse | Add server/Agent and monitor/manage | Connect DSM, discover services, generate launchpad |
| DSM support | Important, media-oriented | NAS is one supported scenario | Primary v1 target and best-supported path |
| Agent | Not the visible center | Core path for richer operations | Optional enhancement, not first-run burden where avoidable |
| Docker | Useful but not main identity | Deep monitoring/management | Discover containers, map ports, show status, avoid risky controls in v1 |
| Media | Strong built-in playback | Secondary | Support Jellyfin/Emby/Navidrome, lightweight preview, external handoff |
| File management | Meaningful feature | Broad management | Lightweight browser/preview only in v1 |
| Monitoring | Helpful but not central | Strong | Status summaries, reachability, certificate, resource health |
| Launchpad | Not primary differentiator | Widgets/status modules | Primary differentiator and paid-quality surface |
| Themes | Useful if present | Not core identity | Three polished launchpad themes in v1 |
| Lifecycle reminders | Not apparent core | Alerts for server health | Domains, VPS, certificates, subscriptions, backups |
| UI risk | Hard to surpass media polish | Risk of dense/admin feel | Calm, native, refined, not over-featured |
| Monetization lesson | Low-price utility/media value | Free limits plus paid unlock | Single Nastart Plus, low-friction pricing |

## 6. Nastart's Product Boundary

### 6.1 Must Be Excellent

These are the areas that define Nastart:

- Synology DSM login and connection confidence.
- Automatic discovery from DSM packages, containers, ports, and app-side
  fingerprints.
- Launchpad generation, editing, grouping, and theme switching.
- Service opening with local/remote/VPN-aware endpoint choice.
- Service reachability and HTTPS/TLS certificate health.
- Domain, VPS, certificate, backup, and subscription reminders.
- iCloud/CloudKit sync for user configuration and launchpad layout.

### 6.2 Must Be Good Enough

These areas should not feel cheap, but they do not need to beat specialist apps
in v1:

- Lightweight NAS file browsing.
- Video/audio/image/text/PDF preview.
- Jellyfin, Emby, Plex, and Navidrome service entry.
- External player handoff.
- Basic NAS resource charts.
- Widgets, if included early.

### 6.3 Must Stay Small In V1

These are tempting, but should be constrained:

- SSH terminal.
- Full SFTP/file management.
- Full Docker administration.
- Proxmox management.
- qBittorrent/Transmission/Aria2 management.
- Advanced media scraping.
- Advanced subtitle management.
- Full custom theme designer.

### 6.4 Must Not Do In V1

- Destructive container/server operations without a mature permission and audit
  model.
- Uploading NAS credentials or private keys to a Nastart-controlled server.
- Promising deep compatibility for NAS platforms we cannot test.
- Shipping many low-quality themes to look feature-rich.

## 7. Launchpad-Specific Differentiation

The launchpad is the area where Nastart must be more ambitious than both
benchmarks.

The launchpad should not be a bookmark grid. It should be a generated, editable,
status-aware surface:

- Services are discovered automatically where possible.
- Cards include meaningful state, not just names and icons.
- Each card has a primary action and secondary actions.
- Cards can represent web apps, media services, DSM packages, containers,
  domains, certificates, and reminders.
- Themes change layout and information density, not just colors.
- The same launchpad model adapts to iPhone, iPad, future macOS, and future
  Apple TV.

Design quality rules:

- Use few themes and polish them deeply.
- Use native Apple interaction patterns first.
- Prefer SF Symbols and generated service icons over mixed icon packs.
- Keep typography and spacing consistent through design tokens.
- Avoid heavy decorative effects that reduce readability.
- Make status visible but quiet.
- Make the default theme good enough that users do not need customization to
  trust the app.

## 8. Product Decisions For V1

| Decision | Result |
|---|---|
| Main competitor reference | DS One for NAS/media polish, MyServers for monitoring/Agent lessons |
| Main differentiation | Auto-generated native launchpad plus lifecycle reminders |
| V1 primary user | Synology DSM user with Docker and self-hosted services |
| V1 automation priority | DSM API -> app-side probing -> optional Agent -> manual correction |
| Media stance | Integrate and hand off, do not become a full player first |
| Operations stance | Monitor and diagnose first, control/destructive actions later |
| Theme stance | 3 excellent launchpad themes, not many skins |
| Paid value | Multiple NAS, advanced discovery, themes, iCloud sync, reminders, diagnostics |
| UI stance | Apple-native, calm, highly consistent, not module-heavy |

## 9. Open Questions Before UI Design

These questions should be answered with sketches and prototypes:

- What is the default launchpad information density on iPhone?
- Should the default card show service status only, or also latency and
  certificate state?
- How prominent should NAS resource metrics be on the launchpad versus a device
  detail page?
- Should media service cards visually differ from utility/service cards?
- How should the app explain Agent enhancement without making setup feel hard?
- Which two or three screenshots best explain Nastart on the App Store?
- How much of MyServers-like monitoring belongs on the home dashboard versus
  inside Device Center?

## 10. Source Notes

This analysis uses public App Store information as a market-facing reference,
plus user-provided screen recordings as product-flow references, not reverse
engineering:

- DS One App Store listing: media, Synology/Emby support, file management,
  iPhone/iPad/Apple TV availability, rating and version notes.
- MyServers App Store listing: SSH/Docker/server monitoring, Agent-like setup
  path, health checks, Docker management, widgets, free/paid limits, rating and
  user-review signals.
- User-provided DS One/MyServers recordings are summarized in
  `docs/research/COMPETITOR_RECORDING_NOTES.md`.

Feature details should be rechecked before final App Store positioning because
competitor listings and app capabilities can change.
