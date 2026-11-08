# Nastart Information Architecture

2026-10-26用户最新规则：Plus并入三端“设置”组；TV固定六项等大三列两行。TV启动台默认显示全部Docker（可手动隐藏），不展示套件，分类与设备→容器目录及手机共享规则一致；套件入口留设备资源组。TV Docker 服务及管理显示最终改为双列等大卡，奇数末张靠左；分组标题整行，暖色焦点不使用覆盖名称的系统白条。存储入口仍保持“浏览文件/已有库/添加目录”，连接表单分HTTP/HTTPS、地址、端口和路径，发现线索不等于已有授权。具体实施与未接能力见[当前批](../archive/handoffs/2026-10/2026-10-26-CROSS-PLATFORM-CARD-RULES-WEBDAV.md)。

2026-10-26最新补充：存储与媒体与NAS概览是同级功能卡片，移动三种布局已从DeviceSummaryPanel移出，iPad共用；TV原为同级行。内部浏览文件/已有媒体库/添加目录与次级连接管理保持。 见[最新批](../archive/handoffs/2026-10/2026-10-26-INDEPENDENT-STORAGE-CARD-AND-ACCENT.md)。

2026-10-26用户要求减少重复：NAS摘要的设备文件/影音媒体库并列快捷入口合并为存储与媒体；该页直接给浏览文件、已连接媒体库和添加媒体文件夹。连接管理才展示协议与服务目录；原四主Tab保持。实际实现/边界见[本批](../archive/handoffs/2026-10/2026-10-26-UNIFIED-MEDIA-HOME-AND-TV-UI.md)。

2026-10-26接续：“媒体服务”分组/服务详情已放入现有“存储与媒体”，仍为四主Tab；NAS文件夹入口不等待可选服务探测。当前NAS的发现线索与独立已存Jellyfin连接分别标名，不能凭同主机名推断归属。当前原生目的页只接现有Jellyfin，其他产品状态与后续范围见[服务批](../archive/handoffs/2026-10/2026-10-26-MEDIA-SERVICE-DISCOVERY-AND-ENTRY.md)。

2026-10-26：三端原网络媒体入口改“存储与媒体”，保留四主Tab；当前NAS/已有媒体库/已有连接与手动WebDAV入口已实接，媒体服务统一分组/能力状态尚未实接。见[本批](../archive/handoffs/2026-10/2026-10-26-NAS-SESSION-SOURCE-HUB-NATIVE.md)。

2026-10-26接入补充：四主Tab保持，“存储与媒体”在NAS摘要/已有来源下承接文件夹与媒体服务，默认先当前NAS与已有授权，手动地址放新增/高级流程。详[统一来源方案](../architecture/UNIFIED_SOURCE_DISCOVERY_AND_ACCESS.md)；此轮仅设计与交互预览，尚未修改App。

Version: 0.3
Status: Draft
Last updated: 2026-07-27

## 1. Purpose

This document defines Nastart's first information architecture across iPhone
and iPad.

The design goal is a calm native Apple experience for Synology DSM and HomeLab
users. Nastart should make services easy to launch, status easy to understand,
and action items hard to miss, without turning into a dense mobile server
console.

Visual style rules are defined in `docs/design/UI_STYLE_GUIDE.md`.

Media-specific Jellyfin, Emby, Navidrome, resource browsing, and external
handoff flows are defined in `docs/design/MEDIA_SERVICE_FLOWS.md`.

## 2. IA Principles

- Start from the user's services, not from infrastructure jargon.
- Make automatic Synology DSM setup the main path; keep manual setup as a
  fallback.
- Keep Agent useful but optional in the first-run experience.
- Keep risky actions out of first-level UI.
- Separate launching, device management, action items, and settings.
- Keep iPhone compact and iPad spacious.
- Avoid turning the app into a generic admin console.
- Keep the app shell visually stable; theme changes mainly affect the Launchpad
  Dashboard surface and service cards.
- Follow the product motto: simple, but not simplistic.
- Keep every top-level tab clean enough to understand at a glance.
- Put advanced configuration, dense metrics, playback settings, transfers,
  credentials, and diagnostics one level deeper.

Top-level tab rule:

