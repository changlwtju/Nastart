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

Open this project on macOS with Xcode:

```text
ios/Nastart/Nastart.xcodeproj
```

The first prototype includes:

- four tabs: Launchpad, Devices, Tasks, Mine
- three Launchpad layout concepts: Home Base, Service Stacks, Command Deck
- sample Synology DSM + Agent data
- localized Chinese and English strings
- iPhone and iPad target families
- minimum deployment target: iOS/iPadOS 16.0

## Before Running On Device

In Xcode:

1. Open `Nastart.xcodeproj`.
2. Select the `Nastart` target.
3. Set your Apple Developer Team.
4. Change `PRODUCT_BUNDLE_IDENTIFIER` if needed.
5. Choose an iPhone or iPad simulator/device.
6. Run the app.

The NAS workspace cannot compile this project because Xcode is only available
on macOS.

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
