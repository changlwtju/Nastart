# Nastart iOS

This directory contains the first SwiftUI prototype for Nastart.

Recommended initial stack:

- Swift
- SwiftUI
- Swift Concurrency
- Observation
- URLSession
- Keychain
- CryptoKit
- Network.framework
- WidgetKit
- StoreKit 2
- OSLog

## Current Prototype

Install the iOS dependency on macOS, then open the CocoaPods workspace:

```bash
cd ios/Nastart
pod install
open Nastart.xcworkspace
```

`MobileVLCKit 3.7.3` is pinned in the `Podfile`. Nastart tries AVPlayer for
Apple-native media first and uses MobileVLCKit for broader container and codec
support. An AVPlayer decoding failure also switches to MobileVLCKit
automatically. Every media item can still be handed to an external player.
The project keeps Xcode user script sandboxing disabled so CocoaPods can embed
the MobileVLCKit framework during device builds.

Opening `Nastart.xcodeproj` remains useful for the lightweight AVPlayer-only
build, but it does not include the compatibility player.

The first prototype includes:

- four tabs: Launchpad, Devices, Tasks, Mine
- three Launchpad layout concepts: Home Base, Service Stacks, Command Deck
- sample Synology DSM + Agent data
- localized Chinese and English strings
- iPhone and iPad target families
- minimum deployment target: iOS/iPadOS 16.0

## Before Running On Device

In Xcode:

1. Run `pod install` and open `Nastart.xcworkspace`.
2. Select the `Nastart` target.
3. Set your Apple Developer Team.
4. Change `PRODUCT_BUNDLE_IDENTIFIER` if needed.
5. Choose an iPhone or iPad simulator/device.
6. Run the app.

The NAS workspace cannot compile this project because Xcode is only available
on macOS.

Debug builds use an empty entitlement file and define `NASTART_NO_ICLOUD`, so
CloudKit is intentionally disabled in Debug. Release builds use the production
CloudKit entitlement; configure the signing team and container before testing
Release sync behavior.

## Swift Unit Tests

The `NastartTests` target covers non-playback policies such as URL validation,
network-host classification, service status replacement, and launchpad category
ordering. It also covers the greenfield playback core model, Range/cache
planning, connection classification, KSPlayer availability boundaries, and
weak-network first-frame policy.

On macOS, the repository wrapper can run the workspace even when global
`xcode-select` points at CommandLineTools, as long as a full Xcode exists in a
standard location such as `/Applications/Xcode.app` or `~/Downloads/Xcode.app`:

```bash
./scripts/xcodebuild_nastart.sh -scheme Nastart \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' test
```

To switch the whole machine to the downloaded Xcode instead, run this locally
and enter the macOS admin password in Terminal:

```bash
sudo xcode-select -s ~/Downloads/Xcode.app/Contents/Developer
```

## Measuring App Size

Measure a Release archive rather than adding source or framework folder sizes:

1. Select a generic iOS device and choose Product > Archive.
2. In Organizer, choose Distribute App > Ad Hoc or Development.
3. Enable the app thinning size report when exporting.
4. Compare the installed size for the target device with the previous archive.

MobileVLCKit contains native code for multiple device architectures, so the
repository and archive can be much larger than the thinned App Store download
or installed size for one device.

## Third-Party Media Component

MobileVLCKit is provided by VideoLAN under LGPL 2.1 or later. Before public
distribution, keep the required notices and confirm the final linkage and
relinking approach against the shipped archive. See `THIRD_PARTY_NOTICES.md`.

## Local Preflight

Before pushing code or opening the project in Xcode, run:

```text
./scripts/preflight.sh
```

The script runs static checks that work in the NAS workspace, including
localization parity, iOS 16 guard patterns, AppIcon asset integrity, Swift
delimiter balance, and `git diff --check`.

## Localization

The prototype uses `Localizable.strings`:

```text
Nastart/en.lproj/Localizable.strings
Nastart/zh-Hans.lproj/Localizable.strings
```

To preview languages in Xcode, edit the scheme and set `Application Language`
to English or Simplified Chinese.

## Design Direction

Launchpad is the visual priority. The current SwiftUI implementation is a
working prototype, not the final polished UI. It exists to make navigation,
state, localization, and layout concepts testable on real devices before
high-fidelity design is locked.
