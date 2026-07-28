# Nastart App Icon Direction

Version: 0.1
Status: Draft
Last updated: 2026-07-28

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

First SVG drafts have been added under `docs/design/app-icon/`.

V2 direction after review:

- Put the NAS hardware silhouette first.
- Use the power/start symbol as a restrained secondary detail.
- Avoid oversized play triangles and thick linework.
- Keep the composition simple enough for iOS home-screen size.
- Prefer refined product-icon rendering over dashboard/logo metaphors.

V3 refinement after comparing NAS companion app icon conventions:

- Use one centered NAS product mark as the primary object.
- Keep drive bays and power/start control visually separated.
- Avoid any overlap between the power button and bay/chassis elements.
- Lighten the chassis color; avoid heavy black blocks unless used as a
  background.
- Make the power/start symbol read as an integrated front-panel control rather
  than a large decorative symbol.

V2 candidates:

- `nastart-app-icon-v2-nas-power.svg`
- `nastart-app-icon-v2-drive-start.svg`
- `nastart-app-icon-v2-slim-bay.svg`

V3 candidates:

- `nastart-app-icon-v3-silver-nas.svg`
- `nastart-app-icon-v3-soft-panel.svg`
- `nastart-app-icon-v3-line-nas.svg`

V4 direction:

- Build from the `Silver NAS` direction, but add a Nastart-specific memory
  point.
- Let drive bays and a restrained startup light rail imply an abstract `N`.
- Keep the mark recognizable as a NAS first, then readable as "start".
- Avoid making the power button the primary symbol, because generic power icons
  are common across utilities.

V4 candidates:

- `nastart-app-icon-v4-n-bay.svg`
- `nastart-app-icon-v4-lightrail.svg`
- `nastart-app-icon-v4-monolith.svg`

V3.1 direction after review:

- Return to the original `V3 Silver NAS` frame.
- Keep the recognizable NAS chassis, bay structure, and small front-panel power
  control.
- Do not force an `N` symbol into the composition.
- Tune the color system instead of changing the structure: lighter chassis,
  softer amber power control, muted sage green status light, and warmer amber
  secondary status light.

V3.1 candidates:

- `nastart-app-icon-v3-1-silver-nas-soft.svg`
- `nastart-app-icon-v3-1-silver-nas-depth.svg`

V3.2 direction:

- Keep the `V3.1 Silver NAS` frame.
- Reduce the visual weight of the power button.
- Treat the power button and status lights as controls on the NAS front panel,
  not decorative symbols floating beside the bay.
- Use muted sage green and warm amber status colors instead of bright indicator
  lights.

V3.2 candidates:

- `nastart-app-icon-v3-2-silver-nas-panel.svg`
- `nastart-app-icon-v3-2-silver-nas-subtle.svg`

V3.3 direction:

- Keep the front-panel power/status controls from V3.2.
- Use equal-width drive bays so the NAS reads as a refined storage product
  instead of an irregular symbol.
- Reserve visual variation for spacing, opacity, and control placement rather
  than inconsistent bay widths.

V3.3 candidates:

- `nastart-app-icon-v3-3-silver-nas-equal-bays.svg`
- `nastart-app-icon-v3-3-silver-nas-equal-panel.svg`

V3.4 direction:

- Keep equal-width drive bays and the embedded front-panel controls.
- Soften the inner bay from near-black to layered dark gray.
- Preserve the outer shell, recessed bay, drive tray, and control hierarchy.
- Make the dark area read as a recessed front bay instead of another chassis.

V3.4 candidates:

- `nastart-app-icon-v3-4-silver-nas-soft-bay.svg`
- `nastart-app-icon-v3-4-silver-nas-recessed.svg`

V3.5 direction:

- Continue from `V3.4 Recessed`.
- Keep the stronger product hierarchy while reducing the outer recess contrast.
- Preserve the recessed bay feeling without making the front panel look busy.
- Add only minimal chassis polish if it improves premium feel at small sizes.

V3.5 candidates:

- `nastart-app-icon-v3-5-silver-nas-recessed-soft.svg`
- `nastart-app-icon-v3-5-silver-nas-recessed-polished.svg`

V3.6 direction:

- Keep the V3.5 recessed structure.
- Improve the outer chassis silhouette so the icon does not require the eye to
  search for the case boundary.
- Reduce visual fatigue by slightly lowering inner gray-step vibration.
- Add contour clarity with a restrained edge and shadow, not a heavy outline.

V3.6 candidates:

- `nastart-app-icon-v3-6-silver-nas-recessed-balanced.svg`
- `nastart-app-icon-v3-6-silver-nas-recessed-clear.svg`

V3.7 direction:

- Stop relying on adjacent warm-gray layers to define the chassis.
- Reduce the number of gray surfaces so the icon does not feel misregistered or
  visually fatiguing.
- Separate background, chassis, and bay with clearer contrast.
- Keep the equal drive bays and subtle front-panel controls from the strongest
  previous versions.

V3.7 candidates:

- `nastart-app-icon-v3-7-silver-nas-slate-backdrop.svg`
- `nastart-app-icon-v3-7-silver-nas-crisp.svg`
- `nastart-app-icon-v3-7-silver-nas-porcelain.svg`

V3.8 direction:

- Use `V3.7 Porcelain` as the base because it is visually calmer.
- Reduce nested surfaces; an app icon does not need to behave like a product
  render.
- Keep only the essential layers: background, chassis, front bay, drive trays,
  and small controls.
- Remove small tray ticks and close gray-on-gray surfaces that create eye strain.

V3.8 candidates:

- `nastart-app-icon-v3-8-silver-nas-porcelain-simple.svg`
- `nastart-app-icon-v3-8-silver-nas-porcelain-flat-bay.svg`

V3.9 direction:

- Use `V3.7 Porcelain` as the base, but remove the outer rounded background
  from the visual concept.
- Treat the NAS chassis itself as the app icon's core mark.
- Avoid unnecessary background/chassis nesting when the chassis already provides
  enough silhouette.
- Keep a non-transparent soft-ground export for final iOS AppIcon packaging,
  because App Store icons should be opaque.

V3.9 candidates:

- `nastart-app-icon-v3-9-silver-nas-core.svg`
- `nastart-app-icon-v3-9-silver-nas-core-soft-ground.svg`

Current preferred direction:

```text
V3.9 Silver NAS Core
```

It preserves the strongest existing frame, avoids forced symbolism, and makes
the NAS chassis the main visual object without the extra outer background layer.
Use the core SVG as the source of truth, then place it on an opaque export
background only when generating the final iOS AppIcon asset set.

Earlier V1 candidates:

- `nastart-app-icon-v1-nas-launch.svg`
- `nastart-app-icon-v1-power-bay.svg`
- `nastart-app-icon-v1-launch-grid.svg`
- `app-icon-preview.html`

Compare them at:

- 1024 x 1024
- App Store listing size
- iPhone home screen size
- Settings/search small icon size
- dark and light wallpapers

After one direction is selected, export the final vector master to the complete
iOS AppIcon raster set and add it to the Xcode asset catalog.
