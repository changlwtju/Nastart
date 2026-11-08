# Nastart Master Plan

> 当前实施入口（2026-10-19）：本文保留初始范围、成本与阶段估算，不代表当前完成度。实际开发进度、问题和依赖计划维护在[开发状态](DEVELOPMENT_STATUS.md)，短摘要见[PROGRESS](../../PROGRESS.md)，播放路线见[当前技术说明](../architecture/VIDEO_PLAYBACK_PIPELINE.md)。

Version: 0.1  
Status: Draft  
Last updated: 2026-07-25

## 1. Purpose

This document estimates product scope, development resources, cost drivers, and
execution phases for Nastart.

## 2. Product System

Nastart should be treated as a product system, not just one iOS app.

Major components:

- iOS/iPadOS app
- future macOS app
- NAS Agent
- optional Cloud service
- developer website
- documentation system
- App Store operations
- customer support

## 3. Resource Estimate

| Scenario | Team | Estimated Time | Risk |
|---|---:|---:|---|
| One person part-time | 1 | 2-4+ years | feasible if scope is sliced into testable milestones |
| One person full-time with AI | 1 | 18-30 months | feasible but demanding |
| Small team | 2-3 | 12-18 months | recommended |
| Professional team | around 5 | 8-12 months | faster but expensive |

For Nastart's current reality, one-person part-time development is acceptable.
The goal should not be to finish every planned feature quickly. The goal should
be to ship coherent internal builds, then TestFlight builds, while keeping cash
spending low and cutting scope aggressively when needed.

## 4. Work Breakdown

| Area | Scope | Estimate |
|---|---|---:|
| Product design | blueprint, PRDs, journeys, business model | 2-3 person-months |
| UI/UX | design system, dashboard, themes, iPad layouts | 3-6 person-months |
| iOS/iPad app | networking, Keychain, dashboard, widgets, settings | 10-15 person-months |
| Agent | Docker, DSM, metrics, TLS, installer, updater | 4-6 person-months |
| Cloud optional | sync, push, accounts, billing, APNs | 5-8 person-months |
| Website | landing, privacy, support, docs | 0.5-1 person-month |
| Testing | NAS matrix, iOS versions, TestFlight, regression | 2-4 person-months |

## 5. Recommended Technical Stack

### iOS/iPadOS

- Swift
- SwiftUI
- Swift Concurrency
- Observation
- URLSession
- Keychain
- CryptoKit
- Network.framework
- WidgetKit
- BackgroundTasks
- StoreKit 2
- App Intents
- OSLog

### Agent

Recommended language: Go

Reasons:

- strong Linux deployment story
- mature HTTP and Docker ecosystem
- easy static binaries
- operational simplicity

### Cloud

Potential stack:

- Go
- PostgreSQL
- Redis
- S3-compatible storage
- APNs

### Website

Potential stack:

- Astro
- static site hosting

## 6. Cost Drivers

- Apple Developer Program
- domain name
- developer website
- business email
- design assets
- test devices
- NAS test matrix
- App Store screenshots and support
- long-term maintenance

Detailed cost categories and V1 cost-control rules are maintained in
`docs/project/COST_BREAKDOWN.md`.

Post-MVP roadmap and V1 architectural extension points are maintained in
`docs/product/POST_MVP_ROADMAP.md`.

## 7. Execution Phases

### Phase 0: Foundation

- Document structure
- Strategic foundations
- Product blueprint
- Security architecture
- Competitive research
- Master plan

### Phase 1: Product and Technical Blueprint

- iOS architecture
- Agent architecture
- data model
- service metadata model
- connection/security model
- first PRD

### Phase 2: Prototype

- finalize IA and visual style constraints for the prototype scope
- detail core UX flows before visual mockups
- create low-fidelity wireframes for iPhone and iPad
- use imagegen to generate several high-fidelity visual references for selected
  screens and launchpad themes
- choose the implementation direction from the visual references
- SwiftUI shell
- local service cards
- Synology DSM connection prototype
- automatic service discovery and card generation prototype
- lightweight media-root browsing and external player handoff prototype
- three launchpad theme prototypes: Clean Grid, Command Center, Glass Deck
- classic and Liquid presentation spike for launchpad cards
- internal/external browser flow
- real-device testing on available iPhone and iPad hardware

### Phase 3: Agent MVP

- local Agent pairing
- Docker read-only discovery
- basic NAS metrics
- service detection

### Phase 4: App MVP

- multi-device management
- generated launchpad
- media roots and playable file handoff
- health monitor
- certificate/domain reminders
- iCloud/CloudKit sync
- iPad layout
- polished launchpad themes across supported iPhone and iPad sizes
- TestFlight release

### Phase 5: Nastart Plus Product

- advanced themes
- widgets
- diagnostics
- multi-provider support
- StoreKit 2 monetization
- richer Launchpad customization
- advanced media library and playback path
- HTTPS/TLS certificate automation exploration

### Phase 6: Optional Nastart Cloud

- custom encrypted sync if CloudKit is insufficient
- push notifications
- backup
- multi-device continuity

### Phase 7: Advanced Media And Automation

- DS One/Lenna-class video playback track
- richer audio playback and queue management
- subtitle, audio track, progress, and quality controls
- Agent-assisted certificate deployment and renewal
- safer file operations and transfer queue
- Apple TV and macOS media/dashboard expansion
