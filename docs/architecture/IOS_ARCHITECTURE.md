# Nastart iOS Architecture

Version: 0.2  
Status: Draft  
Last updated: 2026-07-25

## 1. Purpose

This document defines the initial iOS/iPadOS architecture for Nastart before
creating the Xcode project.

The goal is to keep the first app simple enough to build while preserving
clear extension points for Agent, Cloud, macOS, widgets, monetization, advanced
media playback, and certificate automation later.

## 2. Platform Baseline

- Language: Swift
- UI: SwiftUI
- Minimum deployment target: iOS 16.0 / iPadOS 16.0 for V1
- Future platform baselines: macOS 14.0+, watchOS 9.0+, tvOS 16.0+, and
  visionOS 2.0+ unless reassessed before those platform launches
- Concurrency: Swift Concurrency
- Persistence: repository abstraction over a local store
- Secrets: Keychain
- Networking: URLSession and Network.framework
- Logging: OSLog with privacy annotations
- Purchases: StoreKit 2 when monetization is implemented
- Widgets: WidgetKit later

## 3. Architecture Style

Recommended style:

```text
SwiftUI Views
-> View Models / Presentation State
-> Use Cases
-> Repositories
-> Local Store / Keychain / Network Clients
```

The app should not put network, Keychain, or persistence logic directly inside
SwiftUI views.

## 4. Module Boundaries

### 4.1 App Shell

Responsibilities:

- app lifecycle
- dependency container
- route state
- scene configuration
- feature flags
- global appearance tokens
- stable navigation and system surfaces

The app shell should not be theme-specific. Launchpad themes can change
dashboard presentation, but onboarding, settings, reminders, device detail,
security warnings, and purchase screens should keep one coherent Nastart style.

### 4.2 Device Center

Responsibilities:

- NAS/device profiles
- provider type
- endpoint configuration
- reachability state
- connection warnings
- Synology-first connection flow
- DSM API client as the primary v1 path
- Agent pairing as the enhanced and future compatibility path
- manual fallback for corrections and unsupported services

Device connection modes:

- `dsmOnly`: Synology DSM session is valid, Agent is not paired or not online.
- `dsmWithAgent`: Synology DSM session is valid and Agent capability handshake is
  fresh.
- `agentOnly`: Agent is paired without a DSM provider session. This supports
  future non-Synology hosts and early experimental compatibility.
- `manualOnly`: user-created service endpoints without a managed NAS provider.

The app should determine mode from repository state, not from UI assumptions:

- valid provider account/session
- paired Agent token in Keychain
- latest Agent heartbeat
- Agent API version compatibility
- reported capability flags
- data freshness timestamp

Provider identity and Agent identity should be linked but not collapsed into one
record. A Synology device can have both DSM identity and Agent identity.

Agent must be treated as a data source that affects multiple feature modules,
not as a single settings feature. Adding Agent can change:

- Launchpad card depth and generated services.
- Device Detail metrics, Docker/container sections, and diagnostics.
- Tasks related to stale data, permissions, and discovery conflicts.
- Security screens for Agent token, certificate, and local API trust.
- Settings for pairing, unpairing, support logs, and experimental compatibility.

The UI should subscribe to normalized repository state instead of calling Agent
directly from views. This keeps DSM-only, DSM+Agent, Agent-only, and manual-only
hosts using the same screen structure with different available sections.

### 4.3 Launchpad

Responsibilities:

- service cards
- categories
- card layout
- card status
- quick actions
- built-in theme selection
- platform-adaptive card presentation
- generated service cards from DSM API, app-side probing, and Agent discovery
- manual service cards only as fallback

Launchpad should render service cards from a normalized `ServiceCardModel`.
Discovery source only changes available fields and confidence:

- DSM/package/probe data can create useful basic cards.
- Agent data can enrich cards with container, port, metric, and diagnostic
  fields.
- Manual data can fill gaps or create unsupported services.

Card identity must remain stable when Agent is added later. Adding Agent should
enrich existing cards, not rebuild the user's Launchpad from scratch.

The launchpad UI should be token-driven so the same card model can render as a
classic iOS-style surface on older systems and as a Liquid Glass-style surface
on iOS/iPadOS/macOS/tvOS 26+ where supported.

Launchpad theme tokens should be scoped to launchpad surfaces. They should not
override global app typography, navigation, warning, settings, or purchase
patterns.

### 4.4 Browser Router

Responsibilities:

- choose local/remote endpoint
- open in app or Safari
- handle HTTP and certificate warnings
- isolate WebView state by service where possible

### 4.5 External App Handoff

Responsibilities:

- detect whether a service or endpoint can be opened by an external app
- maintain known app integration metadata
- check whether a target app can be opened
- build documented URL scheme, universal link, or share-sheet payloads
- provide fallback actions when an app is unavailable
- avoid storing app-specific secrets outside Keychain

### 4.6 Media

Responsibilities:

- media service connection state
- Jellyfin, Emby, Navidrome, and similar library providers
- DSM/WebDAV/Agent-backed media roots
- media resource browsing
- resource detail metadata
- bridge from service card to media library surface

V1 can keep browsing and playback intentionally small, but the media module
should not bind UI directly to a single service API.

### 4.7 Playback

Responsibilities:

- route media resources to system playback, external apps, or future advanced
  playback engines
- expose a stable playback session model
- preserve room for subtitles, audio tracks, quality selection, progress sync,
  and advanced video engine integration

V1 implementations:

- `SystemAVPlaybackEngine`
- `ExternalPlayerEngine`

Future implementations:

- `AdvancedVideoPlaybackEngine`
- `AdvancedAudioPlaybackEngine`

### 4.8 Health

Responsibilities:

- manual reachability checks
- last checked timestamps
- simple warnings
- DSM-backed status adapters
- Agent metric adapters for richer or unavailable data

### 4.9 Tasks

Responsibilities:

- domains
- certificates
- subscriptions
- VPS renewals
- backup freshness reminders
- service warnings
- container warnings
- discovery review tasks
- diagnostic suggestions
- local notifications

### 4.10 Security

Responsibilities:

- Keychain wrapper
- certificate trust decisions
- sensitive log redaction
- local encryption helpers if needed
- certificate trust decisions
- future HTTPS/TLS automation boundaries

### 4.11 Settings

Responsibilities:

- privacy/support links
- export/import later
- appearance preferences
- launchpad theme picker and preview
- browser preferences
- notification preferences
- debug diagnostics in development builds

## 5. Suggested Xcode Structure

```text
Nastart/
  App/
  Core/
    Models/
    Persistence/
    Security/
    Networking/
    Diagnostics/
  Features/
    Onboarding/
    DeviceCenter/
    Launchpad/
    BrowserRouter/
    ExternalAppHandoff/
    Media/
    Playback/
    Health/
    Tasks/
    Settings/
  DesignSystem/
  Resources/
  Tests/
```

If the project later expands to macOS, shared domain logic should move into a
Swift package such as `NastartCore`.

## 6. Dependency Direction

Allowed:

- Features depend on Core and DesignSystem.
- Use cases depend on repositories by protocol.
- Repositories depend on concrete storage or networking clients.

Not allowed:

- Core depending on SwiftUI views.
- Repositories calling UI APIs.
- Feature modules reading Keychain directly.
- Browser code storing secrets in plain local storage.

## 7. Persistence Strategy

The MVP should use a repository abstraction even if the first store is simple.

Domain code should talk to:

- `DeviceRepository`
- `ServiceRepository`
- `ReminderRepository`
- `StatusRepository`
- `SettingsRepository`

This keeps room for SwiftData, SQLite, file-backed JSON during prototyping, or
encrypted export/import later.

## 8. Keychain Strategy

Keychain must store:

- NAS passwords
- API tokens
- Agent pairing tokens
- certificate trust fingerprints if sensitive
- Cloud encryption material later

Local database may store:

- display names
- provider type
- service card layout
- non-secret URLs
- reminder metadata

Sensitive URLs containing tokens should be treated as secrets.

## 9. Networking Strategy

Networking should be split into:

- `ReachabilityClient`
- `HTTPProbeClient`
- `CertificateClient`
- `ProviderClient`
- `AgentClient`

The first provider implementation should prioritize Synology DSM. Other NAS
families should be represented through provider protocols and Agent extension
points, but deep non-Synology support is not a v1 requirement.

Agent-backed hosts should be treated as Docker-capable systems rather than as
fully supported vendor providers. This reserves a future path for QNAP, Unraid,
TrueNAS SCALE, ZimaOS, CasaOS, and generic Linux without implying that
non-Synology behavior is complete in v1.

The first version should avoid global App Transport Security exceptions.
Exceptions should be narrow, explicit, and documented.

## 10. Browser Strategy

The built-in browser is a private service viewer, not a public browser.

Rules:

- No public search field.
- No general-purpose address bar in MVP.
- User opens known service entries only.
- HTTP and invalid certificate states must be visible.
- Safari opening should always be available.
- Do not inject Nastart credentials into arbitrary web pages.

## 11. External App Handoff Strategy

Nastart should support opening NAS resources in third-party apps without
becoming a video player, audio player, general file manager, terminal, or remote
desktop client itself.

Handoff should be triggered from two product surfaces:

- service cards and service detail pages for apps such as Jellyfin, Emby, Plex,
  Navidrome, Audio Station, Video Station, and similar media services
- lightweight media resource pages where users browse confirmed DSM shared
  folders, WebDAV/HTTP endpoints, or supported service library endpoints

Supported launch mechanisms, in order:

1. Documented URL schemes or x-callback-url.
2. Universal links when provided by the target app.
3. iOS share sheet or document interaction/open-in fallback.
4. Copy playable URL.

The app should keep a versioned registry for known external apps:

- display name
- bundle identifier if available
- URL scheme candidates
- supported endpoint types
- supported platforms
- App Store URL
- integration confidence: documented, observed, or user-configured
- handoff category

The first registry should include:

- video: Infuse, VidHub, Lenna, VLC, Fileball, nPlayer, SenPlayer, zFuse,
  NetEase Popcorn, DS video
- audio: Stream Music / 音流, Finamp, Amperfy, play:Sub, Evermusic, Flacbox,
  foobar2000, VLC, Plexamp, DS audio
- files/readers: Documents, FileBrowser, FE File Explorer, Owlfiles, YACReader,
  Panels, Chunky, PDF Expert
- remote/service clients: Termius, Blink Shell, ShellFish, Jump Desktop,
  Microsoft Remote Desktop, Home Assistant, Jellyfin, Emby, Plex, Immich

The implementation must use `canOpenURL` responsibly and include only needed
schemes in `LSApplicationQueriesSchemes`. User-configured custom schemes should
be supported for advanced users.

Remote access clients should be treated as handoff targets only in v1. Nastart
should not collect SSH, RDP, or VNC credentials for those apps unless a separate
security design is approved.

## 12. Lightweight Media Resource Browser

V1 should include a focused media resource browser so Nastart can locate media
files and hand them off to specialist apps.

The browser should support:

- DSM shared-folder browsing for user-selected media roots
- optional WebDAV/HTTP endpoint browsing when the user has configured it safely
- supported service/library endpoints where a playable or shareable URL can be
  produced
- common video and audio extension detection
- folder navigation, file detail, copy/share, and external app handoff

The browser should not support:

- in-app media playback
- media scraping, posters, subtitle management, or watch-progress sync
- upload, delete, rename, move, or batch file operations
- arbitrary SFTP/SMB file-management UX in v1

Data access order:

1. DSM API for Synology shared-folder enumeration and file metadata.
2. App-side endpoint probing when DSM provides a usable HTTP/WebDAV endpoint.
3. Optional Agent for path discovery, URL generation, and richer permission
   checks when DSM API is incomplete.
4. Manual confirmation only when automation cannot safely identify a media root.

## 13. Platform-Adaptive Layout

The launchpad should be designed once as a responsive component system, then
adapted per platform.

Required for v1:

- iPhone compact grid
- iPad wide grid and split-view friendly layout
- theme tokens that support classic and Liquid presentation branches

Prepared for later:

- macOS resizable windows, pointer states, and keyboard shortcuts
- Apple TV read-only status-wall layout with focus-friendly cards

## 14. iPad Adaptation

iPad should not be a scaled iPhone layout.

Recommended layout:

- sidebar for NAS/device selection
- main launchpad grid
- detail inspector for service/status/reminders
- split view for settings and detail screens

## 15. Background Work

MVP should be conservative:

- manual refresh first, with automatic checks on user-triggered discovery
- local notifications for reminders
- limited background checks only if reliable and review-safe

Continuous monitoring should wait for Agent and stronger product validation.

## 16. Agent Integration Placeholder

The iOS app should define Agent-facing protocols in v1:

- pair Agent
- list services
- list containers
- read metrics
- check certificates
- run diagnostics
- perform capability handshake
- report heartbeat and data freshness
- identify host/provider hints without requiring a brand-specific UI path

V1 should support Agent pairing as the enhanced path for Docker discovery and
richer monitoring when DSM API is incomplete. Agent remains optional for
Synology onboarding, but it should be available in the first meaningful
TestFlight so pairing, permissions, discovery merging, and stale-data behavior
can be tested early.

The first tested Agent target is Synology DSM. Other Docker-capable systems can
use the same Agent protocol behind an experimental compatibility label until
those platforms receive dedicated testing.

## 17. Sync and Cloud Integration

V1 should support local-first storage and prepare for iCloud/CloudKit sync.
CloudKit should be wrapped behind a sync abstraction so future Nastart Cloud can
be added without rewriting feature modules.

Prepare for:

- iCloud/CloudKit private database sync
- account identity
- encrypted sync
- push notifications
- entitlement validation
- cloud backup

Do not couple local feature access to Cloud identity. Do not sync plaintext DSM
passwords, DSM tokens, Agent tokens, private keys, or secret-bearing URLs.

## 18. Testing Strategy

Minimum:

- domain model tests
- endpoint selection tests
- reminder date calculation tests
- Keychain wrapper integration tests where practical
- HTTP/certificate probe tests with mocked clients

UI testing should focus on onboarding, adding a service, opening a service, and
editing reminders.

## 19. Architecture Open Questions

- SwiftData versus SQLite versus file-backed prototype store.
- Whether WebKit cookies should be shared globally or isolated per service.
- Whether certificate fingerprint storage belongs in Keychain or local database.
- How early StoreKit 2 should be added.
- Whether Agent protocol definitions should live in a cross-platform package.
- Which external app URL schemes are stable enough to enable by default.
