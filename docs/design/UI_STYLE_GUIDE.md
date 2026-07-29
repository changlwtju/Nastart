# Nastart UI Style Guide

Version: 0.3
Status: Draft
Last updated: 2026-07-30

## 1. Purpose

This document defines the first visual direction for Nastart's app shell,
typography, colors, icons, cards, and interaction patterns.

The goal is to make Nastart feel Apple-native, calm, precise, and premium
without becoming visually heavy or hard to implement.

Launchpad themes may change the dashboard expression, but the app shell should
remain stable and recognizable.

The Launchpad is Nastart's primary visual showcase. It can carry more crafted
layout, material, and card personality than fixed utility pages, but it must
still share the same typography, icon language, color semantics, spacing rhythm,
and interaction patterns as the rest of the app.

## 2. Product Feeling

Nastart should feel like:

- a native Apple utility
- a refined NAS home base
- a personal infrastructure launchpad
- technical enough to be trusted
- simple enough to be used every day

Nastart should not feel like:

- a web admin panel squeezed into a phone
- a terminal-first server tool
- a media app clone
- a colorful dashboard skin collection
- a stitched bundle of unrelated utilities

Core visual principle:

```text
Simple, useful, designed; never plain, noisy, or over-explained.
```

Chinese product motto:

```text
简约而不简单
```

Meaning:

- top-level pages should feel clean, calm, and immediately understandable
- deeper pages can hold richer configuration and technical detail
- the app should feel capable without looking complicated
- richness should be discovered progressively, not dumped on first sight

Nastart should pass this product-level UI test:

```text
One glance attracts.
Two glances explain.
Three glances invite action.
```

The UI should communicate through hierarchy, spacing, symbols, status color,
cards, and interaction states before relying on explanatory text.

This principle also applies to implementation and app footprint. Nastart should
cover useful NAS workflows without becoming bloated in installed size or runtime
complexity. Prefer compact native SwiftUI views, SF Symbols, vector assets, and
shared components before adding raster-heavy visuals, large dependencies, or
duplicated custom UI.

Every feature should pass this product-and-engineering test:

```text
Does it add clear user value without making the app feel heavier, harder to use,
or unnecessarily larger to install?
```

If the answer is unclear, simplify the UI first, defer nonessential assets, and
place advanced capability one level deeper.

Top-level pages should follow this rule:

```text
Show the purpose, show the state, show the next action.
Hide everything else one level deeper.
```

For Launchpad specifically, "simple" must not become "ordinary". A plain grid of
service icons is too weak for Nastart's core selling point. The Launchpad should
feel designed through:

- an intentional top status area, not a generic header
- service grouping that feels curated rather than dumped
- cards with clear hierarchy between identity, state, and next action
- richer media cards that still belong to the same card family
- progressive detail for Agent/Plus without fragmenting the layout
- empty space used for calmness, not because the page lacks content strategy

The design target is:

```text
Launchpad should look simple at first glance, useful at second glance, and
crafted at third glance.
```

## 3. App Shell Style

The app shell covers:

- onboarding
- tabs and sidebar
- device center
- reminder center
- settings
- forms
- warning sheets
- purchase screens
- support and privacy pages

The shell should be consistent across themes:

- native navigation bars
- system tab/sidebar patterns
- white or system background as the default surface
- limited accent colors
- simple list and card layouts
- SF Symbols as the primary icon language
- no decorative background illustrations in core utility pages

Launchpad themes can vary card style and information density, but they should
not change core typography, settings layout, purchase UI, or security flows.

The fixed pages should be deliberately quieter than the Launchpad:

- Onboarding, Devices, Tasks, Mine, Settings, and purchase pages should
  look Apple-native and restrained.
- Launchpad should be the most expressive surface, but it should not introduce
  a separate visual system.
- Shared tokens should make the Launchpad feel like a premium expression of
  the same app, not a separate skin.

The recommended baseline should be close to WeChat-style restraint:

- white background first
- black or near-black text first
- black monochrome vector icons for most navigation and utility actions
- color only for selected state, warning, success, danger, Plus, or primary
  action
- no ornamental gradients, noisy backgrounds, or over-designed widgets in the
  app shell

## 4. Typography

Use Apple's system typefaces through SwiftUI dynamic type styles.

Recommended mapping:

| Use | SwiftUI Style | Weight | Notes |
|---|---|---|---|
| Large page title | `.largeTitle` or `.title` | Semibold/Bold | Use sparingly; not every screen needs a large title |
| Navigation title | `.headline` or native nav title | Semibold | Let system navigation do most work |
| Section title | `.headline` | Semibold | Short, direct labels |
| Card title | `.headline` or `.subheadline` | Semibold | Avoid truncating service names too early |
| Body text | `.body` or `.callout` | Regular | Keep paragraphs short |
| Metadata | `.caption` or `.footnote` | Regular/Medium | Use enough contrast |
| Status label | `.caption` | Medium | Pair with status dot/icon |
| Button text | `.body` or `.callout` | Semibold | Clear action verbs |

Rules:

- Prefer system Dynamic Type instead of fixed point sizes.
- Avoid long explanatory paragraphs in primary flows.
- Use sentence-style labels, not marketing slogans.
- Use metadata only where it helps scanning.
- Do not rely on light gray text for important content.
- Prefer short labels and structured choices over full-sentence explanations.
- Use one-line helper text only when a technical concept would otherwise be
  unclear.

### 4.1 Copy Density

Every primary screen should pass this scan test:

- The user can identify the screen purpose in one glance.
- The primary action is visible without reading a paragraph.
- No card requires more than one short line of explanation.
- Technical terms are shown as labels, chips, or status values where possible.

Avoid:

- multi-line teaching text on dashboards
- long feature descriptions inside cards
- repeated "why this matters" copy
- putting setup instructions on everyday-use screens

## 5. Color System

Nastart should use a calm neutral base with a warm accent.

### 5.1 Core Roles

| Role | Direction | Use |
|---|---|---|
| Background | White / system background | Main app pages |
| Grouped background | Very light system grouped background | Long lists, grouped settings, secondary surfaces |
| Surface | White or system secondary background | Cards, panels, form groups |
| Primary text | Near black in light mode, near white in dark mode | Main content |
| Secondary text | Medium gray with sufficient contrast | Metadata only |
| Separator | System separator | Dividers and grouped lists |
| Accent | Warm amber/gold-orange | Primary actions, selected state, Plus |
| Success | System green | Online and healthy |
| Warning | System orange/amber | Certificate/domain/backup warnings |
| Error | System red | Offline, expired, dangerous |
| Info | System blue | Links, neutral guidance, learn more |

### 5.2 Accent Guidance

The accent should feel warm and premium, closer to App Store service buttons
than dark bronze.

Recommended starting accents:

- Light mode accent: `#F4A340`
- Pressed accent: `#E98D26`
- Soft accent background: `#FFF3E2`
- Dark mode accent: `#FFB35A`

Rules:

- Accent is for primary action and selected state, not general decoration.
- Status colors should remain semantic and separate from brand accent.
- Avoid using the warm accent for every icon.
- Default icons should be black/near-black, especially in tabs, lists, toolbars,
  and settings.
- Do not make the whole app brown, orange, or sepia.
- If a card uses a theme-specific tint, keep text and controls legible first.

## 6. Icon System

Primary icon source:

- SF Symbols.

Use custom icons only when:

- SF Symbols cannot represent the service clearly.
- The icon is a generated service/app icon.
- A known service brand icon is legally safe and locally bundled.

Icon rules:

- App shell icons should use consistent stroke weight and optical size.
- Use monochrome icons for tabs, lists, settings, and toolbar actions.
- Use filled or multicolor icons only for service logos/cards where they add
  recognition.
- Do not mix several icon packs in one screen.
- Do not use complex vector illustrations for basic navigation.
- Use color on icons only when it communicates state or selected action.

Recommended tab symbols:

| Tab | SF Symbol Direction |
|---|---|
| Launchpad | `square.grid.2x2` / `rectangle.grid.2x2` |
| Devices | `externaldrive` / `server.rack` where available |
| Tasks | `bell.badge` / `calendar.badge.clock` |
| Mine | `person.crop.circle` plus settings rows, or `gearshape` if account is not central |

## 7. Card System

Nastart should use cards for meaningful repeated objects:

- service cards
- device cards
- reminder cards
- certificate/domain cards
- media resource cards

Do not wrap page sections in decorative cards unless they represent grouped
interactive content.

Cards should use design language instead of text-heavy explanation:

- icon or service logo for identity
- title for object name
- small status dot or badge for state
- one metadata line for context
- one primary tap behavior
- secondary actions behind menu or long press

