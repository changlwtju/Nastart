# Nastart Media Service Flows

Version: 0.2
Status: Draft
Last updated: 2026-07-27

## 1. Purpose

This document defines how Nastart should integrate Jellyfin, Emby, Navidrome,
and similar NAS media services without turning the app into a full media player
or a DS One clone.

The goal is to make media services feel like first-class launchpad citizens:
easy to discover, easy to open, easy to browse, able to play common media
through system playback, and easy to hand off to specialist apps.

## 2. Product Decision

Media services should not become a top-level tab in Nastart v1.

Instead, they should live in this structure:

```text
Launchpad
-> Media service card
-> Media Service Detail
-> Library / Media roots
-> Resource detail
-> basic system playback / external app / preview / copy / share
```

This keeps Nastart's identity clear:

- Launchpad first.
- Service access first.
- Media support as a high-quality service workflow.
- Basic playback exists where system frameworks make it practical.
- Full custom playback engine, scraping, subtitle management, and watch
  progress are deferred.

V1 media scope decision:

- Jellyfin and Emby should be treated as first-class v1 media integrations.
- Navidrome/Subsonic-compatible services should be treated as first-class v1
  audio integrations where APIs are reliable.
- Plex can be included in the same product flow if its API/auth feasibility is
  confirmed early; otherwise it should ship as a high-quality web-service card
  first.
- Media cards may have richer artwork/status affordances than ordinary service
  cards, but they must remain part of the same Launchpad card family.
- V1 should attempt all formats supported reliably by system frameworks, then
  fall back to external apps for unsupported containers, codecs, subtitles, or
  advanced playback needs.

## 3. Integration Levels

Nastart should support three levels of media service integration.

### 3.1 Level 0: Web Service Card

This is the minimum integration.

Capabilities:

- service name
- service icon
- local and remote URL
- reachability
- HTTPS/TLS certificate check
- open web UI
- open in Safari
- copy URL

No media library credentials are required.

Use when:

- the service is detected but not connected
- user does not want to provide media credentials
- API is unavailable
- service type confidence is low

### 3.2 Level 1: Library Connection

This is the recommended v1 media integration.

Capabilities:

- authenticate to Jellyfin, Emby, Navidrome, or compatible service
- list libraries or music collections where supported
- show library counts or high-level metadata where available
- browse a shallow media library structure
- create media roots inside Nastart
- choose default external app per service

Use when:

- user wants Nastart to help locate media
- external handoff needs a stable playable URL or service endpoint
- user wants media service cards to show richer state

### 3.3 Level 2: Resource Handoff

This is one of the highest v1 integration levels.

Capabilities:

- browse folders, libraries, or media items lightly
- show file/item detail
- use iOS preview where safe
- open with default external player
- choose another external app
- copy/share playable URL or service URL

### 3.4 Level 3: Basic System Playback

This is the confirmed v1 media target where feasible.

Capabilities:

- play common video formats through system playback
- play common audio formats through system playback
- use system file preview for images, text, PDF, and similar resources
- provide a clear fallback to external apps when system playback cannot handle
  a resource
- keep the same resource and playback routing model for future advanced engines

V1 should still avoid:

- full custom playback engine
- advanced video renderer integration
- metadata scraping
- subtitle management
- watch-progress sync
- transcoding control
- library administration

## 4. Entry Points

### 4.1 Automatic Discovery

Entry:

```text
Onboarding / Devices
-> Connect Synology DSM
-> Discovery Review
```

When Nastart detects a likely media service from DSM packages, Docker
containers, exposed ports, reverse-proxy paths, or HTTP fingerprints, it should
show a candidate card.

Candidate actions:

- Add as web service.
- Connect library.
- Hide.
- Edit type.

Recommended behavior:

- If confidence is high, preselect service type.
- If confidence is medium, show "Detected as Jellyfin?" with confirm/edit.
- If confidence is low, add as generic web service and let user connect later.

### 4.2 Launchpad Card

Entry:

```text
Launchpad
-> media service card
```

For a Level 0 card:

- tap opens the web UI using best endpoint
- long press shows Open, Connect Library, Edit, Copy URL, Check Status

For a Level 1 or Level 2 card:

- tap opens Media Service Detail
- the first action on detail is still "Open Web UI"
- long press shows Open Web UI, Browse Library, Open In, Edit, Check Status

For a Level 3 media service:

- tap opens Media Service Detail or the user's configured media default
- resource items can show Play, Open In, Copy, and Share actions
- unsupported media should show an external player recommendation instead of a
  broken playback screen

This keeps the Launchpad predictable: cards always open the most useful service
surface, but users can still jump directly to the web UI.

### 4.3 Add Service

Entry:

```text
Launchpad
-> Add Service
-> Media Service
-> Jellyfin / Emby / Navidrome / Plex / Other
```

This path is for users whose service was not discovered automatically.

Fields should be minimal:

- service type
- service URL
- display name
- connection mode: Web only or Connect library

Advanced fields should be hidden:

- local URL
- remote URL
- custom path
- external app default
- certificate trust

### 4.4 Device Detail

Entry:

```text
Devices
-> Device Detail
-> Services / Containers / Packages
-> detected media service
```

This path is for users who think in infrastructure terms.

Actions:

- create Launchpad card
- connect library
- view related container/package
- check endpoints
- open service

### 4.5 Mine / External Apps

Entry:

```text
Mine
-> External Apps
```

This is not where users add Jellyfin, Emby, or Navidrome servers. It is where
they choose defaults for handoff targets:

- default video app
- default audio app
- default file app
- custom URL scheme
- fallback behavior

## 5. Jellyfin Flow

### 5.1 Add / Connect Flow

Recommended path:

```text
Add Service / Discovery Review / Media card
-> Jellyfin
-> Confirm service URL
-> Security check
-> Sign in or token/API-supported auth
-> Fetch server identity
-> Choose libraries
-> Choose default open behavior
-> Media Service Detail
```

Default open behavior options:

- Open service detail.
- Open web UI.
- Open library browser.

Recommended default:

```text
Open service detail
```

Reason:

The detail page can offer both "Open Web UI" and "Browse Library" without
forcing Nastart to behave like a media player.

### 5.2 Media Service Detail

Recommended sections:

```text
Header
├─ service icon/name
├─ endpoint state
├─ certificate state
└─ linked NAS/container

Quick Actions
├─ Open Web UI
├─ Browse Library
└─ Open In

Libraries
├─ Movies
├─ Shows
├─ Music
└─ user-selected libraries

Handoff
├─ default video app
├─ default audio app
└─ share/copy fallback

Settings
├─ endpoints
├─ authentication
├─ card display
└─ reconnect
```

### 5.3 Library Browser

V1 browser should be shallow and functional:

- libraries
- folders or item lists where supported
- search within service if API support is stable
- item detail
- open/copy/share actions

Avoid:

- poster-wall replacement for Jellyfin's own UI
- full movie detail pages
- subtitle selection
- playback state sync

## 6. Emby Flow

Emby should follow the same UX structure as Jellyfin.

Recommended path:

```text
Add Service / Discovery Review / Media card
-> Emby
-> Confirm service URL
-> Security check
-> User authentication or API key where appropriate
-> Fetch server identity
-> Choose libraries
-> Choose default open behavior
-> Media Service Detail
```

Notes:

- Emby supports user authentication and API-key style access in its public
  developer documentation.
- V1 should prefer the safest minimal access needed for browsing and handoff.
- If administrator-only API keys are required for a task, Nastart should avoid
  that task unless the user explicitly understands the permission.

Nastart should not trigger library scans, server administration, or write
operations in v1.

## 7. Navidrome Flow

Navidrome is different because it is music-first and uses the Subsonic /
OpenSubsonic ecosystem.

Recommended path:

```text
Add Service / Discovery Review / Media card
-> Navidrome
-> Confirm service URL
-> Security check
-> Subsonic/OpenSubsonic-compatible login
-> Fetch user/music library state
-> Choose default audio app
-> Media Service Detail
```

### 7.1 Navidrome Detail

