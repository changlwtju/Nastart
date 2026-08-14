# Nastart Sync Strategy

Version: 0.1  
Status: Draft  
Last updated: 2026-07-26

## 1. Purpose

This document defines Nastart's sync strategy across iPhone, iPad, and future
Apple platforms.

The product should support multi-device continuity early without forcing the
team to build and operate a custom backend in v1.

## 2. Decision

V1 should prioritize iCloud/CloudKit sync for Apple-device continuity.

Self-hosted or first-party Nastart Cloud should be treated as a later server
product, not a prerequisite for the first iOS/iPadOS release.

```text
V1: Local-first app + iCloud/CloudKit sync
Later: Optional Nastart Cloud backend if product needs exceed CloudKit
```

This means V1 does not require renting or operating a custom cloud server for
multi-device sync. The app can rely on the user's Apple ID and CloudKit private
database for Apple-device continuity, while keeping Nastart's own backend out
of the first release scope.

CloudKit is not a replacement for every possible future cloud feature. It is a
good fit for Apple-only configuration sync, but not for cross-platform sync,
team sharing, web dashboards, server-triggered automation, or a custom account
system.

## 3. What iCloud Sync Means

iCloud sync should keep user configuration consistent across the user's Apple
devices.

Examples:

- NAS display records
- service cards
- categories
- card order
- favorite/hidden state
- Launchpad theme and layout preferences
- local and remote endpoint metadata
- reminder records
- certificate metadata and warning state
- default external app preferences
- non-sensitive diagnostic history

The goal is that a user can configure Nastart on iPhone and open the same
Launchpad on iPad without repeating setup.

## 4. What Should Not Be Synced Plaintext

Do not sync plaintext secrets.

Sensitive data includes:

- DSM passwords
- DSM session tokens
- Agent pairing tokens
- API keys
- private keys
- URLs containing embedded secrets
- cookies

Preferred handling:

- Store secrets in Keychain.
- Sync only references or non-sensitive metadata when possible.
- If a secret must sync later, use explicit end-to-end encryption design before
  implementation.
- Allow users to re-authenticate on a new device when required.

## 5. V1 Sync Scope

Required for V1 if CloudKit is enabled:

- one user's private iCloud database only
- no sharing between users
- no team/family workspace sync
- no web dashboard
- no custom account system
- no server-side push workflow
- no custom billing backend
- no rented Nastart server required for sync

Recommended synced entities:

- Workspace
- Device metadata, excluding secrets
- Endpoint metadata, excluding secret-bearing URLs
- Service
- ServiceCategory
- Reminder
- ThemeProfile
- ExternalAppIntegration preferences
- certificate record metadata, excluding sensitive trust material if classified
  as secret

## 6. Conflict Handling

V1 should keep conflict handling simple:

- Each record has stable `id`, `createdAt`, and `updatedAt`.
- Last-writer-wins is acceptable for most display preferences.
- Reminders should preserve completion state carefully.
- Local completed-reminder history is bounded to 500 records before it is
  persisted or included in a CloudKit snapshot, keeping local storage and
  sync payloads predictable.
- CloudKit `serverRecordChanged` conflicts must re-read the remote record and
  retry only when the local snapshot is still newer; incompatible remote
  schemas must fail safely without overwriting local data.
- Deleted records should use tombstones or soft delete if CloudKit requires it.
- Dangerous automatic merges should be avoided.

## 7. Offline Behavior

Nastart remains local-first:

- App works without network.
- Launchpad loads from local cache.
- Reminders exist locally.
- Sync resumes when iCloud is available.
- Sync failures should not block local use.

## 8. Membership Position

User-facing membership should stay simple.

Recommended model:

```text
Free
Nastart Plus
```

iCloud sync should be a Nastart Plus capability.

The data model and code should treat sync as a capability flag, not as a
separate Cloud membership tier.

## 9. Future Nastart Cloud

Build a custom Nastart Cloud only if CloudKit no longer fits.

Possible reasons:

- cross-platform sync outside Apple ecosystem
- web dashboard
- family/team sharing
- server-triggered push notifications
- encrypted backup independent of iCloud
- advanced subscription validation
- remote diagnostics relay

Future Nastart Cloud must not store NAS credentials or private tokens in
plaintext.

## 10. Open Questions

- Which fields should require re-authentication on a new device?
- Should certificate fingerprints live in Keychain only or sync as metadata?
- Should local export/import exist alongside iCloud sync?
- Should CloudKit be used directly or wrapped behind a `SyncRepository`
  abstraction from day one?
