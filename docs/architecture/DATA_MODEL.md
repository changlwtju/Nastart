# Nastart Data Model

Version: 0.1  
Status: Draft  
Last updated: 2026-07-25

## 1. Purpose

This document defines the first domain model for Nastart.

It is implementation-agnostic. The same model should support SwiftData, SQLite,
or another local persistence layer.

## 2. Modeling Principles

- Model user-owned infrastructure, not vendor screens.
- Keep secrets out of ordinary local database tables when possible.
- Prefer automatic discovery; support manual entry as a fallback and correction
  path.
- Allow multiple endpoints per service.
- Allow future Provider and Agent capabilities without rewriting service cards.
- Treat Synology DSM as the first-class v1 provider.
- Reserve Agent-backed compatibility for other Docker-capable NAS or Linux
  hosts without making deep non-Synology support a v1 requirement.
- Keep MVP fields small and understandable.

## 3. Core Entities

```text
Workspace
Device
Endpoint
Service
ServiceCategory
CredentialReference
HealthCheck
Reminder
ExternalAppIntegration
CertificateRecord
DomainRecord
AgentConnection
ThemeProfile
Entitlement
```

## 4. Workspace

A workspace groups devices and services.

Fields:

- `id`
- `name`
- `createdAt`
- `updatedAt`
- `preferredDeviceId`

MVP can create one default workspace.

## 5. Device

A device represents a NAS, server, or HomeLab host.

Fields:

- `id`
- `workspaceId`
- `displayName`
- `providerType`
- `modelName`
- `localAddress`
- `remoteAddress`
- `notes`
- `status`
- `createdAt`
- `updatedAt`

Provider types:

- `synology`
- `genericNAS`
- `genericLinux`
- `dockerHost`
- `qnap`
- `unraid`
- `truenas`
- `manual`

Only `synology`, `genericNAS`, `dockerHost`, and `manual` need early product
treatment. `synology` receives the best-supported v1 integration. `dockerHost`
represents Agent-backed Docker-capable systems, primarily for Synology v1
enhancement and future non-Synology compatibility. `genericNAS` and `manual`
support fallback device records and manual service navigation.

## 6. Endpoint

An endpoint describes how to reach a device or service.

Fields:

- `id`
- `ownerType`
- `ownerId`
- `label`
- `url`
- `networkScope`
- `securityMode`
- `isPreferred`
- `lastReachabilityStatus`
- `lastCheckedAt`

Network scopes:

- `local`
- `vpn`
- `remote`
- `unknown`

Security modes:

- `httpsTrusted`
- `httpsPinned`
- `httpsUntrusted`
- `httpUserApproved`
- `unknown`

## 7. Service

A service is a user-facing app or web UI running on NAS/HomeLab infrastructure.

Fields:

- `id`
- `workspaceId`
- `deviceId`
- `displayName`
- `subtitle`
- `categoryId`
- `iconKind`
- `iconValue`
- `openingMode`
- `sortIndex`
- `isFavorite`
- `status`
- `createdAt`
- `updatedAt`

Opening modes:

- `inAppBrowser`
- `safari`
- `askEachTime`

Status:

- `unknown`
- `reachable`
- `unreachable`
- `warning`
- `disabled`

Service URLs should be modeled as Endpoint records rather than fields on the
Service itself.

## 8. ServiceCategory

Fields:

- `id`
- `workspaceId`
- `name`
- `symbolName`
- `sortIndex`

Suggested default categories:

- Media
- Downloads
- Smart Home
- Network
- Files
- Monitoring
- Admin
- Other

## 9. MediaRoot

A media root is a user-confirmed folder, shared folder, or service library that
Nastart can browse for media handoff.

Fields:

- `id`
- `workspaceId`
- `deviceId`
- `serviceId`
- `displayName`
- `rootType`
- `path`
- `endpointId`
- `mediaKind`
- `isEnabled`
- `sortIndex`
- `createdAt`
- `updatedAt`

Root types:

- `dsmSharedFolder`
- `webdav`
- `httpDirectory`
- `jellyfinLibrary`
- `embyLibrary`
- `plexLibrary`
- `navidromeLibrary`
- `subsonicLibrary`
- `audioStationLibrary`
- `videoStationLibrary`
- `agentPath`
- `manual`

Media kinds:

- `video`
- `audio`
- `mixed`
- `unknown`

V1 should prefer DSM-discovered shared folders and service/library endpoints.
Manual paths should be used as confirmation or fallback.

## 10. MediaResource

A media resource represents a folder or file inside a media root. It can be
ephemeral and does not need to be fully persisted unless favorited or recently
opened.

Fields:

- `id`
- `mediaRootId`
- `parentId`
- `displayName`
- `resourceType`
- `path`
- `endpointId`
- `mimeType`
- `fileExtension`
- `fileSize`
- `duration`
- `modifiedAt`
- `playableURL`
- `handoffCategory`
- `createdAt`
- `updatedAt`

Resource types:

- `folder`
- `videoFile`
- `audioFile`
- `playlist`
- `unknownFile`

Handoff categories:

- `video`
- `audio`
- `file`
- `unknown`

Nastart should only expose external playback actions when a playable URL,
supported library endpoint, or shareable file endpoint can be produced.

## 11. CredentialReference

The local database stores references, not secret values.

Fields:

- `id`
- `ownerType`
- `ownerId`
- `purpose`
- `keychainKey`
- `createdAt`
- `updatedAt`

Credential purposes:

- `nasPassword`
- `apiToken`
- `agentToken`
- `cloudEncryptionKey`
- `certificateFingerprint`

## 12. HealthCheck

Fields:

- `id`
- `ownerType`
- `ownerId`
- `checkType`
- `status`
- `message`
- `checkedAt`
- `latencyMs`

