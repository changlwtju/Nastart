# Nastart Cost Breakdown

Version: 0.1
Status: Draft
Last updated: 2026-07-27

## 1. Purpose

This document breaks down the expected cost categories for building Nastart
under the current product direction.

Nastart Plus is planned as a low-priced consumer utility. Cost control is
therefore a core product requirement, not only a finance concern.

## 2. Cost-Control Principle

V1 should avoid costs that do not directly improve the first paid experience.

Recommended cost-control rules:

- No rented custom cloud server for V1 multi-device sync.
- Use iCloud/CloudKit for Apple-device configuration sync.
- Use local-first storage and the user's own NAS for NAS data.
- Build Synology DSM support first; defer deep QNAP/Unraid/TrueNAS support.
- Ship a small number of polished launchpad themes, not a theme marketplace.
- Use external players and system preview APIs before building a professional
  media player.
- Make the Agent read-only in V1 to reduce security, support, and testing cost.
- Avoid custom account systems, web dashboards, server push, and team sharing
  until there is product traction.

## 3. First-Year Cash Cost Categories

These are external cash costs, excluding developer time.

| Category | V1 Need | Expected Cost Level | Notes |
|---|---|---:|---|
| Apple Developer Program | Required for App Store/TestFlight | USD 99/year | Needed for distribution and Apple platform capabilities |
| App Store commission | Required when selling Plus | 15%-30% of qualifying digital sales | 15% is possible if enrolled in Apple's small business program or qualifying subscription rules apply |
| Domain | Recommended | low | Needed for support website, privacy policy, and brand trust |
| Static website hosting | Required before App Store release | free to low | Static site is enough for V1 |
| Business email | Recommended | low | Can start with low-cost mailbox or existing domain email |
| Cloud server | Not required for V1 | 0 | iCloud/CloudKit covers Apple-device sync for V1 |
| Cloud database/storage | Not required for V1 custom backend | 0 | Do not build Nastart Cloud until needed |
| Git hosting | Required | free to low | GitHub free/private repo is enough early |
| CI/CD | Optional | free to low | GitHub Actions or local builds can be enough at first |
| Analytics/crash reporting | Optional | free to low | Can start with App Store Connect and local logs; add third-party tools carefully |
| Design tools/assets | Useful but controllable | low to medium | Avoid paid asset packs unless they lift the launchpad quality |
| Test devices | Important | medium | Use existing devices first; add used devices only for coverage gaps |
| NAS test hardware | Important | medium to high | Start with existing Synology DSM environment; expand later |
| App Store screenshots | Required | low if self-made | Build screenshot templates in-house |
| Legal/privacy docs | Required | low to medium | Start with carefully written privacy/support pages; lawyer review later if revenue grows |

## 4. Bootstrap Cash Scenarios

| Scenario | What It Assumes | First-Year Cash Excluding Labor |
|---|---|---:|
| Minimum bootstrap | Existing Mac/iPhone/iPad/NAS, static website, no paid design tools, no custom server | about CNY 1,000-5,000 plus Apple annual fee/local taxes |
| Lean commercial | Adds domain email, a few used test devices, screenshot/design polish, optional crash reporting | about CNY 5,000-30,000 plus Apple annual fee/local taxes |
| Aggressive validation | Adds more test hardware, paid design help, more devices, stronger launch materials | about CNY 30,000-100,000+ |

The biggest avoidable V1 cash cost is a custom cloud server. Keep it out of V1
unless CloudKit fails a core requirement.

## 4.1 Current Available Resources Scenario

Current known resources:

- iPhone 13 on iOS 16
- iPad 9th generation
- latest-generation Apple TV
- base-model MacBook Air
- Synology-compatible DSM test NAS: DS918+ class, DSM 7.2.1

This is a strong bootstrap setup for early development:

- iPhone and iPad can cover the V1 required platforms.
- MacBook Air is enough for initial Xcode development if project size stays
  controlled.