### 7.1 Service Card Anatomy

Required elements:

- service icon
- service name
- short category or service type
- status indicator
- primary action through tap

Optional elements:

- endpoint label: Local, Remote, VPN
- latency or last checked time
- certificate warning
- container state
- secondary action menu

Avoid:

- long descriptions
- more than two visible metrics on compact cards
- multiple competing action buttons
- dense technical names unless the user expanded details
- decorative badges that do not change user behavior
- explaining what a common icon already communicates

### 7.4 Progressive Detail

Nastart should use three layers of information:

| Layer | Where | Content |
|---|---|---|
| Glance | Launchpad card, device card, reminder card | Name, icon, state, one hint |
| Decision | Detail page | Endpoint, warning reason, related device/container, action choices |
| Explanation | Sheet, help page, diagnostics | Technical cause, next steps, logs, advanced settings |

The first layer must stay quiet. The third layer can be technical, but only when
the user has intentionally opened it.

## 8. Launchpad Versus Fixed Pages

Nastart needs a clear visual hierarchy between its showcase surface and its
everyday utility pages.

### 8.1 Fixed Pages

Fixed pages should feel clear, native, and dependable:

- mostly white or system grouped backgrounds
- simple navigation titles
- grouped lists and plain cards
- black SF Symbols-style icons
- short labels and status values
- minimal decoration
- no custom theme backgrounds

These pages earn trust through restraint and consistency.

### 8.2 Launchpad

Launchpad should feel more crafted:

- stronger card composition
- richer service identity
- more considered section rhythm
- optional material/depth per theme
- clear online, warning, and unavailable states
- polished empty and first-success states
- visually satisfying layouts at 6, 12, and 24 services

The Launchpad may be beautiful, but it must remain operational. If a visual
choice makes service status, endpoint choice, warning state, or tap behavior
less clear, it should be removed.

### 8.3 Shared Design Tokens

Use shared tokens to prevent visual fragmentation:

- text styles
- foreground and secondary text colors
- accent and semantic status colors
- icon stroke weight
- radius scale
- spacing scale
- separator color
- card padding
- sheet and menu behavior

Launchpad themes should be variations on these tokens, not separate one-off
styles.

### 7.2 Device Card Anatomy

Required elements:

- device name
- provider type, such as Synology DSM
- connection status
- short resource summary

Optional elements:

- DSM version
- local/remote endpoint hint
- Agent connected state
- warning count

### 7.3 Reminder Card Anatomy

Required elements:

- reminder name
- type
- due date
- urgency state

Optional elements:

- related service/device/domain
- renew URL
- notification schedule

## 8. Layout Principles

### 8.1 iPhone

- Use tab navigation.
- Use one primary task per screen.
- Keep forms grouped and short.
- Put destructive or advanced operations behind detail screens.
- Use context menus and bottom sheets for secondary card actions.
- Keep Launchpad cards thumb-friendly.

### 8.2 iPad

- Use sidebar or split view.
- Avoid simply stretching iPhone screens.
- Show Launchpad grid and device/status panels side by side where useful.
- Use inspector/detail panes for service and device details.

### 8.3 Future macOS

- Keep components resizable.
- Support pointer hover, keyboard shortcuts, and denser layouts later.
- Do not hard-code iPhone-only assumptions into core Launchpad components.

### 8.4 Future Apple TV

- Treat Apple TV as a future status-wall and media-handoff surface.
- Cards must support focus state and large viewing distance.
- Avoid tiny metadata on tvOS layouts.

## 9. Buttons And Controls

Primary button:

- warm accent background
- white or high-contrast text
- semibold label
- used once per screen when possible

Secondary button:

- system filled or grouped background
- primary text color
- used for cancel, edit, preview, or alternate path

Destructive button:

- red text or red background only when the action is clearly destructive

Selection chips:

- use for categories, filters, endpoints, reminder types, and themes
- selected state can use soft accent background and accent text

Menus:

- use for card secondary actions
- avoid showing every external app on the primary screen

Sheets:

- use for endpoint warnings, certificate trust, open-in choice, and Agent setup
  guidance

## 9.1 Functional Discoverability

Users should understand what Nastart can do without a long introduction.

Use these patterns:

- Tab names for major jobs.
- Section headers for object groups.
- Cards for services, devices, and reminders.
- Status dots and chips for state.
- Context menus for secondary actions.
- Empty states with one action.
- Settings rows for preferences.

