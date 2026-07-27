# Nastart Pricing Strategy

## 1. Pricing Thesis

Nastart is useful, but it is not a must-have utility for most NAS users.

Pricing should reflect that reality:

- keep the entry barrier low
- make the free version genuinely useful
- make Nastart Plus feel like a convenience upgrade
- avoid pricing like a professional SaaS product
- avoid splitting users into too many paid tiers

The product should compete on polish, automation, and convenience, not on
forcing users into a high-price subscription.

Pricing should also reflect V1 infrastructure reality:

- V1 uses local-first storage and iCloud/CloudKit sync.
- V1 does not require a custom Nastart cloud server for multi-device sync.
- Lower recurring infrastructure cost allows lower consumer-friendly pricing.
- If a future Nastart Cloud creates real server cost, pricing should be
  reviewed before promising that server-backed functionality under lifetime
  purchases.

Detailed cost-control assumptions are tracked in
`docs/project/COST_BREAKDOWN.md`.

## 2. Competitive Reference

Public App Store information shows nearby tools using low consumer pricing:

| App | Monthly | Annual | Lifetime |
|---|---:|---:|---:|
| DS One | USD 0.99 | USD 7.99 | USD 9.99 |
| MyServers | USD 0.99 | USD 4.99 | USD 14.99 |

These references suggest Nastart should not launch with aggressive pricing.

## 3. Recommended V1 Price Direction

Recommended US storefront candidates:

| Product | Candidate Price | Notes |
|---|---:|---|
| Nastart Plus Monthly | USD 0.99 | Low-friction trial path |
| Nastart Plus Annual | USD 7.99 or USD 9.99 | Main recommended plan |
| Nastart Plus Lifetime | USD 14.99 | Good for NAS users who dislike subscriptions |

Recommended China storefront candidates:

| Product | Candidate Price | Notes |
|---|---:|---|
| Nastart Plus Monthly | CNY 6 or CNY 8 | Keep impulse-friendly |
| Nastart Plus Annual | CNY 38 or CNY 48 | Main recommended plan |
| Nastart Plus Lifetime | CNY 88 or CNY 98 | Launch-friendly lifetime unlock |

Final storefront prices should be selected in App Store Connect using Apple's
available price points and localized price matrix.

## 4. Free Version Boundary

The free version should prove the product value.

Free should be useful, but it should not cover the complete power-user
workflow. The goal is:

```text
free = enough to trust Nastart
Plus = enough to make Nastart the user's daily NAS home base
```

Recommended Free scope:

- 1 NAS
- basic Synology DSM connection
- basic automatic service discovery
- limited Launchpad cards
- one built-in default theme
- basic service opening
- limited reminders
- local-only data
- basic media library browsing and system playback where feasible
- external app handoff with default behavior

The free version should not feel broken. It should feel useful enough that Plus
is a natural upgrade.

Recommended v1 free limits to evaluate during prototype:

- 1 NAS.
- Up to 10 Launchpad cards.
- Up to 3 active manual reminders/tasks.
- One built-in Launchpad theme plus standard card density.
- Local-only layout without iCloud/CloudKit sync.
- Basic media browsing and system playback where feasible.
- Default external app handoff without per-service advanced preferences.
- No custom Launchpad backgrounds in v1.

These limits should be tuned after TestFlight feedback. If free conversion is
low but retention is high, tighten convenience limits before removing core
local functionality.

## 5. Nastart Plus Boundary

Nastart Plus should unlock convenience and depth:

- multiple NAS devices
- more or unlimited Launchpad cards
- all built-in themes
- iCloud/CloudKit sync
- advanced discovery and card generation
- external app handoff preferences
- advanced playback and external player preferences
- widgets when available
- richer diagnostics
- more reminders
- certificate and subscription lifecycle tracking enhancements
- custom Launchpad backgrounds when the feature ships

Nastart Plus should remain a single user-facing tier. Do not create separate
Pro, Cloud, Theme, or Media tiers in V1.

## 6. Lifetime Purchase Policy

A lifetime purchase is recommended for V1 because:

- this category has many price-sensitive technical users
- NAS users often prefer owning tools
- V1 primarily uses local and iCloud/CloudKit features rather than a custom
  server with direct recurring infrastructure cost

If a future Nastart Cloud server adds meaningful recurring cost, the lifetime
promise should be reviewed carefully before launch. One safe policy is:

- lifetime includes local Plus and iCloud/CloudKit Plus features
- future custom-server Cloud features may require a separate evaluation before
  being included

Do not promise unlimited future server-backed services unless the cost model is
clear.

## 7. Launch Pricing

Recommended launch approach:

- launch with a low annual price and a friendly lifetime unlock
- avoid weekly subscriptions
- optionally run an early supporter lifetime price for the first release window
- keep monthly pricing mainly as a low-friction testing path

Suggested launch positioning:

```text
Free to start. Upgrade to Nastart Plus when you want more NAS devices,
beautiful themes, iCloud sync, reminders, and advanced automation.
```

## 8. Pricing Review Triggers

Review pricing when:

- custom Nastart Cloud becomes real
- Agent support creates meaningful support burden
- media service integration becomes a major paid feature
- App Store reviews complain about the free boundary
- conversion is low despite strong retention
- support cost per paid user rises

Pricing should be adjusted with care. Raising prices too early can make the app
feel out of proportion to the NAS hobbyist market.
