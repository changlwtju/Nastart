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

## 3. Platform Strategy

Recommended platform roadmap:

| Platform | Priority | Decision |
|---|---:|---|
| iPhone | P0 | First release must support |
| iPad | P0 | First release should adapt from day one |
| macOS | P1 | Plan architecture for later expansion |
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

- Minimum deployment target: iOS 16.0 / iPadOS 16.0
- Build with the latest available Xcode and SDK at release time
- Avoid adopting APIs that make iOS 16 support painful unless they are isolated

This fits the user's current device reality while still allowing modern SwiftUI,
Swift Concurrency, WidgetKit, Keychain, Network.framework, and StoreKit 2 usage.

## 5. NAS Compatibility Strategy

Nastart should not be Synology-only.

Recommended support order:

| Provider | Priority | Notes |
|---|---:|---|
| Synology DSM | P0 | First-class early support |
| Docker/Linux Agent | P0 | Core abstraction for many NAS/HomeLab setups |
| QNAP | P1 | Mainstream NAS provider |
| Unraid | P1 | Popular HomeLab platform |
| TrueNAS | P1 | Important for advanced users |
| CasaOS/ZimaOS/FriendlyElec/others | P2 | Later ecosystem support |

The product should use a Provider model so each NAS family can implement its
own capability surface without forcing one universal API.

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
- Cloud sync must be optional.
- Cloud should not store NAS credentials in plaintext.
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
- Pro one-time purchase for advanced local features
- Optional Cloud subscription for sync, push, backup, and cross-device features

Possible feature mapping:

| Tier | Features |
|---|---|
| Free | 1 NAS, basic cards, manual services, basic health view |
| Pro | Multiple NAS, themes, auto discovery, widgets, diagnostics, reminders |
| Cloud | Encrypted sync, push notifications, cloud backup, multi-device continuity |

## 12. Open Questions

- Exact App Store region rollout sequence
- Final app name and visual identity
- Whether Agent is open source from day one
- How much direct DSM control should be exposed in v1
- Whether Cloud subscription launches with v1 or later