Recommended sections:

```text
Header
├─ service icon/name
├─ endpoint state
└─ linked NAS/container

Quick Actions
├─ Open Web UI
├─ Browse Music
└─ Open In Audio App

Music
├─ Albums
├─ Artists
├─ Playlists
└─ Recently added if available

Handoff
├─ Stream Music / 音流
├─ Amperfy / play:Sub / other compatible apps
└─ share/copy fallback
```

### 7.2 Navidrome Limits

V1 should avoid becoming a music player.

Do:

- connect service
- show library entry points
- browse lightly
- hand off to external audio apps
- open Navidrome web UI

Do not:

- implement full queue management
- implement lyrics, scrobbling, rating, offline downloads, or CarPlay behavior
- claim full OpenSubsonic client parity before testing

## 8. Media Resource Detail

Entry:

```text
Media Service Detail
-> Library / Media root
-> Folder / item
-> Resource Detail
```

Resource Detail should show:

- name
- type
- source service/root
- size/duration if available
- path or service URL, collapsed by default
- playable/handoff state

Primary action:

- Open with default app.

Secondary actions:

- Choose app.
- Preview, if native iOS preview is safe.
- Copy URL/path.
- Share.
- Open parent service.

## 9. Failure And Edge Cases

### 9.1 Service Detected But Unreachable

Show:

- service name/type
- local URL failed
- remote URL option if configured
- Diagnose
- Edit endpoint

Avoid long troubleshooting text on the card.

### 9.2 Certificate Problem

Show a warning sheet:

- certificate expired
- certificate changed
- self-signed certificate
- continue once / trust fingerprint / cancel

Never silently trust certificate changes.

### 9.3 Authentication Failed

Show:

- reconnect
- check account/password/token
- open web UI
- keep as web-only card

Do not delete the service card automatically.

### 9.4 Handoff Not Available

Show:

- default app not installed
- share sheet
- copy URL
- open App Store
- open web UI

Do not pretend external playback is supported when Nastart cannot produce a
usable handoff target.

## 10. UI Detail Rules

Media service screens should still follow Nastart's app shell style:

- white background
- black text
- monochrome SF Symbols for actions
- service logos only where they improve recognition
- warm accent for primary action
- concise status chips
- no poster-heavy layout outside media browsing
- no long educational copy

The screen should answer in one glance:

- Which media service is this?
- Is it reachable?
- What can I do now?
- Which app will open it?

## 11. V1 Implementation Priority

Recommended order:

1. Detect Jellyfin, Emby, Plex, and Navidrome as web service cards.
2. Add manual Media Service flow.
3. Add service detail page with Open Web UI, endpoints, status, certificate.
4. Add external app defaults and Open In sheet.
5. Add Navidrome/Subsonic lightweight music browsing.
6. Add Jellyfin/Emby lightweight library browsing.
7. Add DSM shared-folder media roots.
8. Add richer handoff rules after verifying stable app URL schemes.

Do not start UI mockups for media pages until steps 1-4 are clear enough to
prototype.

## 12. Open Questions

- How should Media Service Detail balance "Open Web UI", "Browse Library", and
  "Play/Open In" without feeling crowded?
- Can Plex API/auth integration be verified early enough for v1 first-class
  support, or should it start as web-only?
- Which external app integrations are verifiable enough to enable by default?
- Which exact system-supported video/audio formats should be listed in v1
  support copy?
- How much library metadata can be shown without turning the UI into a full
  media client?
- Should media roots from DSM shared folders be shown under media service cards
  or under a separate Files/Media Roots page inside Device Detail?
- Which parts of Jellyfin/Emby/Navidrome auth can be safely synced through
  iCloud metadata without syncing secrets?

## 13. Source Notes

Implementation details must be verified against official service
documentation before coding:

- Jellyfin documentation describes Jellyfin as a media server with official
  documentation and API documentation.
- Emby developer documentation describes user authentication and API-key
  authentication for server API access.
- Navidrome documentation describes Subsonic/OpenSubsonic API compatibility and
  a broad ecosystem of compatible apps.
