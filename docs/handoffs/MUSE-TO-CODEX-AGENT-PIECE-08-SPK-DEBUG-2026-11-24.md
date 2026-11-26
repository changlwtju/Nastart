# Handoff: Agent Piece 08 — SPK "format incorrect" debug (DSM 7.4.1, DS918+)

## Goal
Get the Nastart Agent SPK to install on the user's DS918+ (DSM 7.4.1-90080 Update 1) via Package Center Manual Install, then complete the piece 08 acceptance (NAS Agent HTTPS, pairing, launchpad verification).

## Background
- The SPK (`nastart-agent-0.4.0-0001.spk`, 81,920 bytes) is built by `scripts/build_spk.sh` (Python tarfile, USTAR format, INFO first). It is a container-route package: it pulls `changlwtju/nastart-agent:0.4.0` from Docker Hub at install time (postinst). Target NAS is DS918+ (apollolake, x86_64, DSM 7.4.1-90080 Update 1), Container Manager already installed.
- DSM 7.4.1 rejects ALL full-SP variants with "套件文件格式不正确" (package format incorrect) at the format-check stage. The system log shows NO install entries for these attempts (rejection happens before any install transaction starts).
- A MINIMAL test SPK installs fine on the same DSM. So the basic format is valid and DSM 7.4.1 accepts unsigned third-party SPKs. Trust level is NOT visible in DSM 7.4.1 Settings → General (user scrolled to the bottom, it is genuinely absent), and the minimal SPK installs anyway, so trust level is not blocking.

## Binary search results (all tested by user via Package Center Manual Install)
The minimal SPK (`nastart-minimal-0.0.1-0001.spk`, SHA 7b150cb7… / rebuilt with conf/privilege SHA 12ed943f…) installs. These full-SP variants ALL fail with "format incorrect":
1. Original (Python tarfile, INFO not first) — FAIL
2. INFO-first (build_spk.sh fixed) — FAIL, SHA d3a8d69c…
3. GNU tar rebuild — FAIL, SHA 59dc1eda…
4. nodep (removed install_dep_packages) — FAIL, SHA b0911d6a…
5. noarch (arch="noarch") — FAIL, SHA 7e74ba23…
6. nores (removed conf/resource) — FAIL, SHA aa5ac798…
7. minscripts (all scripts → minimal exit 0, removed common) — FAIL, SHA 194dcaa8…
8. minpkg (package.tgz → minimal README only) — FAIL, SHA 6cf20878…
9. nolic (removed LICENSE) — FAIL, SHA 06b37bd5…

Ruled out: conf/resource (port config), scripts (content + the extra `common` file), package.tgz contents (compose.sh, compose.yaml, image, port_conf/), LICENSE (contains one non-ASCII em dash, but removing it did not help), INFO checksum (all three verified to match their package.tgz: nolic 8da87146…, minimal d852174f…, noarch 5a72d459…), tar format (GNU tar vs Python tarfile both fail; minimal uses GNU tar and works), trust level (see above).

SPK structure was verified byte-by-byte and is clean: valid POSIX ustar tar, INFO first, no `./` prefix, no PaxHeaders, INFO fields complete with LF endings and no BOM, conf/privilege and conf/resource are valid JSON, all 8 scripts are `-rwxr-xr-x` with `#!/bin/sh` and no CRLF/BOM, icons are valid PNGs, inner package.tgz is a valid ustar tar.

## Remaining suspect: INFO fields
The ONLY difference between nolic (fails) and the minimal SPK (works) is the INFO file's four fields:
- package: "nastart-agent" vs "nastart-minimal"
- version: "0.4.0-0001" vs "0.0.1-0001"
- displayname: "Nastart Agent" vs "Nastart Minimal Test"
- description: "Read-only local NAS and container discovery for Nastart. Requires Container Manager." vs "Minimal test package."

## What is ready for you (all in Mac ~/Downloads/)
- `nastart-agent-test-0.0.1-0001.spk` (SHA 78b812e890ff5f468b8ba07b17e76df248e4261adf4be5437f0ea1982575e50d): INFO-test. All four INFO fields set to minimal-style (package="nastart-agent-test", version="0.0.1-0001", displayname="Nastart Minimal Test", description="Minimal test package."). If this installs, INFO is confirmed as the culprit.
- Four single-field variants (each changes ONLY one INFO field back to the full value, on the INFO-test base; all share package.tgz MD5 8da87146…):
  - `nastart-agent-test-0.0.1-0001-f_pkg.spk` (SHA a095711c96bb6add6ca06a3eea7600885bd2e1488139f8fba13a07f9101bc182): only package="nastart-agent"
  - `nastart-agent-test-0.0.1-0001-f_ver.spk` (SHA 10e21e4a99c9831c16a92cc5708344557685a8120c10685162edbfbf39f6c6a2): only version="0.4.0-0001"
  - `nastart-agent-test-0.0.1-0001-f_disp.spk` (SHA c429437e3c11e601fdf4416045a198800a2e10a1135106ad9314ccda6aeb0855): only displayname="Nastart Agent"
  - `nastart-agent-test-0.0.1-0001-f_desc.spk` (SHA 0ffceaadfd96ac90dca68fc2f594681fc2d1a5b3ca809c845f38876e278a85bc): only description=long
