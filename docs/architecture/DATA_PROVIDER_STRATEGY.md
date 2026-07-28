# Nastart Data Provider Strategy

Nastart keeps SwiftUI screens independent from the final NAS data source.

## Current Stage

`AppDataStore` is the single UI-facing data store. It is injected from `NastartApp` and currently loads `MockAppDataProvider`, which wraps local `SampleData`.

Screens should read data from `@EnvironmentObject private var dataStore: AppDataStore` instead of reading `SampleData` directly.

## Provider Contract

`AppDataProviding` currently exposes:

- `device`
- `services`
- `containers`
- `files`
- `tasks`
- `videoLibraryItems`
- `audioLibraryItems`
- `discoveredDevices`

This is intentionally simple while the UI prototype is still moving quickly.

The broad provider now has narrower protocol shapes beside it:

- `NASDeviceProviding`
- `LaunchpadServiceProviding`
- `DockerProviding`
- `FileSystemProviding`
- `MediaLibraryProviding`
- `ReminderProviding`

The mock provider conforms to all of them. Real providers should be introduced behind these contracts instead of calling DSM or Agent APIs from SwiftUI screens.

## Real Data Direction

Future providers can conform to the same shape:

- `DSMAppDataProvider`: DSM login, system info, packages, shared folders, basic file metadata.
- `AgentAppDataProvider`: Docker metrics, port mappings, service discovery, richer diagnostics.
- `CompositeAppDataProvider`: merges DSM-first data with Agent enhancements.

The UI should not know whether data came from DSM, Agent, iCloud cache, or local sample data.

## Next Step

When real networking begins, keep the UI wired to `AppDataStore` and replace the store's provider composition internally. The first real pass should still be small: DSM login, device summary, package/service list, and shared folder listing.