```text
Top page = scan and act.
Subpage = configure and inspect.
Detail page = explain and diagnose.
```

## 3. Primary Navigation

Recommended v1 tabs:

```text
Launchpad / 启动台
Devices / 设备
Tasks / 事项
Mine / 我的
```

Rationale:

- Launchpad is the product's main differentiator and should be the first tab.
- Devices contains Synology DSM connection, NAS health, endpoints, and Agent.
- The user-facing third tab label should be `事项`. Internally, the feature can
  still use a `Tasks` domain model.
- Tasks contains everything that needs user attention: certificate/domain/VPS
  renewal, backup freshness, service downtime, container anomalies, discovery
  review, diagnostics, and custom reminders.
- Mine contains profile, Plus, settings, appearance, privacy, support, and
  developer/app information.

This four-tab structure is the recommended v1 direction. It is compact enough
for a simple app shell, but still gives the product's major jobs clear places to
live.

## 3.1 Competitor-Informed Tab Decision

DS One and MyServers should influence grouping, not dictate Nastart's tabs.

Public App Store information suggests DS One is organized around NAS media,
music, video, and file-management value, while MyServers is organized around
server monitoring, SSH, Docker, Agent-style setup, widgets, and operations.
Nastart overlaps with both, but its main user journey is different.

| Possible Tab | Inspired By | Decision | Reason |
|---|---|---|---|
| Media | DS One | Do not use as v1 top-level tab | Media is important, but it should start from service cards such as Jellyfin, Emby, Plex, and Navidrome |
| Files | DS One | Do not use as v1 top-level tab | Lightweight file preview is a helper workflow, not the product identity |
| Servers | MyServers | Use `Devices` instead | `Devices` feels more NAS-friendly and less operations-heavy |
| Monitor / Health | MyServers | Do not use as v1 top-level tab | Health should surface in Launchpad and Device Detail first |
| Apps / Services | Both | Use `Launchpad` instead | Launchpad communicates service opening plus layout/design value |
| Tasks | Nastart-specific | Keep as top-level tab | Lifecycle reminders alone are too narrow; an action center can absorb renewals, warnings, diagnostics, and future Agent events |
| Mine / Settings | Common app pattern | Keep as top-level tab | Plus, theme, sync, external apps, privacy, and support need a stable place |

V1 should avoid five or six tabs. If a future version needs deeper monitoring,
media, or automation, add it only after real usage shows that users cannot find
those workflows under the current four-tab model.

User-provided screenshots reinforce this decision:

- DS One's Video, Audio, and Album tabs fit its media-first product identity,
  but Nastart should keep those as service-card/resource workflows.
- MyServers' Dashboard, Board, Server, Terminal, and Settings tabs fit a
  server-operations product, but Nastart should avoid exposing Terminal or
  server administration as first-level identity in v1.
- Nastart's first tab should communicate "my NAS services are ready to launch",
  not "choose a module from a large toolkit".

## 3.2 Simplicity Rules

The app has many small capabilities, but the interface should expose them
progressively:

- First-level tabs answer "where do I go?"
- First-level pages show objects and state, not documentation.
- Cards show only the next useful action.
- Details pages carry secondary information.
- Sheets carry decisions.
- Settings carries preferences.
- Empty states carry one action, not a tutorial.

Default visible complexity should be low:

- Launchpad: service cards and warnings.
- Devices: NAS cards and health summary.
- Tasks: due items, warnings, and pending decisions.
- Mine: account, Plus, appearance, external apps, privacy, support.

Everything else should be one tap deeper.

Not recommended as v1 tabs:

- Media: media should appear through service cards and resource browser, not a
  separate first-level product identity.
- Files: lightweight browsing exists only as a helper workflow.
- Health: health is important, but should live in Launchpad summaries and
  Device detail before becoming its own tab.
- Automation: ACME and scripts are future work.

## 3.3 Confirmed V1 IA Decisions

The following decisions are confirmed before low-fidelity UI design:

- The third tab user-facing name is `事项`.
- Launchpad default card density should start with two-column medium cards,
  with warning or abnormal services automatically promoted visually.