- `nastart-minimal-0.0.1-0001.spk` (already installed on the NAS as a test package; uninstall it after debugging to leave the NAS clean).
- Failed variants are in `~/Downloads/spk_old_variants/`. Current test files in `~/Downloads/`: nolic, nastart-agent-test, the four f_* variants, nastart-minimal.

## Your task
1. Test the INFO-test SPK (`nastart-agent-test-0.0.1-0001.spk`) via DSM Package Center → Manual Install on the DS918+ (DSM at https://192.168.1.64:5001 or via lagrasun.cn).
   - If it installs: INFO is the culprit. Test the four single-field variants (f_pkg, f_ver, f_disp, f_desc) one by one to find which field breaks it.
   - If it fails: INFO is not the culprit. The defect is in something even more fundamental. Re-examine from scratch (compare the INFO-test tar byte-by-byte against the minimal SPK tar; the only differences should be package name and checksum).
2. Once you identify the culprit INFO field, fix it:
   - If it is the package name: determine why "nastart-agent" is rejected and choose a compliant name. Update `scripts/build_spk.sh` and the INFO generation, and any references.
   - If it is the version/displayname/description: fix the value to a DSM-accepted form.
   - Update the source so `scripts/build_spk.sh` produces a correct SPK. Do NOT just hand-edit a one-off SPK; the build script must be fixed so the fix is reproducible.
3. Rebuild the FULL SPK (with conf/resource, real scripts, full package.tgz, LICENSE, fixed INFO) via `scripts/build_spk.sh`, verify it installs on the DS918+, and run the full lifecycle test (`scripts/test_spk_lifecycle.sh`) to confirm nothing regressed.
4. Complete the piece 08 acceptance (see below).

## How to install/test SPKs
- Preferred: DSM Package Center → Manual Install → upload .spk → follow wizard. Report the exact result (installed OK, or the exact error message).
- If you have NAS SSH access (user `changlwtju`, NAS 192.168.1.64), you can also use `sudo synopkg install /path/to.spk`, which prints detailed errors (much more informative than the web UI's generic message). Do NOT modify NAS users, groups, Docker socket permissions, or DSM settings. If you hit a Docker group permission error, STOP and report it (do not change NAS permissions).
- Note: the Mac cannot SSH to the NAS key-based (tested 2026-11-24 22:18, permission denied). You will need the user's DSM/NAS credentials, or use the Mac browser where the user may already be logged in to DSM. Muse (SSH-only, no GUI/browser to the NAS LAN) could not do this directly, which is why this is handed to you.

## Piece 08 acceptance criteria (after SPK installs)
1. SPK installs on DS918+ via Package Center. Confirm Container Manager is installed (it is).
2. `curl -sk https://192.168.1.64:8787/healthz` returns 200 and version 0.4.0.
3. Get the one-time pairing code from Container Manager → container logs for the agent container (do NOT print or repeat the code; use it via script/WDA injection only).
4. On iPhone 13, pair with `https://192.168.1.64:8787` (enable "Skip SSL verification"), verify handshake fingerprint matches and launchpad shows "Agent 已连接".
5. Write acceptance record `docs/archive/handoffs/2026-11/MUSE-TO-CODEX-2026-11-24-AGENT-PIECE-08-ACCEPTANCE.md` (include: local re-verification, SPK variant SHAs and DSM rejection root cause, DSM 7.4.1 / Container Manager versions, NAS results, process issues). Update `docs/project/AGENT-BREAKDOWN.md` piece 08 to "已验收" and `~/MEMORY.md` piece 08 entry.

## Constraints
- Do not modify NAS users, groups, Docker socket, or DSM settings. If a Docker group permission error appears, preserve the scene and report it.
- Do not print or repeat pairing codes, tokens, or private keys.
- The SPK build must remain reproducible via `scripts/build_spk.sh` (fix the script/source, not just a one-off file).
- The minimal test package `nastart-minimal` is installed on the NAS; uninstall it after debugging to leave the NAS clean.
- The persistent Mac Agent (nastart-agent-https, 0.4.0, 192.168.1.82:8787) is still running and the iPhone 13 is paired to it; do not stop it.
