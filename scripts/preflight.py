#!/usr/bin/env python3
"""Local static checks for the Nastart iOS prototype.

This script intentionally avoids Xcode-only tooling so it can run on the NAS
workspace. It is not a Swift compiler; it catches the common issues that have
already cost us time during device builds.
"""

from __future__ import annotations

import json
import re
import struct
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
IOS_ROOT = ROOT / "ios" / "Nastart" / "Nastart"
PROJECT_FILE = ROOT / "ios" / "Nastart" / "Nastart.xcodeproj" / "project.pbxproj"
APP_ICON_CONTENTS = IOS_ROOT / "Assets.xcassets" / "AppIcon.appiconset" / "Contents.json"
LOCALIZATION_FILES = {
    "en": IOS_ROOT / "en.lproj" / "Localizable.strings",
    "zh-Hans": IOS_ROOT / "zh-Hans.lproj" / "Localizable.strings",
}


@dataclass
class CheckResult:
    name: str
    errors: list[str]
    warnings: list[str]

    @property
    def ok(self) -> bool:
        return not self.errors


def run_command(name: str, command: list[str]) -> CheckResult:
    completed = subprocess.run(
        command,
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    if completed.returncode == 0:
        return CheckResult(name, [], [])
    output = completed.stdout.strip() or f"{' '.join(command)} failed"
    return CheckResult(name, [output], [])


def swift_files() -> list[Path]:
    return sorted(IOS_ROOT.rglob("*.swift"))


def strip_swift_comments_and_strings(source: str) -> str:
    output: list[str] = []
    i = 0
    state = "code"
    block_depth = 0

    while i < len(source):
        ch = source[i]
        nxt = source[i + 1] if i + 1 < len(source) else ""

        if state == "code":
            if ch == "/" and nxt == "/":
                state = "line_comment"
                output.append(" ")
                i += 2
                continue
            if ch == "/" and nxt == "*":
                state = "block_comment"
                block_depth = 1
                output.append(" ")
                i += 2
                continue
            if ch == '"':
                state = "string"
                output.append('"')
                i += 1
                continue
            output.append(ch)
            i += 1
            continue

        if state == "line_comment":
            output.append("\n" if ch == "\n" else " ")
            if ch == "\n":
                state = "code"
            i += 1
            continue

        if state == "block_comment":
            output.append("\n" if ch == "\n" else " ")
            if ch == "/" and nxt == "*":
                block_depth += 1
                i += 2
                continue
            if ch == "*" and nxt == "/":
                block_depth -= 1
                i += 2
                if block_depth == 0:
                    state = "code"
                continue
            i += 1
            continue

        if state == "string":
            output.append(" " if ch != "\n" else "\n")
            if ch == "\\":
                i += 2
                continue
            if ch == '"':
                state = "code"
                output.append('"')
            i += 1

    return "".join(output)


def check_swift_balanced_delimiters() -> CheckResult:
    errors: list[str] = []
    pairs = {"{": "}", "(": ")", "[": "]"}
    closing = {v: k for k, v in pairs.items()}

    for path in swift_files():
        source = strip_swift_comments_and_strings(path.read_text(encoding="utf-8"))
        stack: list[tuple[str, int]] = []
        line = 1
        for ch in source:
            if ch == "\n":
                line += 1
                continue
            if ch in pairs:
                stack.append((ch, line))
            elif ch in closing:
                if not stack or stack[-1][0] != closing[ch]:
                    rel = path.relative_to(ROOT)
                    errors.append(f"{rel}:{line}: unexpected '{ch}'")
                else:
                    stack.pop()
        if stack:
            rel = path.relative_to(ROOT)
            opener, opener_line = stack[-1]
            errors.append(f"{rel}:{opener_line}: unclosed '{opener}'")

    return CheckResult("Swift delimiter balance", errors, [])


def check_ios16_static_patterns() -> CheckResult:
    errors: list[str] = []
    warnings: list[str] = []
    blocked_patterns = [
        (re.compile(r"\.buttonBorderShape\(\s*\.circle\s*\)"), "Use an iOS 16-safe shape, not .buttonBorderShape(.circle)."),
        (re.compile(r"\bSection\(\s*\""), "Use Section { ... } header: { Text(...) } to avoid SwiftUI overload issues."),
        (re.compile(r"@Observable\b"), "Observation/@Observable is iOS 17-era; keep the iOS 16 target safe."),
        (re.compile(r"\.sensoryFeedback\s*\("), ".sensoryFeedback is iOS 17+."),
        (re.compile(r"\.symbolEffect\s*\("), ".symbolEffect is iOS 17+."),
        (re.compile(r"\.contentMargins\s*\("), ".contentMargins is iOS 17+."),
        (re.compile(r"\.containerBackground\s*\("), ".containerBackground is iOS 17+."),
    ]
    warn_patterns = [
        (re.compile(r"#Preview\b"), "#Preview requires newer Xcode tooling; Xcode 14 users may need PreviewProvider."),
    ]

    for path in swift_files():
        source = path.read_text(encoding="utf-8")
        for line_number, line in enumerate(source.splitlines(), start=1):
            for pattern, message in blocked_patterns:
                if pattern.search(line):
                    rel = path.relative_to(ROOT)
                    errors.append(f"{rel}:{line_number}: {message}")
            for pattern, message in warn_patterns:
                if pattern.search(line):
                    rel = path.relative_to(ROOT)
                    warnings.append(f"{rel}:{line_number}: {message}")

    return CheckResult("iOS 16 static API guard", errors, warnings)


def parse_localizable(path: Path) -> tuple[dict[str, str], list[str]]:
    key_values: dict[str, str] = {}
    errors: list[str] = []
    key_pattern = re.compile(r'^\s*"((?:\\.|[^"\\])*)"\s*=\s*"((?:\\.|[^"\\])*)"\s*;\s*$')

    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        stripped = line.strip()
        if not stripped or stripped.startswith("//") or stripped.startswith("/*") or stripped.startswith("*"):
            continue
        match = key_pattern.match(line)
        if not match:
            errors.append(f"{path.relative_to(ROOT)}:{line_number}: invalid .strings entry")
            continue
        key, value = match.groups()
        if key in key_values:
            errors.append(f"{path.relative_to(ROOT)}:{line_number}: duplicate key '{key}'")
        key_values[key] = value

    return key_values, errors


def check_localizations() -> CheckResult:
    errors: list[str] = []
    parsed: dict[str, dict[str, str]] = {}

    for locale, path in LOCALIZATION_FILES.items():
        if not path.exists():
            errors.append(f"Missing localization file: {path.relative_to(ROOT)}")
            continue
        parsed[locale], locale_errors = parse_localizable(path)
        errors.extend(locale_errors)

    if len(parsed) == len(LOCALIZATION_FILES):
        all_keys = set().union(*(values.keys() for values in parsed.values()))
        for locale, values in parsed.items():
            missing = sorted(all_keys - set(values.keys()))
            if missing:
                preview = ", ".join(missing[:10])
                suffix = "" if len(missing) <= 10 else f" ... +{len(missing) - 10}"
                errors.append(f"{locale} missing {len(missing)} localization keys: {preview}{suffix}")

    return CheckResult("Localization parity", errors, [])


def check_localization_references() -> CheckResult:
    errors: list[str] = []
    defined_keys: set[str] = set()
    for path in LOCALIZATION_FILES.values():
        if path.exists():
            values, _ = parse_localizable(path)
            defined_keys.update(values)

    call_patterns = [
        re.compile(
            r'\b(?:Text|Label|Button|TextField|SecureField|Toggle|Picker|LabeledContent)'
            r'\(\s*"((?:\\.|[^"\\])*)"'
        ),
        re.compile(r'\.(?:navigationTitle|alert|confirmationDialog)\(\s*"((?:\\.|[^"\\])*)"'),
        re.compile(r'\bNSLocalizedString\(\s*"((?:\\.|[^"\\])*)"'),
    ]

    for path in swift_files():
        source = path.read_text(encoding="utf-8")
        for pattern in call_patterns:
            for match in pattern.finditer(source):
                key = match.group(1)
                if "\\(" in key or "." not in key or key in defined_keys:
                    continue
                line = source.count("\n", 0, match.start()) + 1
                errors.append(f"{path.relative_to(ROOT)}:{line}: undefined localization key '{key}'")

    return CheckResult("Localization references", sorted(set(errors)), [])


def parse_size(size: str, scale: str) -> tuple[int, int]:
    width, height = [float(part) for part in size.split("x")]
    scale_number = int(scale.rstrip("x"))
    return round(width * scale_number), round(height * scale_number)


def png_dimensions(path: Path) -> tuple[int, int, int] | None:
    data = path.read_bytes()
    if len(data) < 33 or data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        return None
    width, height = struct.unpack(">II", data[16:24])
    color_type = data[25]
    return width, height, color_type


def check_app_icon_asset() -> CheckResult:
    errors: list[str] = []
    warnings: list[str] = []

    if not APP_ICON_CONTENTS.exists():
        return CheckResult("AppIcon asset", [f"Missing {APP_ICON_CONTENTS.relative_to(ROOT)}"], [])

    contents = json.loads(APP_ICON_CONTENTS.read_text(encoding="utf-8"))
    images = contents.get("images", [])
    seen_filenames: set[str] = set()
    for image in images:
        filename = image.get("filename")
        size = image.get("size")
        scale = image.get("scale")
        idiom = image.get("idiom")
        if not filename:
            errors.append(f"AppIcon entry for {idiom} {size}@{scale} has no filename")
            continue
        seen_filenames.add(filename)
        icon_path = APP_ICON_CONTENTS.parent / filename
        if not icon_path.exists():
            errors.append(f"Missing app icon file: {icon_path.relative_to(ROOT)}")
            continue
        dimensions = png_dimensions(icon_path)
        if dimensions is None:
            errors.append(f"{icon_path.relative_to(ROOT)} is not a valid PNG")
            continue
        width, height, color_type = dimensions
        expected_width, expected_height = parse_size(size, scale)
        if (width, height) != (expected_width, expected_height):
            errors.append(
                f"{icon_path.relative_to(ROOT)} is {width}x{height}, expected {expected_width}x{expected_height}"
            )
        if color_type in {4, 6}:
            warnings.append(f"{icon_path.relative_to(ROOT)} appears to contain an alpha channel")

    pngs = {path.name for path in APP_ICON_CONTENTS.parent.glob("*.png")}
    unreferenced = sorted(pngs - seen_filenames)
    if unreferenced:
        warnings.append("Unreferenced AppIcon PNGs: " + ", ".join(unreferenced))

    return CheckResult("AppIcon asset", errors, warnings)


def check_project_settings() -> CheckResult:
    errors: list[str] = []
    warnings: list[str] = []

    if not PROJECT_FILE.exists():
        return CheckResult("Xcode project settings", [f"Missing {PROJECT_FILE.relative_to(ROOT)}"], [])

    text = PROJECT_FILE.read_text(encoding="utf-8")
    deployment_targets = sorted(set(re.findall(r"IPHONEOS_DEPLOYMENT_TARGET = ([0-9.]+);", text)))
    if not deployment_targets:
        errors.append("IPHONEOS_DEPLOYMENT_TARGET is not set")
    elif deployment_targets != ["16.0"]:
        errors.append(f"Expected iOS deployment target 16.0, found: {', '.join(deployment_targets)}")

    if "ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;" not in text:
        errors.append("AppIcon asset catalog is not assigned to the target")

    swift_versions = sorted(set(re.findall(r"SWIFT_VERSION = ([0-9.]+);", text)))
    if not swift_versions:
        warnings.append("SWIFT_VERSION is not set")

    return CheckResult("Xcode project settings", errors, warnings)


def main() -> int:
    checks = [
        run_command("Git whitespace", ["git", "diff", "--check"]),
        check_swift_balanced_delimiters(),
        check_ios16_static_patterns(),
        check_localizations(),
        check_localization_references(),
        check_app_icon_asset(),
        check_project_settings(),
    ]

    print("Nastart local preflight")
    print("=" * 24)
    failed = False
    for result in checks:
        status = "PASS" if result.ok else "FAIL"
        print(f"[{status}] {result.name}")
        for warning in result.warnings:
            print(f"  WARN: {warning}")
        for error in result.errors:
            print(f"  ERROR: {error}")
        failed = failed or not result.ok

    if failed:
        print("\nPreflight failed.")
        return 1

    print("\nPreflight passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