- Launchpad groups should not be all collapsed or all expanded by default.
  Favorites, general services, and media library groups should start expanded;
  lower-frequency groups can start collapsed. User collapse state should be
  remembered.
- The DSM service card is a system-level card. A normal tap opens the related
  Device Detail page. Long press exposes DSM Web UI, file browsing, official
  Synology app handoff where verifiable, diagnostics, and card editing.
- Media v1 should target option C: library/resource browsing, basic system
  playback, and external app handoff. It should not include a full custom
  DS One/Lenna-class playback engine in v1.
- Device file browsing should show favorites, recents, common shared folders,
  and a "view all" entry first; full shared-folder browsing appears one level
  deeper.
- Demo mode should exist for onboarding, TestFlight, and App Store review.
- Custom Launchpad background images should not be a v1 requirement. V1 can
  use default surfaces, built-in background modes, or simple readability
  treatments only.
- Upload/download management should be deferred beyond v1. V1 can reserve
  settings and architecture for cache and future transfer behavior.
- Low-fidelity design must include critical subpages and hidden actions, not
  only the four top-level tabs.

## 4. Global App Structure

### 4.1 iPhone Shell

```text
TabView
├─ Launchpad
├─ Devices
├─ Tasks
└─ Mine
```

Use native navigation stacks within each tab.

### 4.2 iPad Shell

```text
NavigationSplitView
├─ Sidebar
│  ├─ Launchpad
│  ├─ Devices
│  ├─ Tasks
│  └─ Mine / Settings
└─ Content + optional detail/inspector
```

iPad should not be a stretched iPhone layout. The Launchpad can show wider
grids and a side status panel. Devices can show list and detail side by side.

## 5. Tab 1: Launchpad

### 5.1 Purpose

The Launchpad is Nastart's home surface:

- open NAS services quickly
- scan service status
- switch between local and remote access
- see urgent certificate/domain/subscription warnings
- hand off media resources to external apps
- express the user's chosen theme

### 5.2 First-Level Content

Recommended default structure:

```text
Header
├─ Current NAS / workspace selector
├─ Search
├─ Refresh/status check
└─ Theme quick preview or settings entry

Status Summary
├─ NAS reachable
├─ service warnings
├─ certificate/domain reminders
└─ optional resource snapshot

Service Sections
├─ Favorites
├─ Media
├─ Downloads
├─ Smart Home
├─ Network
├─ Tools
└─ Custom categories
```

The section names are user-editable later. V1 can ship with automatic categories
plus manual correction.

### 5.3 Required Functions

- Display generated service cards.
- Search services.
- Filter by category or status.
- Refresh status.
- Open service using best endpoint.
- Long press card for secondary actions.
- Edit service card.
- Reorder favorites.
- Switch Launchpad theme through Settings or a lightweight preview entry.

### 5.4 Card Data Depth

Launchpad card identity and actions should remain stable across connection
methods. Data depth can increase when richer sources are available.

Card source states:

| Source State | Typical User Path | Launchpad Behavior |
|---|---|---|
| DSM-only | Synology DSM connected, no Agent | Show services discovered from DSM packages, Container Manager data where available, app-side probes, endpoint health, and certificate status |
| DSM + Agent | Synology DSM connected and Agent paired | Keep the same cards, then enrich them with more reliable Docker/container/package/port/metric data |
| Agent-only | Non-Synology or unsupported NAS with Agent | Generate cards from Agent-reported Docker/services/ports/metrics and mark the device as Agent-backed |
| Manual-only | User adds a URL or service manually | Show basic reachability, certificate, favicon/title, and user-provided metadata |

Card capability levels:

- `basic`: name, URL, icon, category, favorite state.
- `reachable`: status, latency, last checked time, TLS state.
- `serviceAware`: detected service type, favicon/title, endpoint variants.
- `containerAware`: related container, image, exposed ports, container state.
- `metricAware`: CPU, memory, network, storage, temperature where available.
- `mediaAware`: library counts, recent items, playback/handoff actions where
  supported by the media provider.

The UI should not visibly punish users who do not install Agent. Agent should
feel like an optional upgrade in precision and automation, not a mandatory
gate before the Launchpad becomes useful.

### 5.5 Service Card Primary Action

