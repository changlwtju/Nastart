# Nastart Strategic Foundations

Version: 0.1  
Status: Draft  
Last updated: 2026-07-25

## 1. Purpose

This document records the initial strategic assumptions for Nastart before
writing detailed PRDs, UI designs, and engineering architecture.

These decisions may evolve, but they should not be changed casually because
they affect product scope, platform architecture, App Store submission,
business model, and security posture.

## 2. Product Positioning

Nastart is a NAS and HomeLab companion for Apple users.

The first release should be positioned as Synology-first: the product is
designed and tested primarily around Synology DSM. V1 should prioritize
automatic DSM API, app-side probing, and optional Agent flows. Manual entry is a
fallback, not the primary experience. Public messaging should avoid unsupported
or unofficial hardware terminology and should describe Nastart as a third-party
companion optimized for Synology DSM users.

The optional Nastart Agent should be described as a local Docker-based helper
that runs on the user's own NAS or Linux host. Synology DSM is the primary
tested target for v1. Other Docker-capable NAS platforms are a future
compatibility path through the same Agent/provider architecture once dedicated
test devices and provider integrations exist.

It should combine:

- NAS connection management
- Automatic service discovery
- Beautiful native launch pages
- Service health and access diagnosis
- NAS and Docker status monitoring
- Domain, certificate, and subscription lifecycle reminders
- Optional Agent-based advanced capabilities

Nastart should avoid becoming only:

- a mobile Homepage clone
- a generic SSH client
- a pure media player
- a Synology-only utility
- a stitched-together collection of unrelated NAS tools

The core product narrative should be unified:

```text
Connect a Synology NAS -> discover services -> generate a polished launchpad
-> open, monitor, hand off, and remember lifecycle events from one place.
```

Features that do not reinforce this narrative should be treated as later
experiments, even if they are technically possible.

## 3. Platform Strategy

Recommended platform roadmap:

| Platform | Priority | Decision |
|---|---:|---|
| iPhone | P0 | First release must support |
| iPad | P0 | First release should adapt from day one |
| macOS | P1 | Plan architecture and launchpad components for later expansion |
| Apple Watch | P2 | Health summary and quick alerts later |
| Apple TV | P3 | Possible status wall, not early focus |
| Apple Vision Pro | P3 | Keep design adaptable, no early investment |

The app should use responsive SwiftUI layouts from the beginning:

```text
Compact -> iPhone
Regular -> iPad
Large -> future macOS/dashboard layouts
```

## 4. System Version Strategy

Initial recommendation:

- Minimum deployment target: iOS 16.0 / iPadOS 16.0 for the first iPhone and
  iPad release
- Build with the latest available Xcode and SDK at release time
- Avoid adopting APIs that make iOS 16 support painful unless they are isolated
- Treat iOS/iPadOS 26+ Liquid Glass-style UI as an adaptive presentation branch,
  not as a reason to drop older supported systems.

This fits the user's current device reality while still allowing modern SwiftUI,
Swift Concurrency, WidgetKit, Keychain, Network.framework, and StoreKit 2 usage.

Recommended minimum system baselines:

| Platform | Minimum OS | Release Role | Notes |
|---|---:|---|---|
| iPhone | iOS 16.0+ | V1 required | Main release target |
| iPad | iPadOS 16.0+ | V1 required | Must have intentional tablet layout |
| Mac | macOS 14.0+ | Future P1 | Plan SwiftUI architecture and window layouts early; final minimum can be reassessed before Mac launch |
| Apple Watch | watchOS 9.0+ | Future P2 | Health summary and alerts only |
| Apple TV | tvOS 16.0+ | Future P3 | Status-wall/dashboard target, not V1 |
| Apple Vision Pro | visionOS 2.0+ | Future P3 | No early implementation commitment |

Liquid Glass-style UI should be enabled only on systems where the platform
supports it well. Classic presentation remains the baseline for older supported
systems.

## 4.1 Launchpad Theme Strategy

The launchpad is one of Nastart's main selling points. V1 should optimize for
theme quality rather than theme count.

Recommended V1 direction:

- roughly 3 polished built-in themes
- treat the initial theme names as candidates until low-fidelity layout sketches
  are reviewed
- Classic presentation for iOS/iPadOS versions below 26
- Liquid presentation for iOS/iPadOS/macOS/tvOS 26+ where system-supported
  materials are available
