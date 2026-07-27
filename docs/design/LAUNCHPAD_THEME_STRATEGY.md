# Nastart Launchpad Theme Strategy

## 1. Principle

Nastart's launchpad themes should prioritize quality over quantity.

V1 should not ship many superficial skins. It should ship a small number of
polished themes that feel native, useful, and worthy of being a core selling
point.

The Launchpad is the highest-priority UI surface in Nastart. It is the screen
that should make users feel the app is worth keeping before they fully
understand every feature. Other pages can be simpler and more system-native,
but the Launchpad must feel deliberately designed, visually refined, and
immediately useful.

The launchpad is also Nastart's main differentiation against DS One and
MyServers. DS One can be stronger at built-in media playback, and MyServers can
be stronger at broad server administration. Nastart must therefore make the
launchpad feel clearly more intentional than a bookmark grid or a monitoring
list.

The Launchpad must not settle for being a generic app launcher, link directory,
or ordinary HomePage-style mobile clone. Low-fidelity wireframes can use simple
boxes to test structure, but the final direction must add a distinct Nastart
design language through hierarchy, grouping, card rhythm, status expression,
progressive detail, and platform-native interaction. If a candidate Launchpad
could be mistaken for a normal bookmark grid with NAS icons, it is not strong
enough.

The theme system should serve three goals:

- make automatically discovered NAS services feel organized and beautiful
- adapt to different Apple platform sizes and interaction models
- prepare for future user-customizable dashboard design without turning V1 into
  a design-tool project

Launchpad quality target:

```text
First glance: the app feels polished.
Second glance: services and status are understandable.
Third glance: the next action is obvious.
```

## 2. App Shell Versus Launchpad Themes

Nastart should have one stable app identity and multiple launchpad expressions.

The app shell should remain consistent across themes:

- tab/navigation structure
- onboarding and setup flow
- device detail pages
- reminder pages
- settings pages
- permission, warning, purchase, and security screens
- typography scale
- baseline spacing
- core icons
- core status language

Only the launchpad presentation should change by theme:

- card shape and density
- service grouping style
- card background material
- accent usage inside cards
- status visualization inside cards
- optional wallpaper/background treatment
- launchpad-specific header and summary panels

This prevents theme switching from making Nastart feel like three unrelated
apps. The product identity should be calm, native, and trustworthy; themes
should add personality only inside the dashboard surface.

### 2.1 Cohesion Contract

Launchpad themes must not break the rest of the app's design language.

Shared across Launchpad and fixed pages:

- typography scale and weight rules
- SF Symbols-style icon weight
- base foreground color and contrast
- warm accent color semantics
- status color semantics
- corner-radius scale
- card padding rhythm
- toolbar and sheet behavior
- context menu and long-press behavior
- empty, loading, offline, and warning states

Allowed to vary by Launchpad theme:

- service-card composition
- card density
- background material
- section presentation
- status visualization style
- header layout
- optional wallpaper or depth treatment

Not allowed:

- theme-specific fonts
- unrelated icon packs
- radically different tab/navigation styling
- decorative effects that reduce readability
- a Launchpad theme that makes Settings, Devices, or Reminders feel like a
  different app

If a theme requires changing the shell to look good, the theme direction is not
ready.

### 2.2 Launchpad Design Bar

Every candidate Launchpad direction must pass these design checks before it can
move into SwiftUI:

- It looks intentional with only 6 discovered services.
- It still feels organized with 24 discovered services.
- It can show at least three states: online, warning, and unavailable.
- It can show a certificate/domain warning without adding paragraph text.
- It supports a media service card and a plain web service card without visual
  imbalance.
- It supports long names, local IPs, domains, and port labels.
- It has a clear primary tap action and non-intrusive secondary actions.
- It works on iPhone first and has a real iPad layout, not a stretched phone
  grid.
- It can be rebuilt with SwiftUI components, not only as a beautiful bitmap.
- It feels like Nastart, not DS One, MyServers, Homepage, or a generic widget
  board.

## 3. V1 Theme Count

Recommended V1 count:

- 3 high-quality themes
- no theme marketplace
- no full drag-and-drop theme designer
- no unlimited user-created styles in the first release

Three excellent themes are more valuable than ten inconsistent ones.

## 4. Theme Selection Process

The first three themes should not be locked by name too early.

Recommended process:

1. Define the core launchpad layouts first.
2. Produce low-fidelity sketches for iPhone, iPad, and a future desktop/TV-like
   wide layout.
3. Test whether each layout communicates a clearly different use case.
4. Pick the three themes only after the sketches prove they are visually and
   functionally distinct.
5. Convert the selected directions into design tokens and SwiftUI components.

Low-fidelity sketches should compare:

- single-column versus two-column iPhone cards
- compact grid versus status-dense cards
- top status strip versus side status panel
- category-first versus favorite-first layout
- card actions visible on-card versus hidden behind context menu
- classic surface versus Liquid Glass-style presentation

Before any theme is considered shippable, it should pass these quality gates:

- The default screenshot should explain the product without marketing copy.
- A user should understand which services are online, warning, or unavailable in
  under three seconds.
- Cards should look generated-but-curated, not automatically dumped into a grid.
- The page should feel simple but not thin: every visible element must either
  help users open a service, understand NAS state, or discover a useful next
  action.
- The Launchpad should have a recognizable visual rhythm beyond evenly spaced
  boxes, while still avoiding decorative noise.
