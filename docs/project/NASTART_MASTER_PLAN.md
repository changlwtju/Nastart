# Nastart Master Plan

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
| One person part-time | 1 | 3-5 years | very high |
| One person full-time with AI | 1 | 18-30 months | feasible but demanding |
| Small team | 2-3 | 12-18 months | recommended |
| Professional team | around 5 | 8-12 months | faster but expensive |

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

- SwiftUI shell
- local service cards
- manual NAS/service entry
- theme prototype
- internal/external browser flow

### Phase 3: Agent MVP

- local Agent pairing
- Docker read-only discovery
- basic NAS metrics
- service detection

### Phase 4: App MVP

- multi-device management
- generated launchpad
- health monitor
- certificate/domain reminders
- iPad layout
- TestFlight release

### Phase 5: Pro Product

- advanced themes
- widgets
- diagnostics
- multi-provider support
- StoreKit 2 monetization

### Phase 6: Optional Cloud

- encrypted sync
- push notifications
- backup
- multi-device continuity

