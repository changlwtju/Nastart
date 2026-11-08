#if DEBUG
import XCTest
@testable import NetworkMedia

final class OfflineUIScenarioTests: XCTestCase {
    func testNormalLaunchDoesNotRequestOfflineRoot() {
        XCTAssertNil(OfflineUIConfiguration.requested(arguments: ["app"]))
        XCTAssertNil(OfflineUIConfiguration.requested(arguments: ["app", "--offline-ui-theme", "glassDeck"]))
    }
    func testEverySceneHasAnExplicitIsolatedConfiguration() {
        for scene in OfflineUIConfiguration.Scenario.allCases where scene != .invalid {
            let value = OfflineUIConfiguration.requested(arguments: ["app", "--offline-ui", scene.rawValue,
                "--offline-ui-theme", "glassDeck", "--offline-ui-appearance", "dark", "--offline-ui-text-size", "large"])
            XCTAssertEqual(value?.scenario, scene)
            XCTAssertEqual(value?.theme, .glassDeck)
            XCTAssertEqual(value?.appearance, .dark)
            XCTAssertEqual(value?.textSize, .large)
        }
    }
    func testMalformedExplicitRequestNeverFallsBackToProduction() {
        for args in [["--offline-ui"], ["--offline-ui=library"], ["--offline-ui", "https://example.test"],
                     ["--offline-ui", "library", "--offline-ui", "detail"],
                     ["--offline-ui", "library", "--offline-ui-theme", "unknown"],
                     ["--offline-ui", "settings", "--offline-ui-text-size", "unknown"],
                     ["--offline-ui", "library", "--offline-ui-appearance", "dark", "--offline-ui-appearance", "light"],
                     ["--offline-ui", "--offline-ui-theme", "glassDeck"]] {
            XCTAssertEqual(OfflineUIConfiguration.requested(arguments: args)?.scenario, .invalid)
        }
    }
    func testPasswordFlagsWithoutOfflineRootStayOrdinary() {
        XCTAssertNil(OfflineUIConfiguration.requested(arguments: ["app", "--offline-password-initial", "empty"]))
        XCTAssertNil(OfflineUIConfiguration.requested(arguments: ["app", "--offline-password-trace"]))
        XCTAssertNil(OfflineUIConfiguration.requested(arguments: ["app", "--offline-password-cell", "A1"]))
    }
    func testPasswordProbeDefaultsMatchProductionForEveryScene() {
        for scene in OfflineUIConfiguration.Scenario.allCases where scene != .invalid {
            let value = OfflineUIConfiguration.requested(arguments: ["app", "--offline-ui", scene.rawValue, "--offline-password-trace"])
            XCTAssertEqual(value?.passwordProbe, .production, scene.rawValue)
        }
        XCTAssertTrue(PasswordProbeOptions.production.isPrefilled)
        XCTAssertTrue(PasswordProbeOptions.production.isSecure)
        XCTAssertTrue(PasswordProbeOptions.production.contentTypesEnabled)
        XCTAssertFalse(PasswordProbeOptions.production.startsVisible)
        XCTAssertNil(PasswordProbeOptions.production.cell)
    }
    func testPasswordProbeOptionsParseOnHonoringScenes() {
        let form = OfflineUIConfiguration.requested(arguments: ["app", "--offline-ui", "connection-edit", "--offline-password-trace",
            "--offline-password-initial", "empty", "--offline-password-content-type", "off",
            "--offline-password-start-visible", "visible", "--offline-password-cell", "F3-1"])
        XCTAssertEqual(form?.scenario, .connectionEdit)
        XCTAssertEqual(form?.passwordProbe, PasswordProbeOptions(initial: .empty, secure: .secure, contentTypes: .off,
                                                                  visibility: .visible, modifiers: .bare, cell: "F3-1"))
        let probe = OfflineUIConfiguration.requested(arguments: ["app", "--offline-ui", "password-probe-uikit",
            "--offline-password-secure", "plain", "--offline-password-modifiers", "form", "--offline-password-initial", "prefilled"])
        XCTAssertEqual(probe?.scenario, .passwordProbeUIKit)
        XCTAssertEqual(probe?.passwordProbe.secure, .plain)
        XCTAssertEqual(probe?.passwordProbe.modifiers, .form)
        XCTAssertEqual(probe?.passwordProbe.isPrefilled, true)
    }
    func testPasswordProbeMisuseStaysOnTheInvalidScene() {
        let base = ["app", "--offline-ui"]
        let bad: [[String]] = [
            ["connection-edit", "--offline-password-initial"],
            ["connection-edit", "--offline-password-initial", "--offline-password-trace"],
            ["connection-edit", "--offline-password-initial", "unknown"],
            ["connection-edit", "--offline-password-initial", "empty", "--offline-password-initial", "empty"],
            ["connection-edit", "--offline-password-initial=empty"],
            ["connection-edit", "--offline-password-unknown", "x"],
            ["connection-edit", "--offline-password-secure", "plain"],
            ["connection-edit", "--offline-password-modifiers", "form"],
            ["password-probe-swiftui", "--offline-password-start-visible", "visible"],
            ["library", "--offline-password-initial", "empty"],
            ["connection-actions", "--offline-password-initial", "empty"],
            ["connection-edit", "--offline-password-cell", ""],
            ["connection-edit", "--offline-password-cell", "ABCDEFGHIJKLMNOPQ"],
            ["connection-edit", "--offline-password-cell", "a_b"],
            ["connection-edit", "--offline-password-cell", "中文"],
            ["library", "--offline-password-cell", "A1"]
        ]
        for tail in bad {
            XCTAssertEqual(OfflineUIConfiguration.requested(arguments: base + tail)?.scenario, .invalid, tail.joined(separator: " "))
        }
        XCTAssertEqual(OfflineUIConfiguration.requested(arguments: base + ["connection-edit", "--offline-password-cell", "ABCDEFGHIJKLMNOP"])?.scenario, .connectionEdit)
    }
    func testLocalLibrarySceneIsExplicitAndRejectsPasswordFlags() {
        XCTAssertEqual(OfflineUIConfiguration.requested(arguments: ["app", "--offline-ui", "local-library"])?.scenario, .localLibrary)
        XCTAssertEqual(OfflineUIConfiguration.requested(arguments: ["app", "--offline-ui", "local-library",
            "--offline-password-initial", "empty"])?.scenario, .invalid)
        XCTAssertNil(OfflineUIConfiguration.requested(arguments: ["app", "local-library"]))
    }
    func testRootScenesAreExplicitAndRejectPasswordFlags() {
        for (raw, scene) in [("launchpad-root", OfflineUIConfiguration.Scenario.launchpadRoot),
                             ("devices-root", .devicesRoot), ("tasks-root", .tasksRoot)] {
            XCTAssertEqual(OfflineUIConfiguration.requested(arguments: ["app", "--offline-ui", raw])?.scenario, scene)
            XCTAssertEqual(OfflineUIConfiguration.requested(arguments: ["app", "--offline-ui", raw,
                "--offline-password-initial", "empty"])?.scenario, .invalid)
        }
    }
    func testSyntheticDatasetIncludesLayoutBoundariesWithoutEndpoints() {
        let items = OfflineMediaFixture.items
        XCTAssertEqual(Set(items.map(\.id)).count, items.count)
        XCTAssertEqual(items.count % 2, 1)
        XCTAssertTrue(items.contains { !$0.hasArtwork })
        XCTAssertTrue(items.contains { $0.year.isEmpty })
        XCTAssertTrue(items.contains { $0.title.count > 40 })
    }
}
#endif
