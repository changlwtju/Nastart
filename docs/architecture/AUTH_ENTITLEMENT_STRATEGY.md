# Auth and Entitlement Strategy

Nastart should keep NAS access and paid membership as two separate systems.

## NAS access

Nastart does not need a first-party account for v1.

Users connect their own NAS directly:

- DSM address, account, and password or token are used only for DSM login.
- DSM login credentials (including configured endpoints, last route and trusted device ID), Agent tokens, and service API keys are stored on-device in Keychain. DSM SIDs currently live in the active session; cold restore logs in again rather than reusing a persisted SID.
- Disconnecting NAS removes local NAS credentials and session state.
- Disconnecting NAS does not affect App Store purchases or Plus entitlement.

This keeps the app local-first, reduces backend cost, and avoids storing user NAS secrets on Nastart servers.

### Current automatic restore (2026-10-22)

`DSMConnectionOperations.login` enables credential-free preparation when multiple validated configured URLs exist. `DSMClient.login` races bounded API.Info GETs on those exact origins, reuses the first usable result and cancels losing probes before sequential authentication. Manual login and single-endpoint restore retain their original order. No new host is learned from discovery or redirects. An uncertain credential POST outcome remains terminal; explicit API-version incompatibility and safe connection errors retain their existing bounded fallback rules.

[Implementation and limited iPhone 13 evidence](../archive/handoffs/2026-10/2026-10-22-CONFIGURED-ENDPOINT-RESTORE.md) do not establish iPhone 18 acceptance or a competitor speed result.

## Profile

The profile shown in the Mine tab is local app profile state, not a Nastart cloud account.

It currently includes:

- nickname
- avatar initial / future avatar reference
- NAS connection status
- Plus entitlement status

Future iCloud sync can sync profile preferences if the user enables Plus and iCloud.

## Plus entitlement

Plus is determined by Apple StoreKit purchases, not DSM login.

The intended production flow is:

- App checks StoreKit current entitlements at launch.
- App listens for StoreKit transaction updates while running.
- Restore Purchases calls Apple's restore/sync purchase flow.
- Manage Subscription opens Apple's subscription management UI or subscription management URL.
- Nastart does not cancel subscriptions inside the app; cancellation and renewal are controlled by Apple.

Family Sharing should stay disabled for v1 because the planned subscription price is low and the product is niche.

## Feature gates

Feature gates should read from one source: `EntitlementStore`.

Initial Plus-gated features:

- iCloud sync
- multiple NAS devices
- larger launchpad card count
- advanced launchpad themes
- more reminders and watchers

Free features should remain useful enough for onboarding, but advanced continuity and scale should require Plus.

## Later server option

Only introduce a Nastart account if the product later needs features that cannot be solved locally or through iCloud:

- cross-platform sync outside Apple devices
- web console
- team sharing
- server-side push aggregation
- non-Apple purchase channels

Until then, no custom account backend is needed.
