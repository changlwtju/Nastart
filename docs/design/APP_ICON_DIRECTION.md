# Nastart App Icon Direction

Version: 0.1
Status: Draft
Last updated: 2026-07-27

## 1. Purpose

This document defines the first direction for the Nastart app icon.

The icon should communicate NAS plus start/launch in one simple mark. It should
feel clear, premium, and recognizable at small iOS sizes without becoming a
literal server illustration.

## 2. Design Inputs

Nastart combines two ideas:

- NAS: storage, home server, private infrastructure, local services
- Start: boot, open, launch, enter, begin, quick access

The icon should also fit the app's UI style:

- white or near-white app shell
- black text
- black monochrome utility icons
- warm accent only for important emphasis
- simple Apple-native visual language

## 3. Competitive Reference

Competitor references should guide category recognition, not visual copying.

Observed reference directions from public App Store listings and NAS/server app
categories:

- Synology official apps often use clean, simple, product-specific symbols.
- DS One is media/NAS-oriented and should be treated as a quality benchmark for
  independent NAS-app polish.
- MyServers is more server/operations-oriented and reinforces that monitoring
  apps often use technical symbols, status, and server/device metaphors.

Nastart should avoid looking like a generic SSH/server manager. It should feel
more like a NAS launchpad.

## 4. Recommended Primary Concept

### 4.1 NAS Launch Mark

Primary concept:

```text
A compact NAS device/block
+ a start/play/launch cut
+ one warm status light
```

Visual idea:

- A centered rounded NAS block or compact drive-bay shape.
- Two or three simple horizontal bay lines to imply storage.
- A right-facing start/play triangle or launch notch integrated into the body,
  preferably using negative space.
- One small warm amber status dot to imply powered-on/ready.
- Avoid detailed screws, vents, cables, rack rails, screen reflections, or
  realistic hardware.

Why this should be the default direction:

- It reads as NAS without needing text.
- The start/play language expresses "Nastart" directly.
- It is compact enough for an iOS icon.
- It can support monochrome rendering in the app and richer rendering as the
  App Store icon.
- It avoids the overused `</>` code-symbol direction and keeps the product
  focused on NAS users.

## 5. Secondary Concepts

### 5.1 Power Bay

Visual idea:

- NAS block with a power symbol integrated into the front panel.
- Amber power indicator as the only accent.

Pros:

- Very easy to understand as "turn on / start".
- Simple at small sizes.

Risk:

- Power symbols are common and can feel generic.

### 5.2 Launch Grid

Visual idea:

- Four rounded service tiles with one tile shaped as a play/launch arrow.
- Small status dot or highlight.

Pros:

- Communicates Launchpad and service cards.
- Matches the product's unique dashboard direction.

Risk:

- It may not clearly communicate NAS by itself.

### 5.3 NAS Compass

Visual idea:

- Abstract NAS block combined with a subtle upward/right launch arrow.

Pros:

- Communicates navigation and starting a journey.

Risk:

- Arrow/compass language can become startup-app generic if the NAS shape is not
  strong enough.

## 6. Recommended Color Direction

App icon should stay close to the app shell's restrained style, but it can use a
slightly richer surface than the in-app UI.

Recommended starting palette:

| Role | Direction |
|---|---|
| Background | off-white or very light warm gray |
| Main glyph | near black / graphite |
| Secondary depth | soft graphite or cool gray |
| Accent | warm amber-gold, around `#F4A340` |
| Dark mode variant | optional later, not required for App Store icon |

Avoid:

- heavy bronze backgrounds
- neon green dashboard colors
- blue-purple tech gradients
- realistic metallic server rendering
- too many color zones

## 7. Shape And Rendering Rules

Apple app icons should be unique, memorable, and recognizable at a glance. The
icon should therefore follow these rules:

- One primary object only.
- Strong silhouette.
- No text.
- No tiny details.
- No transparency in final App Store assets.
- No fake iPhone or UI screenshot inside the icon.
- Test at small sizes before choosing a direction.
- Keep a vector master, then export required raster sizes.

Recommended master:

- 1024 x 1024 square artboard.
- Icon design should respect iOS rounded-corner masking.
- Main mark should fit comfortably inside the safe area.

## 8. First Draft Brief

Generate three icon drafts before choosing the final mark:

1. NAS Launch Mark: compact NAS block with integrated play/start cut and amber
   status light.
2. Power Bay: compact NAS block with integrated power/start symbol.
3. Launch Grid: four service-card tiles with one tile as the start tile.

Preferred candidate after current discussion:

```text
NAS Launch Mark
```

This direction best combines NAS recognition with the start/launch idea while
remaining simple enough for a premium iOS utility icon.

## 9. Rejection Criteria

Reject an icon draft if:

- it reads as a generic media player only
- it reads as a generic server rack only
- it reads as a coding app rather than NAS/HomeLab
- it needs text to explain the concept
- it contains too many small lines
- it looks like a web-dashboard favicon
- it becomes unclear at 60 x 60 points

## 10. Next Step

Before implementation, produce low-fidelity icon drafts in SVG or a design tool,
then compare them at:

- 1024 x 1024
- App Store listing size
- iPhone home screen size
- Settings/search small icon size
- dark and light wallpapers
