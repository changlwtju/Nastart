# Competitor Recording Notes

Version: 0.1
Status: Draft
Last updated: 2026-07-27

## 1. Source Material

User-provided iPhone screen recordings:

- `RPReplay_Final1785137232.mp4`
- `RPReplay_Final1785137309.mp4`

Extracted review artifacts:

- `docs/research/competitor-recordings/recording-01-contact-sheet.jpg`
- `docs/research/competitor-recordings/recording-02-contact-sheet.jpg`

The recordings are enough for first-pass IA and interaction analysis. We do not
need exhaustive screenshots before moving into Nastart's own design workflow.

## 2. Recording 01: DS One-Oriented Flow

### 2.1 Observed Screens

- Home dashboard with NAS resource summary, shortcut grid, and recent folders.
- Add service sheet with library, WebDAV, and DSM service options.
- DSM login form with QuickConnect guidance.
- File browser with folder list, breadcrumb path, search, and compact toolbar.
- Media tab with music-oriented cards and categories.
- Resource monitor with overview, memory, CPU, network, process list, disk,
  and temperature states.
- Synology web page handoff.
- Power menu for shutdown, force shutdown, and restart.

### 2.2 Strengths Worth Learning

- The first screen gives useful NAS state immediately: storage, memory, CPU,
  temperature, storage-device status, and files.
- The bottom tabs clearly reveal product identity: home, video, audio, album,
  mine.
- File browsing is visually calm: folder icons, one-line metadata, and a clear
  path hierarchy.
- Resource monitoring stays modular. Users can drill into CPU, memory, process,
  and runtime status instead of reading everything on one page.
- QuickConnect help is shown as a temporary sheet, not permanent instructional
  copy.
- Dangerous actions are hidden behind a menu and not promoted on the main
  screen.

### 2.3 Risks To Avoid

- Media-first tabs would make Nastart look like a DS One clone and weaken the
  launchpad positioning.
- A dense resource monitor can become a technical page rather than a daily app
  surface.
- Power and destructive NAS actions need a mature safety model; they should not
  be prominent in Nastart v1.

### 2.4 Nastart Implications

- Nastart's first screen should be Launchpad-first, but it can borrow DS One's
  compact status summary pattern.
- Files should be a helper flow launched from a service, folder, or device
  detail, not a v1 top-level tab.
- Media should start from Jellyfin, Emby, Plex, and Navidrome service cards.
- Resource details should live under Device Detail, with only critical state
  surfaced on Launchpad.
- QuickConnect/DSM setup help should appear as contextual sheets.

## 3. Recording 02: MyServers-Oriented Flow

### 3.1 Observed Screens

- Dashboard/board tab with server widgets, CPU/memory/network/disk panels, and
  Docker module card.
- Server list with connection status, more actions, and add button.
- Add/update server page with MyServers service and SSH connection choices.
- Quick import and pairing-code setup paths.
- Terminal tab with empty session state.
- Subscription sheet with permanent, monthly, and yearly plans.
- Settings page with Plus banner, appearance, theme, Face ID, language, iCloud,
  SSH credentials, clipboard magnet checks, redemption, feedback, Telegram, and
  review entries.

### 3.2 Strengths Worth Learning

- The product is very explicit about server objects and operational modules.
- Pairing-code setup reduces manual configuration burden.
- Subscription value is tied to visible limits: servers, apps, sessions, Docker
  management.
- Settings are grouped into basic, advanced, and feedback sections, which is
  easy to scan.
- The UI uses native list, sheet, segmented-control, and switch patterns.

### 3.3 Risks To Avoid

- The app surface can feel like an operations console because several modules
  compete for attention.
- Terminal as a top-level tab signals a technical user base; Nastart should not
  make SSH the product identity.
- A Plus banner at the top of settings is useful, but too much explanation can
  make the app feel commercial before trust is established.
- Some status cards show many empty technical values at once; Nastart should
  hide unknown/empty values more gracefully.

### 3.4 Nastart Implications

- Nastart should keep optional Agent/pairing-code concepts, but use them as an
  enhancement path rather than the default DSM-first path.
- The Devices tab should absorb server/NAS details without becoming a generic
  "Servers" console.
- Plus limits should be concrete and easy to understand:
  launchpad themes, synced devices, reminders, service checks, and advanced
  diagnostics.
- Terminal should be a future advanced feature or Device Detail action, not a
  v1 tab.
- Empty states should show one next action and avoid placeholder-heavy status
  blocks.

## 4. Cross-Competitor Product Lessons

### 4.1 What Both Apps Validate

- NAS users accept mobile apps that combine connection, files, media, and
  monitoring.
- A clean card/list hybrid is a natural mobile pattern for NAS and server
  tools.
- Connection confidence matters: users need to know whether the device,
  service, or endpoint is reachable.
- Paid unlocks are normal in this category, but pricing must feel proportional
  because the audience is specialized.

### 4.2 Where Nastart Must Be Different

Nastart should be judged less by the number of modules and more by how quickly
it turns a Synology NAS into a useful, attractive personal launchpad.

Core differentiation:

```text
DSM login
-> automatic discovery
-> generated launchpad
-> service health and certificate awareness
-> reminders for NAS-related lifecycle events
-> iCloud-synced personal layout
```

### 4.3 UI Direction

- Use black or near-black SF Symbols for shell navigation.
- Keep accent color for selected state, primary actions, warnings, and Plus.
- Prefer visible objects over paragraphs: service cards, status chips,
  connection rows, reminder rows.
- Avoid too many top-level tabs. Four tabs remains the recommended v1 shell:
  Launchpad, Devices, Reminders, Mine.
- Keep media, files, terminal, and Docker management one level deeper unless
  usage data proves they deserve top-level placement.

## 5. Recommended Next Design Moves

1. Finalize the five primary flows:
   DSM first connection, Launchpad card structure, Device Detail, Reminder
   creation, and Plus unlock.
2. Produce low-fidelity wireframes for the four-tab shell.
3. Generate high-fidelity visual references only after the IA is stable.
4. Build a SwiftUI interactive prototype before committing to final visuals.