```text
Tap service card
-> choose best endpoint
-> open in in-app browser / Safari / external app according to service rules
```

Endpoint choice priority:

1. Local URL if reachable.
2. VPN URL if configured and available.
3. Remote URL if local is unavailable.
4. Show unreachable sheet with diagnose/edit options.

### 5.6 Service Card Secondary Actions

Use long press or an overflow menu:

- Open in Safari.
- Open with external app.
- Copy URL.
- Check status.
- View details.
- Edit card.
- Hide from Launchpad.

Do not show too many visible buttons on compact cards.

### 5.7 Launchpad Subpages

| Page | Purpose | Entry |
|---|---|---|
| Service Detail | Show endpoints, status, certificate, related container/package, handoff options | Tap card detail / long press |
| Add/Edit Service | Manual correction and fallback entry | Add service / edit card |
| Search | Search cards, services, reminders, and known categories | Search field |
| Category Editor | Rename/reorder groups | Manage categories |
| Theme Preview | Preview and apply Launchpad themes | Theme entry / Settings |
| Media Resource Browser | Browse configured media roots and hand off files | Media service detail |
| Endpoint Warning Sheet | Explain HTTP, invalid certificate, expired cert, or unreachable endpoint | Opening risky service |
| Open In Sheet | Choose external app, share sheet, copy URL, or App Store fallback | Secondary action |

Detailed media service behavior is intentionally kept in
`docs/design/MEDIA_SERVICE_FLOWS.md` so this IA document remains readable.

## 6. Tab 2: Devices

### 6.1 Purpose

Devices is where users connect, inspect, and maintain NAS/hosts.

It should answer:

- Is my NAS reachable?
- What DSM/device is connected?
- What resources are healthy or warning?
- Is Agent connected?
- Which services came from this device?

### 6.2 First-Level Content

```text
Device List
├─ Primary Synology DSM device
├─ additional NAS / hosts
├─ add device
└─ connection warnings
```

If only one NAS exists, Devices can still show the device card plus quick status
instead of an empty-feeling list.

### 6.3 Required Functions

- Add Synology DSM device.
- Add generic/manual host.
- Show reachability.
- Show basic DSM identity and version.
- Show CPU, memory, storage, network, and temperature where available.
- Show discovered packages, containers, and services.
- Manage local/remote/VPN endpoints.
- Show Agent status and setup path.
- Re-run discovery.

### 6.4 Connection Mode Impact

The Devices tab must adapt to the same connection modes used by Launchpad. It
should not assume every device has DSM-level data.

| Mode | Device Tab Behavior | Launchpad Impact |
|---|---|---|
| DSM-only | Show DSM identity, DSM version, storage, packages, available Docker data, certificates, and probes | Useful service cards with DSM/probe confidence |
| DSM + Agent | Show DSM identity plus Agent health, richer host metrics, Docker details, port mappings, and permission scope | Same cards become richer; do not duplicate cards |
| Agent-only | Show host identity, Agent health, Docker/services/metrics reported by Agent, and experimental compatibility label | Generate Agent-backed cards with capability-based display |
| Manual-only | Show user-entered endpoints and probe results only | Basic manual service cards |

When a richer source disappears, the UI should degrade gracefully:

- keep user-confirmed cards visible
- show stale indicators only where useful
- hide missing deep metrics instead of leaving broken placeholders
- create a task when the user needs to reconnect, review permissions, or merge
  duplicate discoveries

### 6.5 Device Subpages

| Page | Purpose | Entry |
|---|---|---|
| Add Device | Choose Synology DSM, Agent, or manual host | Add button |
| Synology Login | DSM URL, account, 2FA if needed, connection security | Add Synology DSM |
| Discovery Review | Confirm, hide, or edit discovered services | After successful login / rescan |
| Device Detail | Health summary, endpoints, services, packages, containers | Device card |
| Resource Detail | CPU/memory/storage/network/disk/temperature details | Device detail |
| Containers | Container list, ports, status, linked service card | Device detail |
| Package List | DSM package list and linked cards | Device detail |
| Endpoint Settings | Local, remote, VPN, reverse proxy paths | Device detail |
| Certificate Detail | Certificate status, fingerprint, expiry, change history | Device detail / service detail |
| Agent Setup | Docker command/compose guide, pairing, permissions | Device detail |
| Security & Credentials | Keychain state, certificate trust, reconnect, logout | Device detail |

