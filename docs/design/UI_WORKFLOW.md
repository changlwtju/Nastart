# Nastart UI Workflow

Version: 0.2
Status: Draft
Last updated: 2026-07-27

## 1. Purpose

This document defines the required workflow for Nastart UI design and
implementation.

Nastart should not jump directly from ideas to polished mockups or code. The app
has many small features, so the UI must be designed through a staged process
that keeps complexity visible before visual polish begins.

## 2. Required Workflow

All major UI work should follow this sequence:

```text
Document IA / style
-> low-fidelity wireframes
-> imagegen high-fidelity visual references
-> select direction
-> SwiftUI interactive prototype
-> real-device testing
```

Chinese summary:

```text
文档确定 IA / 风格
-> 低保真线框图
-> imagegen 生成几版高保真视觉参考
-> 选定方向
-> 用 SwiftUI 做可交互原型
-> 真机调试
```

This sequence is mandatory for:

- onboarding
- Launchpad Dashboard
- media service flows
- device detail
- reminder center
- Plus/paywall
- settings
- iPad layouts
- major app icon direction

Small settings rows, error sheets, and minor detail screens can skip imagegen if
they follow existing design tokens and patterns.

Launchpad is the exception in the opposite direction: it must not skip any major
stage. Because it is Nastart's highest-priority visual showcase, each Launchpad
theme needs documented IA, low-fidelity layout exploration, high-fidelity visual
references, SwiftUI prototyping, and real-device review before it is considered
ready.

## 3. Stage 1: Document IA / Style

Goal:

- define what the screen does before deciding how it looks

Inputs:

- product requirements
- information architecture
- competitor observations
- user journey
- feature boundaries
- security constraints

Outputs:

- screen purpose
- entry points
- primary action
- secondary actions
- required states
- empty/loading/error states
- copy-density rules
- navigation and back behavior

Do not proceed to wireframes if:

- the screen has no clear primary action
- the same feature appears in two unrelated tabs
- a flow depends on an undefined API or permission model
- failure states are not considered

## 4. Stage 2: Low-Fidelity Wireframes

Goal:

- prove layout and flow without being distracted by visual style

Wireframes should be grayscale and simple:

- boxes
- labels
- card slots
- tab/sidebar structure
- navigation arrows
- sheet positions

Required wireframe variants:

- iPhone compact
- iPad regular
- empty state
- populated state
- warning/error state

Wireframes must include critical subpages and hidden actions, not only top-level
tabs:

- Launchpad card detail and long-press menu.
- DSM card path to Device Detail.
- Media Service Detail, resource list, resource detail, basic playback, and
  external app fallback.
- Device Detail, resource status drill-down, and file browsing path.
- Tasks list, task detail, and postpone/ignore/complete actions.
- Mine first level plus the second-level setting groups.
- Plus sheet shown from at least one natural locked feature.

For Launchpad themes, compare:

- one-column versus two-column iPhone cards
- compact grid versus status-dense cards
- top status strip versus side panel
- category-first versus favorite-first grouping

## 5. Stage 3: Imagegen High-Fidelity Visual References

Goal:

- explore mood, material, spacing, and card presentation quickly

Use imagegen for:

- high-fidelity visual references
- App Store screenshot mood
- Launchpad theme style exploration
- app icon concept exploration
- large visual direction comparison

Do not use imagegen as final UI source:

- generated text may be wrong
- exact spacing is not deterministic
- controls are not reusable components
- accessibility and Dynamic Type cannot be validated from a bitmap

Imagegen output should be treated as reference only. Final UI must be rebuilt in
SwiftUI.

For Launchpad work, imagegen should be used to explore visual mood and card
composition, while Figma can be used to organize selected directions, spacing,
components, and design tokens when a Figma file is available. Neither replaces
SwiftUI implementation or real-device validation.

Recommended prompt constraints:

- iOS app UI mockup
- white/system background
- black text
- monochrome SF Symbols-style icons
- warm accent only for primary action/selected state
- no marketing hero page
- no decorative gradients or noisy backgrounds
- realistic iPhone and iPad layout
- concise labels, minimal paragraph text

## 6. Stage 4: Select Direction

Goal:

- decide what to implement

Selection criteria:

- user can identify screen purpose within one glance
- primary action is obvious
- text is minimal
- icons feel like one family
- status and warnings are clear
- layout works with sparse and dense data
- iPhone and iPad both feel intentional
- theme does not make the app shell feel like a different product

Only selected directions should become SwiftUI prototypes.

Launchpad direction selection should be stricter than ordinary pages:

- compare at least three distinct directions before locking v1 visual language
- reject directions that only look good with perfect sample data
- reject directions that cannot handle sparse, dense, warning, and offline
  states
- reject directions that feel visually disconnected from Devices, Reminders, or
  Mine
- reject directions that are merely a generic service launcher, bookmark grid,
  or mobile copy of a web dashboard
- prefer fewer themes with stronger layout systems over more themes with thin
  visual differences

Launchpad high-fidelity references should explore actual design language, not
only color or shadow changes. Each direction should make a different choice
about card hierarchy, grouping, status expression, and progressive detail while
still using the same underlying information model.

## 7. Stage 5: SwiftUI Interactive Prototype

Goal:

- test the real interaction, navigation, Dynamic Type, and state changes

Prototype should include:

- real navigation stacks
- tab/sidebar behavior
- fake but structured data
- populated and empty states
- loading and failure states
- context menus or sheets
- dark mode check where feasible
- iPhone and iPad previews

Prototype should avoid:

- hard-coded screenshots as UI
- fake text-heavy explanations
- one-off components that ignore design tokens
- final API dependency before interaction is proven

## 8. Stage 6: Real-Device Testing

Goal:

- confirm that the design works on the devices users will actually hold

Initial device checks should include:

- iPhone 13 on iOS 16
- iPad 9th generation on current supported iPadOS
- future Apple TV layout only as component planning, not v1 requirement
- MacBook Air for Xcode development and future macOS thinking

Check:

- tap targets
- readability
- Dynamic Type
- long service names
- local IP/domain strings
- dark mode
- network failure states
- one-handed use on iPhone
- iPad split layout

For Launchpad specifically, real-device testing should include:

- 6, 12, and 24 service data sets
- long service names and mixed Chinese/English labels
- local IP, domain, and port strings
- online, offline, warning, and certificate-expiring states
- light and dark mode
- Dynamic Type larger text sizes
- one-handed iPhone use
- iPad landscape layout

## 9. Design Freeze Rule

Before implementation of any major screen, create a short design freeze note:

- chosen layout
- chosen visual direction
- key interactions
- known compromises
- deferred ideas

This prevents endless redesign during coding.

## 10. Current Priority

Do not generate first full UI mockups yet.

Before mockups, finish flow-level detail for:

- DSM first connection
- Discovery Review
- Launchpad card anatomy
- Launchpad theme layout variants
- Media Service Detail and Jellyfin/Emby/Navidrome connection
- Device Detail and health sections
- Reminder creation and alert states
- Plus unlock moments
- Settings and external app defaults

After these are clear, create low-fidelity wireframes first.