Avoid these patterns:

- large onboarding slides for features users have not tried
- dashboard banners explaining every module
- repeated callouts competing with the service cards
- icon-only controls without native labels, tooltips, or accessible names

## 10. Motion And Feedback

Motion should be restrained:

- subtle card press scale or highlight
- smooth sheet presentation
- refresh progress where status checks run
- small status transition animations

Avoid:

- decorative looping animations
- busy dashboard effects
- motion that makes service state harder to read

## 11. Empty, Loading, And Error States

Text should be short and action-oriented.

Examples:

- No services yet. Connect Synology DSM to generate your launchpad.
- Certificate expires soon.
- Local address is unreachable. Try remote address?
- Agent is offline.

Rules:

- Avoid long teaching paragraphs.
- Provide one primary next action.
- Offer "Learn more" only when the issue is genuinely technical.

## 12. Plus And Paywall Style

Plus should feel like a natural unlock, not a hard wall.

Recommended:

- show value in context
- keep Free useful
- label Plus-only features quietly
- annual plan as recommended
- lifetime as a NAS-user-friendly option if pricing allows

Plus visual style:

- warm accent
- simple comparison rows
- no aggressive countdowns
- no overloaded pricing page

## 13. Design Token Candidates

These are starting points, not final values:

| Token | Value Direction |
|---|---|
| Card corner radius | 16-22 on iOS, slightly less on dense layouts |
| Card padding | 12-18 |
| Section spacing | 20-28 |
| Compact grid gap | 10-14 |
| Wide grid gap | 14-20 |
| Icon size compact | 24-32 |
| Service icon size | 36-48 |
| Status dot | 7-9 |

The token system should be implemented once and reused across themes.

## 14. Quality Checklist

Before a UI direction becomes implementation-ready:

- Screens work in light and dark mode.
- Primary text has strong contrast.
- Icons look like one family.
- Every screen has one obvious primary action.
- Long service names and IP addresses do not break layout.
- The Launchpad looks good with demo, real, sparse, and dense data.
- iPad layouts are intentionally designed.
- The design still feels usable without decorative backgrounds.

## 15. Screenshot Reference Notes

These notes come from user-provided screenshots of DS One and MyServers. They
are design observations, not instructions to copy either product.

### 15.1 DS One Lessons

Useful patterns:

- The home page uses a light background, rounded cards, clear NAS status cards,
  and a simple icon grid. This makes technical NAS data feel approachable.
- The bottom tab bar uses large, readable icons with direct labels.
- The media page shows that immersive image-led surfaces can work well for
  media, but this should stay limited to media contexts.
- The settings page uses grouped rows, monochrome outline icons, and short row
  labels. This is a strong reference for Nastart's Mine/Settings pages.
- The card spacing is generous enough that the app feels calm rather than like
  a dense admin panel.

Risks to avoid:

- Do not let Nastart's Launchpad become a media-app home page.
- Do not use many colored square icons unless the icon style is tightly
  controlled.
- Do not add top-level Video, Audio, and Album tabs in Nastart v1; those belong
  inside media service cards and handoff flows.

### 15.2 MyServers Lessons

Useful patterns:

- The tab split between dashboard, board, servers, terminal, and settings shows
  a clear operations-oriented mental model.
- The board page proves that status widgets can be powerful when the user wants
  monitoring density.
- The settings page uses large title, grouped sections, toggles, and clear
  system-style rows.

Risks to avoid:

- Nastart should not expose terminal as a first-level tab in v1.
- Monitoring cards should not overwhelm the Launchpad.
- The app should avoid showing too many gauges, counters, and technical labels
  on the first screen.
- Plus/paywall cards should be cleaner and more restrained, with less visual
  weight unless the user has intentionally opened Plus.

### 15.3 Nastart Adaptation

Recommended adaptation:

- Use DS One's softness and approachable card spacing as the baseline.
- Use MyServers' dashboard discipline only for the `Command Center` Launchpad
  theme and Device Detail pages.
- Keep Nastart's main app shell closer to white-background, black-text,
  monochrome-icon utility design.
- Let color appear mainly through status, selected tab, primary actions, service
  logos, and theme-specific Launchpad cards.
- Keep media imagery inside media surfaces; do not make the whole app poster-led
  or image-heavy.