- Existing DSM 7.2.1 environment can cover the primary Synology-first test path.
- Apple TV can be used later for status-wall experiments, but tvOS should not be
  part of V1.

Recommended first-stage cash spending with these resources:

| Item | Needed Now | Estimate |
|---|---:|---:|
| Apple Developer Program | Yes | USD 99/year |
| Domain | Strongly recommended | about CNY 50-150/year |
| Static support/privacy site | Yes, but can be free hosting | CNY 0-300/year |
| Paid design tools/assets | Optional | CNY 0 first |
| Extra test devices | Defer | CNY 0 first |
| Extra NAS hardware | Defer | CNY 0 first |
| Custom cloud server | No for V1 | CNY 0 |

With current resources, the realistic first-year cash cost can stay near:

```text
Apple Developer Program + domain + minimal website
```

In practice this can be roughly CNY 800-1,500 depending on exchange rate,
domain choice, and whether email/hosting remains free.

## 4.2 Break-Even Estimate

Break-even should be calculated in two layers:

1. Cash break-even: external spending only.
2. Optional full-cost break-even: external spending plus the value of developer
   time, only if the project is treated as a commercial labor investment.

Assumptions:

- App Store Small Business Program or qualifying subscription commission:
  roughly 15% Apple commission.
- Without reduced commission, use 30% as a conservative fallback.
- China and US prices are approximate candidates, not final App Store price
  points.

Approximate net revenue per purchase at 15% commission:

| Product | Gross Price | Approx. Net |
|---|---:|---:|
| Monthly US | USD 0.99 | USD 0.84 |
| Annual US | USD 7.99 | USD 6.79 |
| Annual US higher candidate | USD 9.99 | USD 8.49 |
| Lifetime US | USD 14.99 | USD 12.74 |
| Monthly China | CNY 6-8 | CNY 5.1-6.8 |
| Annual China | CNY 38-48 | CNY 32.3-40.8 |
| Lifetime China | CNY 88-98 | CNY 74.8-83.3 |

Cash break-even examples for about CNY 1,200 first-year external cost:

| Plan Mix | Rough Paid Users Needed |
|---|---:|
| Mostly CNY 48 annual | about 30 annual subscribers |
| Mostly CNY 38 annual | about 38 annual subscribers |
| Mostly CNY 98 lifetime | about 15 lifetime buyers |
| Mostly CNY 88 lifetime | about 17 lifetime buyers |
| Mostly CNY 8 monthly | about 177 paid months, or about 15 users retained for 12 months |

If Apple commission is 30%, increase the required user count by roughly 20-25%.

For a part-time indie project, developer time may be treated as long-term
learning and product investment rather than cash that must be quickly recovered.
If developer time is still valued at CNY 30,000, 50,000, or 100,000, approximate
full-cost break-even becomes:

| Developer-Time Target | CNY 48 Annual Plan | CNY 98 Lifetime Plan |
|---|---:|---:|
| CNY 30,000 | about 735 users | about 360 users |
| CNY 50,000 | about 1,225 users | about 600 users |
| CNY 100,000 | about 2,450 users | about 1,200 users |

This is not a reason to stop the project. It is a reminder that V1 should ship
in useful slices. Cash cost is manageable, but broad feature scope can delay
real user feedback for too long.

## 4.3 Part-Time Indie Development Model

For this project, the preferred model is part-time indie development:

- cash spending should stay very low
- development time can stretch longer
- each milestone should produce something testable
- TestFlight should be used before full App Store monetization pressure
- the product should not wait for every planned feature before showing value

Recommended mindset:

```text
Recover cash cost early.
Validate product value through TestFlight.
Treat developer time as staged investment, not a short-term debt.
```

The most important risk is not failing to recover the Apple Developer Program
fee. The more serious risk is spending a year on scattered features without a
coherent usable beta.

## 4.4 Website Requirement Boundary

A full marketing website is not strictly required for development, but App Store
submission requires public privacy and support information.