- iPhone and iPad layout quality from day one
- macOS and Apple TV component readiness for later releases
- full user-designed dashboards deferred until after built-in templates are
  excellent

## 5. NAS Compatibility Strategy

Nastart should be Synology-first in v1, but not hard-coded as Synology-only.
The first release should make Synology DSM the best-supported and most complete
experience. Other NAS platforms should be prepared through Agent/provider
interfaces, but deep non-Synology support can be treated as v2+ work.

Recommended support order:

| Provider | Priority | Notes |
|---|---:|---|
| Synology DSM | P0 | First-class v1 support and primary test target |
| DSM API | P0 | Preferred v1 automation path for Synology login, system data, packages, and available container data |
| App-side probing | P0 | Preferred v1 path for service reachability, certificate checks, title/favicon fingerprints |
| Docker/Linux Agent | P0/P1 | Optional advanced path for discovery and monitoring; Synology-tested first, future compatibility path elsewhere |
| Manual NAS/service entry | P1 | Required fallback, not primary workflow |
| QNAP | P1 | Future deep provider support |
| Unraid | P1 | Future deep provider support |
| TrueNAS | P1 | Future deep provider support |
| CasaOS/ZimaOS/FriendlyElec/others | P2 | Later ecosystem support |

The product should use a Provider model so each NAS family can implement its
own capability surface without forcing one universal API.

Marketing copy should be clear:

- optimized for Synology DSM
- automatic where possible through DSM API, app-side probing, and optional Agent
- manual entry is available as a fallback
- Agent/provider architecture reserves a path for future non-Synology NAS support
- deeper compatibility for other NAS platforms will improve over time
- Nastart is not an official Synology app

## 6. Release Region Strategy

Initial recommendation:

- Release globally if compliance and support capacity allow.
- Support Simplified Chinese and English at first.
- Avoid China-only positioning, because HomeLab/NAS communities are global.

## 7. Privacy Strategy

Default privacy posture:

- No ads.
- No cross-app tracking.
- No mandatory account for core local features.
- iCloud/CloudKit sync should be considered for v1 Apple-device continuity.
- Any Cloud or sync layer must not store NAS credentials in plaintext.
- Privacy policy and support pages are required before App Store submission.

## 8. Age Rating Strategy

Nastart may include an embedded browser for user-owned NAS services.

To reduce age-rating and review risk:

- Do not provide public web search.
- Treat built-in browser as a private service viewer.
- Provide clear user-controlled service entries.
- Avoid content discovery features unrelated to user-owned systems.

## 9. App Size Strategy

Initial internal target:

- First download target: under 60 MB where practical.
- Keep heavy icon packs, themes, and integrations modular.
- Prefer system components and remote-updatable metadata where safe.

## 10. Website Strategy

The project needs a developer website before App Store submission.

Minimum pages:

- Landing page
- Privacy policy
- Support
- FAQ
- Roadmap or changelog

The first website can be static.

## 11. Business Model

Recommended model:

- Free base version for local NAS connection and basic launchpad
- Nastart Plus as the single user-facing paid tier for advanced local features
  and selected sync capabilities
- iCloud sync belongs to Nastart Plus, while custom server Cloud remains future
  work
- Keep pricing low and consumer-friendly. Nastart improves NAS convenience and
  polish, but it is not a must-have utility for most users.
- Prefer a low annual plan and a lifetime purchase option. Avoid weekly
  subscriptions and avoid high SaaS-style pricing.

Possible feature mapping:

| Tier | Features |
|---|---|
| Free | 1 NAS, basic DSM connection, limited cards, manual fallback |
| Nastart Plus | Multiple NAS, themes, auto discovery, widgets, diagnostics, reminders, iCloud sync |
| Future Cloud | Push notifications, cloud backup, cross-platform sync, server validation |

Candidate launch pricing:

| Product | US Candidate | China Candidate |
|---|---:|---:|
| Nastart Plus Monthly | USD 0.99 | CNY 6-8 |
| Nastart Plus Annual | USD 7.99-9.99 | CNY 38-48 |
| Nastart Plus Lifetime | USD 14.99 | CNY 88-98 |

Final App Store prices should be selected from Apple's available price points
and localized storefront matrix.

## 12. Open Questions

- Exact App Store region rollout sequence
- Final app name and visual identity
- Whether Agent is open source from day one
- How much direct DSM control should be exposed in v1
- Whether custom Nastart Cloud is needed after v1