### 6.6 Device Detail Information Density

Device Detail can be denser than Launchpad, but still should avoid admin-panel
overload.

Recommended sections:

- Summary.
- Health.
- Services.
- Containers.
- Certificates.
- Endpoints.
- Agent.
- Security.

Charts and metrics should be tappable for detail; do not place every metric on
the first screen.

## 7. Tab 3: Tasks

### 7.1 Purpose

Tasks is Nastart's action center. It prevents users from missing
NAS-adjacent lifecycle events and gives them one place to handle warnings,
pending setup decisions, and future Agent-discovered issues.

It includes:

- domain renewal
- HTTPS/TLS certificate expiry
- VPS renewal
- paid service subscription
- backup freshness
- storage threshold
- service unreachable warnings
- container stopped or unhealthy warnings
- new discovered services waiting for review
- diagnostic suggestions
- Agent setup or permission issues
- custom reminder

### 7.2 First-Level Content

```text
Task Center
├─ Due soon
├─ Service warnings
├─ Discovery review
├─ Diagnostics
├─ Domains
├─ Certificates
├─ VPS / servers
├─ Subscriptions
├─ Backups
└─ Custom
```

### 7.3 Required Functions

- Add manual reminder.
- Edit reminder or task metadata.
- Complete, ignore, postpone, or archive task.
- Attach reminder to device/service/domain.
- Local notifications.
- Sync reminder metadata through iCloud/CloudKit when Plus is enabled.
- Show critical tasks in Launchpad status summary.
- Convert an auto-detected warning into a reminder when useful.

### 7.4 Task Subpages

| Page | Purpose | Entry |
|---|---|---|
| Add Reminder | Select type and create reminder | Add button |
| Task Detail | Due date, warning reason, related item, suggested action | Task card |
| Warning Detail | Service/container/certificate issue and next action | Warning card |
| Discovery Review | Confirm, hide, rename, or group newly discovered service | Discovery task |
| Diagnostic Suggestion | Suggested check or fix for endpoint, DNS, TLS, or Agent | Diagnostic task |
| Domain Reminder | Domain registrar, expiry date, renew URL | Add/edit |
| Certificate Reminder | Cert source, expiry, fingerprint, service/domain link | Add/edit or auto-detected cert |
| VPS Reminder | Provider, plan, expiry, renew URL | Add/edit |
| Subscription Reminder | Service, billing period, renew/ignore behavior | Add/edit |
| Backup Reminder | Backup task, freshness window, device link | Add/edit |
| Notification Settings | Alert timing and permission state | Reminder settings |
| Archive | Completed/expired reminders | Filter |

### 7.5 Task UX Rule

Task screens should use short labels and options, not long forms.

Use segmented controls, date pickers, renewal-cycle presets, and URL fields only
when needed.

Tasks should not become a notification log. Each visible item should imply a
clear decision:

- open related service
- review discovered item
- renew or mark renewed
- diagnose
- ignore
- postpone
- archive

## 8. Tab 4: Mine

### 8.1 Purpose

Mine contains user-level state and app-level configuration.

It should not become a dumping ground. Frequently used operational tasks belong
in Launchpad, Devices, or Tasks.

Mine should feel like a quiet control panel. It can contain many settings, but
the first level should stay short and grouped. Advanced playback, transfer, and
cache settings should live one level deeper rather than making the Mine page
look like a technical checklist.

### 8.2 First-Level Content

```text
Profile Header
├─ local/iCloud user display
├─ sync state
└─ Plus state

Compact Entitlement Row
└─ Nastart Plus

Primary Rows
├─ Launchpad
├─ Preferences
├─ Data & Security
└─ Help & About
```

### 8.3 Required Functions

- Manage Nastart Plus.
- Switch Launchpad theme.
- Configure external app defaults.
- Configure browser/opening behavior.
- Configure future player behavior.
- Configure future upload/download and cache behavior.
- Configure notifications.
- View iCloud sync status.
- Export/import later.
- Privacy and security review.
- Support and feedback.
- App version and legal links.

