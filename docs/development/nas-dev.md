# Nastart NAS Development Workflow

The NAS workspace is optimized for fast static validation and fixture-driven
checks. It does not replace a Mac/Xcode build, but it should catch the mistakes
that are cheap to detect before handing the branch to Xcode.

## What To Run

```bash
scripts/preflight.sh
```

This compiles the Python helper scripts, then runs `scripts/preflight.py`.
For a narrower pass while iterating, run:

```bash
python3 scripts/preflight.py
git diff --check
```

## Good NAS-Side Work

- SwiftUI layout cleanup that can be reviewed by static structure and localized
  string checks.
- Launchpad service recognition rules and fixture updates.
- DSM, Agent, and playback policy work that improves the app's real NAS
  behavior while keeping Mac/Xcode as the final device validation step.
- Documentation, handoff notes, and scripts that do not need Apple toolchains.

## Agent Development Focus

Agent is an optional read-only enhancement path. On Synology, DSM login remains
the primary connection because it provides DSM identity, File Station browsing,
package APIs, session-backed media URLs, and DSM-specific settings. Agent then
adds richer local observations such as Docker containers, published ports,
host metrics, and service endpoint discovery.

The useful NAS-side work is making that enhanced data more accurate:

- Keep Agent-discovered services aligned with `ServiceIconRegistry`.
- Avoid showing background infrastructure containers by default.
- Improve endpoint inference and diagnostics without giving Agent write access.
- Keep the install and smoke-test scripts easy to run from a Mac on the same
  LAN as the NAS.

Deploy from a Mac or another shell that can SSH into the NAS:

```bash
scripts/install_agent_via_ssh.sh --host NAS_HOST --user SSH_USER --pairing-code 123456
```

The installer uploads the fixed Agent payload, prefers Docker Compose, and
falls back to Python 3 when Compose is unavailable. The app also has an in-app
SSH installer that follows the same deployment shape.

After deploying Agent, verify it from a Mac or NAS shell:

```bash
python3 scripts/agent_smoke_test.py --base-url http://NAS_HOST:8787 --pairing-code 123456
```

After pairing once, future checks can use the stored token copied from the
pairing response if needed:

```bash
python3 scripts/agent_smoke_test.py --base-url http://NAS_HOST:8787 --token AGENT_TOKEN
```

## Mac/Xcode Handoff

Run the final compiler-backed validation on a Mac:

```bash
scripts/xcodebuild_nastart.sh build
```

If the branch changes Swift APIs, SF Symbols, Xcode project wiring, CocoaPods,
or entitlements, treat the Mac build as required before pushing a release-bound
commit.

## Service Icon Fixtures

Common home-lab services live in:

```text
docs/development/service-icon-fixtures.json
```

When adding or changing a service icon rule:

- Add or update the JSON fixture.
- Keep `ServiceIconRegistry` in `NASModels.swift` as the single source of
  runtime matching.
- Add Swift regression coverage in `NonPlaybackPolicyTests.swift` for services
  whose category, icon, or badge affects the launchpad.
- Run `scripts/preflight.sh` before handoff.