Minimum acceptable V1 web presence:

- privacy policy page
- support/contact page
- optional FAQ
- optional landing page

The site can be static and free-hosted. It does not need a custom backend.

## 5. Development Effort Breakdown

The following estimates are rough implementation effort, not calendar time.
They assume one capable developer using AI assistance and existing open-source
knowledge, but still requiring real testing on DSM and Apple devices.

| Area | V1 Scope | Rough Effort |
|---|---|---:|
| Product/spec/design planning | PRD, IA, theme strategy, release scope, pricing | 2-4 weeks |
| SwiftUI app shell | tabs/sidebar, settings, navigation, state model | 3-5 weeks |
| Device center | Synology connection, endpoint storage, Keychain, certificate warnings | 4-8 weeks |
| DSM API discovery spike | login, packages, containers, ports, metrics feasibility | 4-8 weeks |
| Service discovery/card generation | fingerprints, confidence model, confirm/edit generated cards | 5-10 weeks |
| Launchpad V1 | cards, grouping, status, endpoint opening, reorder, theme picker | 6-12 weeks |
| Three theme prototypes | low-fidelity sketches, token system, iPhone/iPad adaptation | 4-8 weeks |
| Media service integration | Jellyfin/Emby/Navidrome library connection and basic playback/handoff | 6-12 weeks |
| Lightweight file preview/playback | video/audio/image/text/PDF preview, Quick Look, external fallback | 4-8 weeks |
| Health and certificates | reachability, TLS validity, fingerprint change, warnings | 3-6 weeks |
| Reminder center | domain/VPS/subscription/certificate/local notification flows | 3-6 weeks |
| iCloud/CloudKit sync | model mapping, conflict handling, re-auth boundaries | 4-8 weeks |
| StoreKit 2 | Plus purchase, restore, entitlement gates, paywall | 3-6 weeks |
| Agent V1 | Docker read-only helper, pairing, metrics, packaging, docs | 6-12 weeks |
| Website and App Store materials | landing, privacy, support, FAQ, screenshots | 2-4 weeks |
| TestFlight/release QA | regression, devices, DSM versions, review fixes | 4-8 weeks |

Many items can overlap, but the risk is integration and testing, not only
coding. The DSM API, media service integration, and launchpad polish are the
main schedule risks.

## 6. Cost-Control MVP Cut Line

If development cost or time starts expanding, cut in this order:

1. Defer Apple TV, Watch, Vision Pro, and Mac releases.
2. Defer deep non-Synology NAS provider support.
3. Defer advanced theme customization and marketplace.
4. Defer professional media-player features such as subtitles, transcoding, and
   metadata scraping.
5. Defer server-backed Nastart Cloud.
6. Defer write operations in Agent and Docker control.
7. Keep local reminders before server push.

Do not cut:

- Synology DSM connection quality
- automatic discovery and card generation
- Launchpad polish
- basic external opening and handoff
- Keychain/security warnings
- at least one good iPhone and one good iPad layout

These are the core reasons users would try Nastart.

## 7. Suggested V1 Budget Strategy

Recommended first stage:

```text
Spend time on automation and launchpad polish.
Spend little cash on infrastructure.
Buy test hardware only when a real compatibility gap appears.
Avoid custom Cloud until user traction proves the need.
```

Practical target:

- keep first-year fixed cash costs low
- treat developer time as the main investment
- use TestFlight to validate whether users value automatic discovery and
  launchpad themes before expanding expensive features
- avoid any feature that creates recurring server cost before Nastart Plus has
  stable conversion

## 8. When Costs Increase

Costs will rise meaningfully if Nastart adds:

- custom Nastart Cloud
- server-side push/remote diagnostics
- cross-platform sync outside Apple ecosystem
- team/family sharing
- full media player
- full file manager
- write-capable Docker/NAS operations
- large non-Synology test matrix
- paid design contractor
- paid customer support workflow

These can still be good future investments, but they should follow traction,
not precede it.