### 8.4 First-Level Layout

Recommended iPhone structure:

```text
Mine
├─ Account / Sync Header
│  ├─ display name or local profile
│  ├─ iCloud sync state
│  └─ Plus state
├─ Compact Plus row
├─ Launchpad
├─ Preferences
├─ Data & Security
└─ Help & About
```

The page should avoid large promotional panels unless the user is already
trying to unlock a Plus feature. A compact Plus row is usually enough.

This keeps the Mine page visually quiet. Most configuration depth belongs in
the second level.

### 8.5 Mine Subpages

| Page | Purpose | Entry |
|---|---|---|
| Profile | Display name/avatar if needed, iCloud status | Profile header |
| Nastart Plus | Pricing, restore purchases, feature comparison | Plus row / paywall |
| Launchpad | Theme, layout, background, card display, and dashboard behavior | Launchpad row |
| Launchpad Theme | Preview, compare, apply themes | Launchpad |
| Launchpad Layout | Card size, density, group collapse behavior, device summary visibility | Launchpad |
| Launchpad Background | Default surfaces, built-in background modes, readability treatment | Launchpad |
| Card Display Items | Show/hide status, endpoint, latency, certificate, widget summaries | Launchpad |
| Preferences | Browser, players, external apps, transfers, cache, and notifications | Preferences row |
| Browser & Opening | In-app browser/Safari, endpoint preference, warning behavior | Preferences |
| Video Player | Default playback engine, external video apps, subtitle/audio-track defaults later | Preferences |
| Audio Player | Default audio behavior, queue/background/lock-screen options later | Preferences |
| External Apps | Known app integrations and custom URL schemes | Preferences |
| Transfers & Cache | Upload/download defaults, transfer queue preferences, cache controls | Preferences |
| Notifications | Reminder, task, health, certificate, and Agent alert permissions | Preferences |
| Data & Security | iCloud sync, local data, credentials, privacy, and certificate trust | Data & Security row |
| Sync & Data | iCloud sync state, local data, export/import later | Data & Security |
| Privacy & Security | Keychain, CloudKit sync boundaries, certificates, Face ID, logout | Data & Security |
| Help & About | Help, feedback, diagnostics export, legal, version, acknowledgements | Help & About row |
| Support | FAQ, contact, diagnostics export later | Help & About |
| About | Version, privacy policy, terms, acknowledgements | Help & About |

### 8.6 Subpage Detail Intent

`Launchpad`:

- theme
- card size and density presets
- group collapse behavior
- top device summary visibility and fields
- built-in background mode
- card display items

Do not include global Tab order here. Launchpad customization is about the
dashboard surface, not rebuilding the entire app navigation.

`Preferences`:

- default browser: in-app browser, Safari, ask every time
- default endpoint preference: auto, local first, remote first, ask
- default video action: system player, external app, ask, web UI
- default audio action: system player, external app, ask, web UI
- external app registry and custom schemes
- future subtitle, audio-track, and quality defaults
- cache size limit
- clear all cache
- clear media artwork cache
- temporary file retention
- future upload/download queue settings
- Wi-Fi/cellular transfer rules later
- background transfer behavior later
- certificate and domain alerts
- service unreachable alerts
- backup freshness alerts
- Agent offline alerts
- quiet hours
- notification permission state

`Data & Security`:

- iCloud/CloudKit sync status
- last sync time
- conflict handling later
- local-only mode
- export/import later
- reset demo data
- Keychain credential list
- Face ID / app lock
- trusted certificate fingerprints
- data stored in iCloud explanation
- disconnect device / delete local credentials
- future Agent permission review

`Help & About`:

- help and FAQ
- feedback
- diagnostics export later
- App Store review link
- version
- privacy policy and terms
- open-source acknowledgements

### 8.7 Module Settings Decision

Nastart should not copy DS One's module settings as a v1 navigation feature.

Do not support adding/removing/reordering top-level tabs in v1 because the
navigation is intentionally small and product-defining:

```text
Launchpad / Devices / Tasks / Mine
```

What Nastart should support instead:

- Launchpad sections and service-card visibility.
- Launchpad card size/density/display item settings.
- Hiding advanced rows inside Devices when data is unavailable.
- Future feature flags for development/TestFlight builds.