- Service quantity should affect scroll length and grouping, not produce a
  different product layout.
- Plus and Agent should enrich capability and information depth without making
  the free or DSM-only Launchpad feel like a second-class screen.
- The theme should still look good with 6, 12, and 24 services.
- The same service model should adapt cleanly to iPhone and iPad.
- No theme should rely on decorative effects that hide weak layout hierarchy.

## 5. Candidate V1 Themes

The following are candidate directions, not final locked names.

### 5.1 Clean Grid

Purpose:

- default theme
- calm, iOS-native, readable
- suitable for most users

Style:

- light background
- clear cards
- subtle dividers
- restrained accent color
- status dots and short labels
- minimal shadows

Best for:

- iPhone
- general users
- App Store screenshots that need to communicate clarity

### 5.2 Command Center

Purpose:

- information-dense operations view
- highlight NAS and service status

Style:

- compact cards
- grouped service sections
- visible latency, status, certificate, and container hints
- stronger typography hierarchy
- no terminal-style gimmicks

Best for:

- iPad
- macOS
- advanced HomeLab users

### 5.3 Glass Deck

Purpose:

- premium showcase theme
- visually align with iOS 26+ and the Liquid Glass direction

Style:

- layered surfaces
- translucent controls where the platform supports them
- strong content readability
- restrained background motion or depth
- glass effects used for hierarchy, not decoration

Best for:

- iOS 26+
- iPadOS 26+
- macOS 26+
- App Store visual marketing

## 6. Future Theme Directions

Future themes can be richer and more expressive after the first three built-in
themes are polished.

Possible later directions:

- Chinese / Guofeng theme
- cosmic or space theme
- playful cartoon theme
- retro terminal-inspired theme
- photography or wallpaper-led theme
- minimal monochrome theme

These should wait until the token system and core layouts are stable.

## 7. System Style Adaptation

Each theme should support two appearance branches:

- Classic: for iOS/iPadOS versions below 26 or environments where Liquid Glass
  APIs/materials are unavailable
- Liquid: for iOS/iPadOS/macOS/tvOS 26 and later, using system-supported glass
  materials and navigation patterns where available

The Liquid branch must not be a fake glass overlay. It should follow these
rules:

- keep text legible before visual effect
- use glass-like surfaces primarily for navigation, controls, and floating
  panels
- keep service cards content-first
- avoid stacking too many translucent layers
- provide a fallback when Reduce Transparency or accessibility settings are
  enabled

## 8. Platform Adaptation

### iPhone

V1 iPhone launchpad should be fast and thumb-friendly:

- one or two card columns depending on theme
- bottom-oriented primary actions
- short card text
- compact status hints
- long press or secondary menu for advanced actions

### iPad

iPad should not be a stretched iPhone layout:

- sidebar or split-view navigation
- wider grid
- optional inspector panel
- health and reminder summary beside service cards
- drag/reorder interactions when practical

### macOS

macOS is not required for the first App Store launch, but architecture should
prepare for it:

- resizable window layouts
- keyboard and pointer states
- denser Command Center theme
- menu commands for refresh, open, edit, and diagnostics

### Apple TV

Apple TV should be treated as a future status-wall target:

- large cards
- focus engine support
- read-only status dashboard first
- minimal text entry
- remote-friendly navigation

V1 does not need a tvOS app, but launchpad components should avoid assumptions
that make tvOS impossible later.

## 9. Minimum OS Baseline

Recommended platform baselines:

| Platform | Minimum OS | Role |
|---|---:|---|
| iPhone | iOS 16.0+ | V1 required |
| iPad | iPadOS 16.0+ | V1 required |
| Mac | macOS 14.0+ | Future P1 |
| Apple Watch | watchOS 9.0+ | Future P2 |
| Apple TV | tvOS 16.0+ | Future P3 |
| Apple Vision Pro | visionOS 2.0+ | Future P3 |

Liquid Glass-style presentation is an enhancement for systems that support it,
not the baseline requirement.

## 10. Theme Token Model

Themes should be built from design tokens, not ad hoc styling.

Required token groups:

- app shell tokens that never change per theme
- color palette
- typography scale
- spacing scale
- card radius
- card background style
- status color rules
- icon treatment
- density mode
- platform size-class rules
- material mode: solid, elevated, glass

This lets the team improve visual quality without rewriting every card.

Theme tokens should be separated into:

- global app tokens: shared by the entire app
- launchpad theme tokens: applied only to dashboard cards and launchpad surfaces
- platform tokens: size-class, pointer/focus, and device-specific adjustments

## 11. Customization Roadmap

### V1

- choose one of the built-in themes
- change themes from Mine / Settings -> Appearance -> Launchpad Theme
- preview theme before applying
- apply the selected theme only to the Launchpad Dashboard surface
- choose light/dark/system appearance
- choose card density where safe
- reorder cards and categories

### V1.5

- choose accent color
- choose card size presets
- show/hide card metadata
- choose background color or image
- save per-device layout preferences

### V2

- user-created theme presets
- export/import theme JSON
- advanced dashboard layout editing
- shared/community theme packs

## 12. Quality Bar

A theme is not ready unless it passes:

- iPhone compact layout review
- iPad split layout review
- light and dark appearance review
- accessibility contrast review
- long service-name wrapping review
- service-card density review
- empty/error/loading state review
- App Store screenshot review

The theme system is a core product surface. It should be treated as product
design, not decoration.