Check types:

- `httpReachability`
- `certificateValidity`
- `agentHeartbeat`
- `deviceReachability`

MVP only requires HTTP reachability and optional certificate validity.

## 13. ExternalAppIntegration

An external app integration describes how Nastart can hand off a NAS resource
or endpoint to another iOS/iPadOS app.

Fields:

- `id`
- `displayName`
- `bundleIdentifier`
- `urlSchemes`
- `appStoreURL`
- `handoffCategory`
- `supportedEndpointTypes`
- `integrationConfidence`
- `isEnabled`
- `sortIndex`
- `createdAt`
- `updatedAt`

Handoff categories:

- `video`
- `audio`
- `fileManager`
- `reader`
- `remoteAccess`
- `serviceClient`
- `downloadClient`
- `custom`

Supported endpoint types:

- `directFileURL`
- `httpStream`
- `audioStream`
- `webdav`
- `smb`
- `jellyfin`
- `emby`
- `plex`
- `alist`
- `navidrome`
- `subsonic`
- `audioStation`
- `ssh`
- `rdp`
- `vnc`
- `unknown`

Integration confidence:

- `documented`
- `observed`
- `userConfigured`
- `disabled`

Initial known apps:

- Infuse
- VidHub
- Lenna
- VLC
- Fileball
- nPlayer
- SenPlayer
- zFuse
- NetEase Popcorn
- DS video
- Stream Music / 音流
- Finamp
- Amperfy
- play:Sub
- Evermusic
- Flacbox
- foobar2000
- Plexamp
- DS audio
- Documents
- FileBrowser
- FE File Explorer
- Owlfiles
- YACReader
- Panels
- Chunky
- PDF Expert
- Termius
- Blink Shell
- ShellFish
- Jump Desktop
- Microsoft Remote Desktop
- Home Assistant
- Jellyfin
- Emby
- Plex
- Immich

External app integrations should be treated as metadata, not as hard product
dependencies. If a scheme changes or a target app is unavailable, Nastart should
fall back to share sheet, Safari, copy URL, or App Store lookup.

## 14. Reminder

Fields:

- `id`
- `workspaceId`
- `title`
- `kind`
- `targetName`
- `dueDate`
- `renewalCycle`
- `alertLeadDays`
- `status`
- `notes`
- `createdAt`
- `updatedAt`

Kinds:

- `domain`
- `certificate`
- `vps`
- `subscription`
- `backup`
- `custom`

Status:

- `active`
- `snoozed`
- `done`
- `expired`
- `archived`

## 15. CertificateRecord

Fields:

- `id`
- `endpointId`
- `subject`
- `issuer`
- `notBefore`
- `notAfter`
- `fingerprint`
- `trustState`
- `lastCheckedAt`

Fingerprints may be stored in Keychain if treated as sensitive trust material.

## 16. DomainRecord

Fields:

- `id`
- `workspaceId`
- `domainName`
- `registrar`
- `expiresAt`
- `notes`
- `lastCheckedAt`

MVP can store domain expiration manually. WHOIS or registrar API integration is
deferred.

## 17. AgentConnection

Fields:

- `id`
- `deviceId`
- `agentBaseURL`
- `pairingState`
- `permissionLevel`
- `lastSeenAt`
- `version`
- `credentialReferenceId`

Pairing states:

- `notPaired`
- `pairing`
- `paired`
- `expired`
- `revoked`

Permission levels:

- `read`
- `diagnose`
- `control`
- `admin`

MVP does not require an Agent for basic use, but the model should support
Agent-backed discovery and monitoring in v1. Synology is the primary tested
Agent target. Other Docker-capable systems are reserved for later compatibility
work.

## 18. ThemeProfile

Fields:

- `id`
- `workspaceId`
- `name`
- `appearance`
- `scope`
- `accentColor`
- `cardStyle`
- `themeFamily`
- `presentationBranch`
- `density`
- `platformOverrides`
- `previewSnapshot`
- `createdAt`
- `updatedAt`

Candidate theme families:

- `cleanGrid`
- `commandCenter`
- `glassDeck`

Presentation branches:

- `classic`
- `liquid`

Theme scopes:

- `appGlobal`
- `launchpadOnly`

Advanced theme editing is deferred, but roughly three high-quality defaults
should exist early. The initial theme families are candidates until layout
sketches are reviewed. Theme data should be token-driven so built-in themes can
adapt across iPhone, iPad, future macOS, and future Apple TV surfaces.
V1 built-in themes should normally use the `launchpadOnly` scope so theme
changes do not rewrite the app shell.

The selected theme should be stored as a user/workspace preference and exposed
through Settings. `previewSnapshot` can point to a bundled or generated preview
used by the theme picker before the user applies the theme.

## 19. Entitlement

Fields:

- `id`
- `tier`
- `source`
- `expiresAt`
- `lastVerifiedAt`

Tiers:

- `free`
- `pro`
- `cloud`

Entitlements unlock app features. They must not be treated as a security
boundary for NAS access.

## 20. MVP Required Model Subset

MVP must implement:

- Device
- Endpoint
- Service
- ServiceCategory
- MediaRoot
- MediaResource
- CredentialReference
- HealthCheck
- ExternalAppIntegration
- Reminder

MVP can stub:

- Workspace
- CertificateRecord
- DomainRecord
- AgentConnection
- ThemeProfile
- Entitlement

## 21. Open Questions

- Should service icon metadata follow the dashboard ecosystems such as
  Homepage/Homarr for future import?
- Should endpoints be independently reusable across devices and services?
- Should categories be global or workspace-scoped?
- How much history should HealthCheck retain?
- Should reminders support attachments or receipts later?