If a future version adds a major media or transfer center, reassess tab
customization only after real usage proves that fixed navigation no longer
works.

## 9. Onboarding Flow

Recommended first-run path:

```text
Welcome
-> Choose setup path
-> Connect Synology DSM
-> Discover services and status
-> Confirm generated launchpad
-> Choose default Launchpad theme
-> Choose opening behavior
-> Launchpad
```

Setup paths:

- Connect Synology DSM.
- Explore demo launchpad.
- Add service manually.
- Enhance with Agent, shown after DSM connection or when discovery is weak.

The app should not require Agent, Plus, or Cloud during onboarding.

### 9.1 Demo Mode

Demo mode is useful for App Store screenshots, TestFlight, and users without a
NAS at hand.

Demo data should be clearly marked and removable.

## 10. Add Synology DSM Flow

```text
Devices / Onboarding
-> Add Device
-> Synology DSM
-> Enter DSM address
-> Security check
-> Sign in
-> Fetch DSM identity
-> Discover packages/containers/services
-> Discovery Review
-> Generate Launchpad
```

If login fails:

```text
Login failure
-> short error
-> check address / credentials / 2FA / certificate
```

If discovery is incomplete:

```text
Discovery Review
-> show low-confidence candidates
-> suggest optional Agent enhancement
-> allow manual correction
```

## 11. Add Service Flow

Fields:

- service name
- category
- icon
- local URL
- remote URL optional
- opening mode
- related device

Advanced fields hidden behind disclosure:

- certificate trust
- custom URL scheme / external app default
- health check path
- notes

## 12. Open Service Flow

Default:

```text
Tap card
-> choose best endpoint
-> open
```

If risk exists:

```text
Tap card
-> warning sheet
-> continue / cancel / open in Safari / trust certificate
```

If unavailable:

```text
Tap card
-> unavailable sheet
-> try remote / diagnose / edit endpoint / copy URL
```

## 13. External App Handoff Flow

Nastart should not put full playback, full file management, terminal, or remote
desktop features on the main path in v1, but supported service cards and media
resources should expose a small "Open in..." action.

Recommended service-level flow:

```text
Media service card
-> Service Detail
-> Open In
-> default app / compatible app / share sheet / copy URL
```

Recommended resource-level flow:

```text
Media service card
-> Service Detail
-> Media roots
-> folder / file list
-> file preview
-> open with default app / choose app / copy / share
```

Supported first-screen media roots should stay intentionally small:

- Video.
- Music.
- Photos.
- Downloads.
- User-selected shared folder.

This screen should look like a focused picker rather than a general file
manager. Avoid file operations such as rename, move, delete, upload, permission
editing, or batch selection in v1.

## 14. Search Flow

Search should exist in Launchpad first.

Search scope:

- service cards
- categories
- devices
- tasks and reminders
- known service types

Recommended flow:

```text
Launchpad search
-> type service/category/domain
-> result list
-> tap to open / long press for actions
```

Do not provide public web search in v1.

## 15. Notifications Flow

Notification types:

- reminder due soon
- certificate expiring
- certificate changed
- service unreachable, if user enabled
- Agent offline, if user enabled

Flow:

```text
Task, reminder, or warning
-> notification
-> relevant detail page
-> renew / postpone / diagnose / mark done
```

## 16. Plus Upgrade Flow

Plus should appear where users hit a natural limit:

- more than one NAS
- more than free card limit
- advanced discovery or Agent convenience features
- all built-in themes
- iCloud sync
- advanced reminder rules
- widgets and diagnostics

Flow:

```text
Locked feature
-> compact Plus sheet
-> compare benefits
-> choose monthly / annual / lifetime
-> purchase / restore
```

Do not block basic local discovery so early that users cannot understand the
product value.

## 17. Page Tree Summary

```text
Onboarding
├─ Welcome
├─ Setup path
├─ Synology login
├─ Discovery review
├─ Theme choice
└─ Launchpad

Launchpad
├─ Search
├─ Service detail
│  ├─ Endpoint detail
│  ├─ Certificate detail
│  ├─ Media roots
│  └─ Open In
├─ Add/Edit service
├─ Category editor
└─ Theme preview

Devices
├─ Add device
│  ├─ Synology login
│  ├─ Manual host
│  └─ Agent setup
├─ Device detail
│  ├─ Resource detail
│  ├─ Containers
│  ├─ Packages
│  ├─ Endpoints
│  ├─ Certificates
│  ├─ Agent
│  └─ Security
└─ Discovery review

Tasks
├─ Add reminder
├─ Task detail
├─ Warning detail
├─ Discovery review
├─ Diagnostic suggestion
├─ Domain
├─ Certificate
├─ VPS
├─ Subscription
├─ Backup
└─ Archive

Mine
├─ Profile
├─ Nastart Plus
├─ Launchpad
│  ├─ Launchpad Theme
│  ├─ Launchpad Layout
│  ├─ Launchpad Background
│  └─ Card Display Items
├─ Preferences
│  ├─ Browser & Opening
│  ├─ Video Player
│  ├─ Audio Player
│  ├─ External Apps
│  ├─ Transfers & Cache
│  └─ Notifications
├─ Data & Security
│  ├─ Sync & Data
│  └─ Privacy & Security
└─ Help & About
   ├─ Support
   └─ About
```

## 18. Empty States

Empty states should be short and action-oriented.

Examples:

- No services yet. Connect Synology DSM to generate your launchpad.
- No tasks yet. Everything that needs attention will appear here.
- Device unavailable. Try remote address or check local network.
- No media roots yet. Add a shared folder or media service.

Avoid long explanatory paragraphs.

## 19. Future-Proof IA Check

The v1 tab structure should support later Nastart versions without forcing a
major navigation rewrite.

Recommended long-term shell:

```text
Launchpad / 启动台
Devices / 设备
Tasks / 事项
Mine / 我的
```

Future capabilities should map into this shell as follows:

| Future Capability | Primary Location | Notes |
|---|---|---|
| Agent setup and pairing | Devices | Per-device enhancement path, not a global tab |
| Agent health and permission warnings | Tasks | Show only when user action is needed |
| Other NAS brands | Devices | Add provider type under Add Device; keep Launchpad service model shared |
| Manual host/server support | Devices | Supported as a provider, not a separate Servers tab in v1 |
| Deep diagnostics | Devices / Tasks | Device Detail carries tools; Tasks carries suggested actions |
| HTTPS/TLS automation | Devices / Tasks | Certificates live with device/service; renewal work appears in Tasks |
| SSH advanced tools | Device Detail | Future advanced action, not a v1 tab |
| Docker controls | Device Detail | Status first; destructive controls require later safety model |
| Media/file enhancements | Service Detail | Start from Jellyfin/Emby/Navidrome or file roots, not a Media tab |
| Download clients | Launchpad service card / Service Detail | qBittorrent/Transmission remain services |
| Widgets | Launchpad / system widgets | Launchpad owns app widgets; iOS widgets can come later |
| Automation rules | Devices / Tasks | Rules create actions or warnings, not a separate v1 Automation tab |
| Multi-user/team features | Mine / Settings | Future account-level configuration |

Do not add a new top-level tab unless a future capability introduces a new
daily user goal that cannot be naturally expressed as launch, device, task, or
settings.

This keeps Nastart extensible without drifting into a module-heavy app.

## 20. App Store And Review Considerations

Because Nastart may include an in-app browser:

- present it as a private service viewer
- do not expose public search
- do not provide a general public address bar in MVP
- include privacy and support links
- explain local-first data handling
- make third-party service and player integrations user-initiated

## 21. IA Open Questions

These should be resolved through low-fidelity prototypes:

- What does the confirmed two-column medium-card Launchpad look like with 6,
  12, and 24 services?
- Does the `事项` page work better as a unified inbox, or as a three-section
  page with pending items, monitored objects, and history?
- Should items and warnings appear as cards on Launchpad, only as a top warning
  strip, or both depending on severity?
- How strong should the media-card visual distinction be while still keeping
  the same service-card family?
- Should Health become a separate tab after Agent matures?
- How prominent should Agent setup be before users see first value?
- Do the proposed free limits feel useful enough while still making Plus
  desirable?
