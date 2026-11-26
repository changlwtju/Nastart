import XCTest

final class TVLaunchTests: XCTestCase {
    func testOfflineSettingsNASNativeConfirmCancelAndFocus() {
        assertOfflineDisconnectConfirmation(kind: "settingsNAS", index: 0)
    }

    func testOfflineConnectionNASNativeConfirmCancelAndFocus() {
        assertOfflineDisconnectConfirmation(kind: "connectionNAS", index: 1)
    }

    func testOfflineJellyfinNativeConfirmCancelAndFocus() {
        assertOfflineDisconnectConfirmation(kind: "jellyfin", index: 2)
    }

    func testOfflineJellyfinNativeConfirmCancelAndFocusLarge() {
        assertOfflineDisconnectConfirmation(kind: "jellyfin", index: 2, textSize: "large")
    }

    private func assertOfflineDisconnectConfirmation(kind: String, index: Int, textSize: String = "standard") {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--offline-ui", "account-connections", "--offline-ui-confirmations",
                               "--offline-ui-theme", "glassDeck", "--offline-ui-appearance", "dark",
                               "--offline-ui-text-size", textSize]
        app.launchEnvironment = [:]
        app.launch(); defer { app.terminate() }
        let kinds = ["settingsNAS", "connectionNAS", "jellyfin"]
        XCTAssertTrue(app.buttons["offline.disconnect.open.settingsNAS"].waitForExistence(timeout: 10))
        assertOfflineFocus("offline.disconnect.open.settingsNAS", in: app)
        if index > 0 {
            for offset in 1...index { offlineStep(.down, "offline.disconnect.open." + kinds[offset], app) }
        }
        let opener = "offline.disconnect.open." + kind
        let confirm = "tv.disconnect.confirm." + kind
        let cancel = "tv.disconnect.cancel." + kind
        let feedback = app.staticTexts["offline.disconnect.feedback"]
        let result = app.staticTexts["offline.disconnect.result"]
        XCTAssertEqual(feedback.label, "旧错误（合成）")
        XCTAssertEqual(result.label, "attempts=0 · kind=none · cleared=false")
        func open() {
            assertOfflineFocus(opener, in: app)
            XCUIRemote.shared.press(.select)
            XCTAssertTrue(app.buttons[confirm].waitForExistence(timeout: 5), app.debugDescription)
            XCTAssertTrue(app.buttons[cancel].exists)
            keepOfflineAccountScreenshot("disconnect-\(kind)-\(textSize)-native-dialog", app)
        }
        func choose(_ target: String, direction: XCUIRemote.Button) {
            // tvOS wraps the identified SwiftUI Button in a focus-owning UIKit Button.
            // Resolve that native parent from its identified descendant, within this sheet.
            let native = app.sheets.buttons.containing(.button, identifier: target).firstMatch
            XCTAssertTrue(native.exists, app.debugDescription)
            if !native.hasFocus { XCUIRemote.shared.press(direction) }
            let focused = XCTNSPredicateExpectation(predicate: NSPredicate { object, _ in
                (object as? XCUIElement)?.hasFocus == true
            }, object: native)
            XCTAssertEqual(XCTWaiter.wait(for: [focused], timeout: 4), .completed, app.debugDescription)
            XCUIRemote.shared.press(.select)
            XCTAssertTrue(app.buttons[confirm].waitForNonExistence(timeout: 5))
            assertOfflineFocus(opener, in: app)
        }
        open()
        choose(cancel, direction: .left)
        XCTAssertEqual(feedback.label, "旧错误（合成）")
        XCTAssertEqual(result.label, "attempts=0 · kind=none · cleared=false")
        open()
        XCUIRemote.shared.press(.menu)
        XCTAssertTrue(app.buttons[confirm].waitForNonExistence(timeout: 5))
        XCTAssertEqual(app.state, .runningForeground)
        assertOfflineFocus(opener, in: app)
        XCTAssertEqual(feedback.label, "旧错误（合成）")
        XCTAssertEqual(result.label, "attempts=0 · kind=none · cleared=false")
        open()
        choose(confirm, direction: .right)
        XCTAssertEqual(feedback.label, "本次失败（合成）")
        XCTAssertEqual(result.label, "attempts=1 · kind=\(kind) · cleared=true")
        open()
        choose(cancel, direction: .left)
        XCTAssertEqual(feedback.label, "本次失败（合成）")
        XCTAssertEqual(result.label, "attempts=1 · kind=\(kind) · cleared=true")
        keepOfflineAccountScreenshot("disconnect-\(kind)-\(textSize)-after-confirm-and-cancel", app)
    }

    func testOfflinePlayerServicesRemainReadableAndMenuReturns() {
        assertOfflinePlayerServices(theme: "glassDeck", appearance: "dark", textSize: "standard")
    }

    func testOfflinePlayerServicesCleanGridLightLarge() {
        assertOfflinePlayerServices(theme: "cleanGrid", appearance: "light", textSize: "large")
    }

    func testOfflinePlayerServicesCommandCenterDark() {
        assertOfflinePlayerServices(theme: "commandCenter", appearance: "dark", textSize: "standard")
    }

    private func assertOfflinePlayerServices(theme: String, appearance: String, textSize: String) {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--offline-ui", "settings", "--offline-ui-theme", theme,
                               "--offline-ui-appearance", appearance, "--offline-ui-text-size", textSize]
        app.launchEnvironment = [:]
        app.launch()
        XCTAssertTrue(app.buttons["offline.settings.plus"].waitForExistence(timeout: 10))
        defer { app.terminate() }
        offlineStep(.right, "offline.settings.appearance", app)
        offlineStep(.right, "offline.settings.player", app)
        XCUIRemote.shared.press(.select)
        let products = ["jellyfin", "emby", "plex", "navidrome"]
        let states = ["已保存独立授权", "尚未确认", "清单显示未运行", "清单显示已安装"]
        var previousY: CGFloat = -.infinity
        for (product, state) in zip(products, states) {
            let row = app.descendants(matching: .any)["player.integration." + product]
            XCTAssertTrue(row.waitForExistence(timeout: 5))
            XCTAssertTrue(row.label.contains(state), row.label)
            XCTAssertGreaterThan(row.frame.minY, previousY)
            previousY = row.frame.minY
        }
        let notice = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "服务清单与登录授权分别管理")).firstMatch
        XCTAssertTrue(notice.exists)
        let initialY = notice.frame.minY
        let initial = XCTAttachment(screenshot: app.screenshot())
        initial.name = "player-services-before-remote"; initial.lifetime = .keepAlways; add(initial)
        for _ in 0..<4 {
            if notice.frame.maxY <= app.frame.maxY { break }
            XCUIRemote.shared.press(.down)
        }
        let final = XCTAttachment(screenshot: app.screenshot())
        final.name = "player-services-after-remote"; final.lifetime = .keepAlways; add(final)
        let geometry = XCTAttachment(string: "notice.initialY=\(initialY)\nnotice.final=\(notice.frame)\nviewport=\(app.frame)\n" + app.debugDescription)
        geometry.name = "player-services-geometry"; geometry.lifetime = .keepAlways; add(geometry)
        XCTAssertGreaterThanOrEqual(notice.frame.minY, app.navigationBars.firstMatch.frame.maxY)
        XCTAssertLessThanOrEqual(notice.frame.maxY, app.frame.maxY, "Remote must reveal the full explanation within the visible page")
        XCUIRemote.shared.press(.menu)
        assertOfflineFocus("offline.settings.player", in: app)
    }

    func testOfflineAppearanceCardOptionsToggleAndReturn() {
        let app = launchOfflineRetryFocus("settings", first: "offline.settings.plus")
        defer { app.terminate() }
        assertOfflineFocus("offline.settings.plus", in: app)
        offlineStep(.right, "offline.settings.appearance", app)
        XCUIRemote.shared.press(.select)
        let ids = ["compactMetrics", "showServiceStatus", "showCardSubtitle"].map { "appearance.cards." + $0 }
        XCTAssertTrue(app.descendants(matching: .any)[ids[0]].waitForExistence(timeout: 5))
        assertOfflineFocus(ids[0], in: app)
        let before = XCTAttachment(screenshot: app.screenshot()); before.name = "appearance-card-options-initial"
        before.lifetime = .keepAlways; add(before)
        var originals: [String] = []
        var changed: [String] = []
        for (index, id) in ids.enumerated() {
            if index > 0 { offlineStep(.down, id, app) }
            let option = app.descendants(matching: .any)[id]
            XCTAssertTrue(option.isHittable)
            let original = option.value as? String
            XCTAssertNotNil(original, "Native toggle must expose its current state")
            originals.append(original ?? "")
            XCUIRemote.shared.press(.select)
            let updated = XCTNSPredicateExpectation(predicate: NSPredicate { object, _ in
                guard let value = (object as? XCUIElement)?.value as? String else { return false }
                return value != original
            }, object: option)
            XCTAssertEqual(XCTWaiter.wait(for: [updated], timeout: 3), .completed)
            changed.append(option.value as? String ?? "")
            assertOfflineFocus(id, in: app)
        }
        let after = XCTAttachment(screenshot: app.screenshot()); after.name = "appearance-card-options-toggled"
        after.lifetime = .keepAlways; add(after)
        XCUIRemote.shared.press(.menu)
        assertOfflineFocus("offline.settings.appearance", in: app)
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(app.descendants(matching: .any)[ids[0]].waitForExistence(timeout: 5))
        assertOfflineFocus(ids[0], in: app)
        for (index, id) in ids.enumerated() {
            if index > 0 { offlineStep(.down, id, app) }
            let option = app.descendants(matching: .any)[id]
            XCTAssertEqual(option.value as? String, changed[index], "Preview state should survive child navigation")
            XCUIRemote.shared.press(.select)
            let restored = XCTNSPredicateExpectation(predicate: NSPredicate { object, _ in
                (object as? XCUIElement)?.value as? String == originals[index]
            }, object: option)
            XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 3), .completed)
            assertOfflineFocus(id, in: app)
        }
    }

    func testOfflineAccountCardsRemoteTransitionsKeepSafeAddresses() {
        let app = launchOfflineRetryFocus("account-connections", first: "offline.accounts.nas")
        defer { app.terminate() }
        let nas = app.buttons["offline.accounts.nas"]
        let jellyfin = app.buttons["offline.accounts.jellyfin"]
        XCTAssertTrue(nas.isHittable)
        XCTAssertTrue(jellyfin.isHittable)
        assertOfflineFocus("offline.accounts.nas", in: app)
        XCTAssertTrue(app.staticTexts["已保存登录配置"].exists)
        XCTAssertTrue(app.staticTexts["https://nas.invalid:5001/dsm"].exists)
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == %@", "未连接")).count, 1)
        assertOfflineAccountAddressPrivacy(app)
        keepOfflineAccountScreenshot("nas-saved-jellyfin-empty", app)

        XCUIRemote.shared.press(.select)
        XCTAssertTrue(app.staticTexts["已保存登录配置"].waitForNonExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == %@", "未连接")).count, 2)
        XCTAssertTrue(app.staticTexts["https://nas.invalid:5001/dsm"].waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["离线预览：仅切换合成配置，未连接、授权或移除任何服务器。"].exists)
        assertOfflineFocus("offline.accounts.nas", in: app)

        offlineStep(.right, "offline.accounts.jellyfin", app)
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(app.staticTexts["已保存授权"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["https://media.invalid:8920/jellyfin"].exists)
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == %@", "未连接")).count, 1)
        assertOfflineFocus("offline.accounts.jellyfin", in: app)
        assertOfflineAccountAddressPrivacy(app)
        keepOfflineAccountScreenshot("nas-empty-jellyfin-saved", app)

        XCUIRemote.shared.press(.select)
        XCTAssertTrue(app.staticTexts["已保存授权"].waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["https://media.invalid:8920/jellyfin"].waitForNonExistence(timeout: 3))
        offlineStep(.left, "offline.accounts.nas", app)
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(app.staticTexts["已保存登录配置"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["https://nas.invalid:5001/dsm"].exists)
        assertOfflineFocus("offline.accounts.nas", in: app)
        assertOfflineAccountAddressPrivacy(app)
    }

    private func assertOfflineAccountAddressPrivacy(_ app: XCUIApplication) {
        let sensitive = NSPredicate(format: "label CONTAINS %@ OR label CONTAINS %@ OR label CONTAINS %@ OR label CONTAINS %@",
                                    "fixture-only", "fixture:", "?api_key=", "#fixture")
        XCTAssertEqual(app.staticTexts.matching(sensitive).count, 0)
    }

    private func keepOfflineAccountScreenshot(_ name: String, _ app: XCUIApplication) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }

    func testOfflineFolderEditorRemoteSaveCancelAndReturnToBrowse() {
        let app = launchOfflineRetryFocus("folder-edit", first: "network.folderEdit.browse")
        defer { app.terminate() }
        let save = app.buttons["network.folderEdit.save"]
        let note = app.staticTexts["network.folderEdit.note"]
        XCTAssertFalse(save.isEnabled)
        XCTAssertFalse(note.exists)
        reachFolderBrowse(app)
        XCUIRemote.shared.press(.select)
        XCTAssertEqual(app.textFields["network.folderEdit.path"].value as? String, "/video/合成目录")
        XCTAssertTrue(save.isEnabled)
        offlineStep(.down, "network.folderEdit.save", app)
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(note.waitForExistence(timeout: 3))
        XCTAssertEqual(note.label, "仅完成离线路径检查，未验证服务器或保存媒体库。")
        offlineStep(.down, "network.folderEdit.cancel", app)
        XCUIRemote.shared.press(.select)
        XCTAssertEqual(note.label, "已取消离线草稿，原配置未改动。")
        offlineStep(.up, "network.folderEdit.save", app)
        offlineStep(.up, "network.folderEdit.browse", app)
        // Selecting the same synthetic directory does not simulate a new edit.
        XCUIRemote.shared.press(.select)
        XCTAssertEqual(app.staticTexts["network.folderEdit.currentPath"].label, "/video/电影 100%")
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.lifetime = .keepAlways; add(shot)
    }

    func testOfflineFolderEditorBrowseClearsInitialFailure() {
        let app = launchOfflineRetryFocus("folder-edit-error", first: "network.folderEdit.browse")
        defer { app.terminate() }
        XCTAssertTrue(app.staticTexts["network.folderEdit.error"].exists)
        XCTAssertFalse(app.staticTexts["network.folderEdit.note"].exists)
        reachFolderBrowse(app)
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(app.staticTexts["network.folderEdit.error"].waitForNonExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["network.folderEdit.note"].exists)
        offlineStep(.down, "network.folderEdit.save", app)
        XCUIRemote.shared.press(.select)
        XCTAssertEqual(app.staticTexts["network.folderEdit.note"].label, "仅完成离线路径检查，未验证服务器或保存媒体库。")
        XCTAssertEqual(app.staticTexts["network.folderEdit.currentPath"].label, "/video/电影 100%")
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.lifetime = .keepAlways; add(shot)
    }

    private func reachFolderBrowse(_ app: XCUIApplication) {
        let browse = app.buttons["network.folderEdit.browse"]
        // Observe the native initial focus; do not assign focus from the test.
        for _ in 0..<5 {
            if browse.hasFocus { break }
            XCUIRemote.shared.press(.down)
        }
        assertOfflineFocus("network.folderEdit.browse", in: app)
        XCTAssertTrue(browse.isHittable)
    }

    func testOfflineRelatedRetryFocusReturnsAndRecoversAfterRetry() {
        let app = launchOfflineRetryFocus("detail-focus-retry")
        defer { app.terminate() }
        assertOfflineFocus("tv.play", in: app)
        offlineStep(.down, "tv.detail.person.p1", app)
        offlineStep(.right, "tv.detail.person.p2", app)
        offlineStep(.down, "tv.detail.similar.r1", app)
        offlineStep(.right, "tv.detail.similar.r2", app)
        offlineStep(.down, "tv.detail.similar.retry", app)
        XCTAssertTrue(app.buttons["tv.detail.similar.retry"].isHittable)
        offlineStep(.up, "tv.detail.similar.r2", app)
        offlineStep(.down, "tv.detail.similar.retry", app)
        offlineStep(.down, "tv.detail.files", app)
        offlineStep(.up, "tv.detail.similar.retry", app)
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(app.buttons["tv.detail.similar.retry"].waitForNonExistence(timeout: 3))
        assertOfflineFocus("tv.detail.similar.r2", in: app)
        XCTAssertEqual(app.staticTexts["offline.focus.receipt"].label, "重试次数：1")
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.lifetime = .keepAlways; add(shot)
    }
    func testOfflineRetryReachableWithoutCastOrRelatedCards() {
        let app = launchOfflineRetryFocus("detail-focus-retry-empty")
        defer { app.terminate() }
        assertOfflineFocus("tv.play", in: app)
        offlineStep(.down, "tv.detail.similar.retry", app)
        offlineStep(.down, "tv.detail.files", app)
        offlineStep(.up, "tv.detail.similar.retry", app)
        offlineStep(.up, "tv.play", app)
        offlineStep(.down, "tv.detail.similar.retry", app)
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(app.buttons["tv.detail.similar.retry"].waitForNonExistence(timeout: 3))
        assertOfflineFocus("tv.detail.files", in: app)
        XCTAssertEqual(app.staticTexts["offline.focus.receipt"].label, "重试次数：1")
    }
    func testOfflineRetryRemovalFallsBackToHeroWhenNoLowerContentExists() {
        let app = launchOfflineRetryFocus("detail-focus-retry-only")
        defer { app.terminate() }
        assertOfflineFocus("tv.play", in: app)
        offlineStep(.down, "tv.detail.similar.retry", app)
        offlineStep(.up, "tv.play", app)
        offlineStep(.down, "tv.detail.similar.retry", app)
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(app.buttons["tv.detail.similar.retry"].waitForNonExistence(timeout: 3))
        assertOfflineFocus("tv.play", in: app)
        XCTAssertEqual(app.staticTexts["offline.focus.receipt"].label, "重试次数：1")
    }
    func testOfflineHeroActionsRecoverWhenRetryAndOverviewDisappear() {
        let app = launchOfflineRetryFocus("detail-focus-actions")
        defer { app.terminate() }
        assertOfflineFocus("tv.play", in: app)
        offlineStep(.right, "tv.detail.overview", app)
        offlineStep(.down, "tv.detail.person.p1", app)
        offlineStep(.up, "tv.detail.overview", app)
        // The semantic action order reaches retry even when it occupies its own visual row.
        offlineStep(.right, "tv.detail.retry", app)
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(app.buttons["tv.detail.retry"].waitForNonExistence(timeout: 3))
        assertOfflineFocus("tv.play", in: app)
        XCTAssertEqual(app.staticTexts["offline.focus.receipt"].label, "重试次数：1")
        offlineStep(.right, "tv.detail.overview", app)
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(app.buttons["tv.detail.overview"].waitForNonExistence(timeout: 3))
        assertOfflineFocus("tv.play", in: app)
        offlineStep(.down, "tv.detail.person.p1", app)
        offlineStep(.up, "tv.play", app)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.lifetime = .keepAlways; add(shot)
    }
    func testOfflineNetworkFilesReturnToSelectedSegmentAndKeepEditReachable() {
        let app = launchOfflineRetryFocus("network-focus-files", first: "network.file.overview")
        defer { app.terminate() }
        assertOfflineFocus("network.file.overview", in: app)
        offlineStep(.down, "network.file.member.one", app)
        offlineStep(.down, "network.file.member.two", app)
        XCUIRemote.shared.press(.select)
        XCTAssertEqual(app.staticTexts["offline.file.receipt"].label, "选择次数：1")
        offlineStep(.down, "network.detail.person.one", app)
        offlineStep(.right, "network.detail.person.two", app)
        offlineStep(.up, "network.file.member.two", app)
        offlineStep(.up, "network.file.member.one", app)
        offlineStep(.up, "network.file.overview", app)
        offlineStep(.down, "network.file.member.one", app)
        offlineStep(.down, "network.file.member.two", app)
        offlineStep(.down, "network.detail.person.one", app)
        offlineStep(.down, "network.file.information", app)
        XCUIRemote.shared.press(.select)
        XCTAssertEqual(app.buttons["network.file.information"].value as? String, "已展开")
        offlineStep(.down, "network.file.edit", app)
        offlineStep(.up, "network.file.information", app)
        XCTAssertFalse(app.buttons["network.file.readOnly"].exists)
        offlineStep(.up, "network.detail.person.one", app)
        offlineStep(.up, "network.file.member.two", app)
        offlineStep(.up, "network.file.member.one", app)
        offlineStep(.up, "network.file.overview", app)
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(app.buttons["network.file.overview"].waitForNonExistence(timeout: 3))
        assertOfflineFocus("network.file.member.one", in: app)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.lifetime = .keepAlways; add(shot)
    }
    func testOfflineReadOnlyNetworkDetailStartsAtFileInformation() {
        let app = launchOfflineRetryFocus("network-focus-read-only", first: "network.file.information")
        defer { app.terminate() }
        assertOfflineFocus("network.file.information", in: app)
        XCTAssertFalse(app.buttons["network.file.readOnly"].exists)
        XCTAssertFalse(app.buttons["network.file.play"].exists)
        XCUIRemote.shared.press(.select)
        offlineStep(.down, "network.file.edit", app)
        offlineStep(.up, "network.file.information", app)
        XCTAssertEqual(app.staticTexts["offline.file.receipt"].label, "选择次数：0")
    }
    func testOfflineChangingFilesAndPeoplePreservesValidAndNativeFocus() {
        let app = launchOfflineRetryFocus("network-focus-dynamic", first: "offline.change.overview")
        defer { app.terminate() }
        assertOfflineFocus("offline.change.overview", in: app)
        offlineStep(.down, "offline.change.file.1", app)
        offlineStep(.down, "offline.change.file.2", app)
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(app.buttons["offline.change.file.2"].waitForNonExistence(timeout: 3))
        assertOfflineFocus("offline.change.file.1", in: app)
        offlineStep(.down, "offline.change.person.A", app)
        offlineStep(.right, "offline.change.person.B", app)
        offlineAdvanceVersion(1, app)
        assertOfflineFocus("offline.change.person.B", in: app)
        offlineStep(.right, "offline.change.person.B", app)
        offlineStep(.left, "offline.change.person.A", app)
        offlineAdvanceVersion(2, app)
        assertOfflineFocus("offline.change.person.C", in: app)
        offlineAdvanceVersion(3, app)
        assertOfflineFocus("offline.change.person.C", in: app)
        XCTAssertFalse(app.buttons["offline.change.file.1"].exists)
        offlineStep(.down, "offline.change.info", app)
        XCUIRemote.shared.press(.select)
        offlineStep(.down, "offline.change.edit", app)
        offlineAdvanceVersion(4, app)
        assertOfflineFocus("offline.change.edit", in: app)
        offlineStep(.up, "offline.change.info", app)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.lifetime = .keepAlways; add(shot)
    }
    func testOfflineLongNetworkRowsRevealOffscreenFilesAndPeople() {
        let app = launchOfflineRetryFocus("network-focus-long", first: "offline.change.overview")
        defer { app.terminate() }
        assertOfflineFocus("offline.change.overview", in: app)
        let lastFile = app.buttons["offline.change.file.12"]
        let beforeY = lastFile.frame.minY
        XCTAssertGreaterThan(beforeY, app.frame.maxY)
        XCTAssertFalse(lastFile.isHittable)
        for i in 1...12 { offlineStep(.down, "offline.change.file.\(i)", app) }
        XCTAssertTrue(lastFile.isHittable)
        XCTAssertTrue(lastFile.frame.intersects(app.frame))
        let afterY = lastFile.frame.minY
        XCTAssertGreaterThan(beforeY - afterY, app.frame.height * 0.3)
        let fileShot = XCTAttachment(screenshot: app.screenshot()); fileShot.lifetime = .keepAlways; add(fileShot)
        offlineStep(.down, "offline.change.person.1", app)
        let lastPerson = app.descendants(matching: .any)["offline.change.person.18"]
        XCTAssertFalse(lastPerson.isHittable)
        for i in 2...18 { offlineStep(.right, "offline.change.person.\(i)", app) }
        XCTAssertTrue(lastPerson.isHittable)
        XCTAssertTrue(lastPerson.frame.intersects(app.frame))
        let personShot = XCTAttachment(screenshot: app.screenshot()); personShot.lifetime = .keepAlways; add(personShot)
        for i in stride(from: 17, through: 1, by: -1) { offlineStep(.left, "offline.change.person.\(i)", app) }
        offlineStep(.up, "offline.change.file.12", app)
        for i in stride(from: 11, through: 1, by: -1) { offlineStep(.up, "offline.change.file.\(i)", app) }
        offlineStep(.up, "offline.change.overview", app)
        XCTAssertTrue(app.buttons["offline.change.overview"].isHittable)
        let metrics = XCTAttachment(string: "vertical.beforeY=\(beforeY)\nvertical.afterY=\(afterY)\nvertical.displacement=\(beforeY - afterY)\nviewport.height=\(app.frame.height)\nhorizontal.initialHittable=false\nhorizontal.finalHittable=true\nframeTiming=notMeasured")
        metrics.lifetime = .keepAlways; add(metrics)
    }
    func testOfflineEditSheetReturnsToNativeEditAfterCloseAndMenu() {
        let app = launchOfflineRetryFocus("network-focus-presentation", first: "offline.presentation.overview")
        defer { app.terminate() }
        assertOfflineFocus("offline.presentation.overview", in: app)
        offlineStep(.down, "offline.presentation.file.1", app)
        offlineStep(.down, "offline.presentation.file.2", app)
        offlineStep(.down, "offline.presentation.info", app)
        XCUIRemote.shared.press(.select)
        offlineStep(.down, "offline.presentation.edit", app)
        for (index, close) in [XCUIRemote.Button.select, .menu].enumerated() {
            XCUIRemote.shared.press(.select)
            XCTAssertTrue(app.buttons["offline.presentation.sheet.close"].waitForExistence(timeout: 4))
            assertOfflineFocus("offline.presentation.sheet.close", in: app)
            XCUIRemote.shared.press(close)
            XCTAssertTrue(app.buttons["offline.presentation.sheet.close"].waitForNonExistence(timeout: 4))
            assertOfflineFocus("offline.presentation.edit", in: app)
            XCTAssertEqual(app.staticTexts["offline.presentation.receipt"].label, "编辑返回：\(index + 1)；全屏返回：0")
        }
        offlineStep(.up, "offline.presentation.info", app)
        offlineStep(.up, "offline.presentation.file.2", app)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.lifetime = .keepAlways; add(shot)
    }
    func testOfflineFullScreenReturnsToSelectedFileAfterCloseAndMenu() {
        let app = launchOfflineRetryFocus("network-focus-presentation", first: "offline.presentation.overview")
        defer { app.terminate() }
        assertOfflineFocus("offline.presentation.overview", in: app)
        offlineStep(.down, "offline.presentation.file.1", app)
        offlineStep(.down, "offline.presentation.file.2", app)
        for (index, close) in [XCUIRemote.Button.select, .menu].enumerated() {
            XCUIRemote.shared.press(.select)
            XCTAssertTrue(app.buttons["offline.presentation.cover.close"].waitForExistence(timeout: 4))
            assertOfflineFocus("offline.presentation.cover.close", in: app)
            XCUIRemote.shared.press(close)
            XCTAssertTrue(app.buttons["offline.presentation.cover.close"].waitForNonExistence(timeout: 4))
            assertOfflineFocus("offline.presentation.file.2", in: app)
            XCTAssertEqual(app.staticTexts["offline.presentation.receipt"].label, "编辑返回：0；全屏返回：\(index + 1)")
        }
        offlineStep(.up, "offline.presentation.file.1", app)
        offlineStep(.up, "offline.presentation.overview", app)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.lifetime = .keepAlways; add(shot)
    }
    // Diagnostic wrapper reuses identical assertions; it adds no acceptance coverage.
    func testOfflineDynamicFocusDiagnosticWindow() {
        testOfflineChangingFilesAndPeoplePreservesValidAndNativeFocus()
    }
    private func offlineAdvanceVersion(_ expected: Int, _ app: XCUIApplication) {
        XCUIRemote.shared.press(.playPause)
        let label = app.staticTexts["offline.change.version"]
        let match = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "资料版本：\(expected)"), object: label)
        XCTAssertEqual(XCTWaiter.wait(for: [match], timeout: 4), .completed)
    }
    private func launchOfflineRetryFocus(_ scene: String, first: String = "tv.play") -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--offline-ui", scene, "--offline-ui-theme", "glassDeck", "--offline-ui-appearance", "dark"]
        if name.contains("DiagnosticWindow") { app.launchArguments.append("--offline-focus-trace") }
        app.launchEnvironment = [:]
        app.launch()
        XCTAssertTrue(app.buttons[first].waitForExistence(timeout: 10))
        return app
    }
    private func offlineStep(_ key: XCUIRemote.Button, _ id: String, _ app: XCUIApplication) {
        XCUIRemote.shared.press(key)
        assertOfflineFocus(id, in: app)
    }
    private func assertOfflineFocus(_ id: String, in app: XCUIApplication) {
        let element = app.descendants(matching: .any)[id]
        let expected = XCTNSPredicateExpectation(predicate: NSPredicate { object, _ in
            (object as? XCUIElement)?.hasFocus == true
        }, object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: 4), .completed, "Expected \(id): \(app.debugDescription)")
    }
    func testMenuClosesFullScreenWithButtonFocus() {
        assertMenuClosesFullScreen(mode: "button")
    }

    func testMenuClosesFullScreenWithPlayerSliderFocus() {
        assertMenuClosesFullScreen(mode: "slider")
    }

    func testMenuClosesUnpreparedKSPlayerSurface() { assertPlayerMenu(mode: "player-ks") }
    func testMenuClosesUnpreparedAVPlayerSurface() { assertPlayerMenu(mode: "player-av") }
    func testMenuClosesNativeJellyfinPlayerSurface() { assertPlayerMenu(mode: "player-native-av") }

    func testNativePlayerMenuClosesPanelBeforeClosingPlayback() {
        let app = XCUIApplication()
        app.launchArguments = ["--tv-exit-probe", "player-native-av"]
        app.launchEnvironment = [:]
        app.launch()
        XCTAssertTrue(app.buttons["tv.exit.probe.open"].waitForExistence(timeout: 10))
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(app.buttons["tv.player.play"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["tv.player.play"].hasFocus)
        for _ in 0..<4 { XCUIRemote.shared.press(.right) }
        XCTAssertTrue(app.buttons["tv.player.more"].hasFocus)
        XCUIRemote.shared.press(.select)
        let option = app.buttons["tv.player.option.panel.first"]
        XCTAssertTrue(option.waitForExistence(timeout: 3))
        XCTAssertTrue(option.hasFocus)
        XCUIRemote.shared.press(.menu)
        XCTAssertTrue(option.waitForNonExistence(timeout: 3), "Back must close the settings panel first")
        XCTAssertTrue(app.buttons["tv.player.play"].exists)
        XCUIRemote.shared.press(.menu)
        XCTAssertTrue(app.buttons["tv.player.play"].waitForNonExistence(timeout: 3), "Second Back must close playback")
        XCTAssertTrue(app.staticTexts["tv.exit.probe.receipt"].label.contains("disappeared=1"))
        app.terminate()
    }

    func testSourceSubtitleMenuRemainsReachableAfterOffAndRepeatedSelection() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--tv-exit-probe", "player-native-tracks"]; app.launchEnvironment = [:]
        app.launch(); defer { app.terminate() }
        func step(_ key: XCUIRemote.Button, _ id: String) {
            let before = app.staticTexts["tv.player.focus.events"].label
            XCUIRemote.shared.press(key)
            let trace = app.staticTexts["tv.player.focus.events"]
            let nativeTarget = NSPredicate { object, _ in
                (object as? XCUIElement)?.label.split(separator: "|").last.map(String.init) == id
            }
            let wait = XCTNSPredicateExpectation(predicate: nativeTarget, object: trace)
            XCTAssertEqual(XCTWaiter.wait(for: [wait], timeout: 3), .completed, app.debugDescription)
            let events = String(app.staticTexts["tv.player.focus.events"].label.dropFirst(before.count)).split(separator: "|").map(String.init)
            XCTAssertTrue(events.allSatisfy { $0 == id }, "Unexpected intermediate native focus: \(events)")
        }
        XCTAssertTrue(app.buttons["tv.exit.probe.open"].waitForExistence(timeout: 10)); XCUIRemote.shared.press(.select)
        XCTAssertTrue(app.buttons["tv.player.play"].waitForExistence(timeout: 5))
        step(.right, "tv.player.forward"); step(.right, "tv.player.audio"); step(.right, "tv.player.subtitles")
        step(.select, "tv.player.option.panel.first")
        XCUIRemote.shared.press(.select)
        XCTAssertEqual(app.staticTexts["tv.player.focus.events"].label.split(separator: "|").last.map(String.init), "tv.player.option.panel.first")
        XCUIRemote.shared.press(.select)
        XCTAssertEqual(app.staticTexts["tv.player.focus.events"].label.split(separator: "|").last.map(String.init), "tv.player.option.panel.first")
        step(.down, "tv.player.option.subtitle.4")
        XCUIRemote.shared.press(.select)
        XCTAssertEqual(app.staticTexts["tv.player.focus.events"].label.split(separator: "|").last.map(String.init), "tv.player.option.subtitle.4")
        step(.up, "tv.player.option.panel.first")
        XCUIRemote.shared.press(.select)
        step(.down, "tv.player.option.subtitle.4")
        XCUIRemote.shared.press(.menu)
        XCTAssertFalse(app.buttons["tv.player.option.panel.first"].exists); XCTAssertTrue(app.buttons["tv.player.play"].exists)
        XCUIRemote.shared.press(.menu); XCTAssertTrue(app.buttons["tv.player.play"].waitForNonExistence(timeout: 3))
    }

    func testRootTabsHideForPushedPagesAndReturnAfterTwoBacks() {
        let app = XCUIApplication()
        app.launchArguments = ["--tv-exit-probe", "navigation"]
        app.launchEnvironment = [:]
        app.launch()
        let tab = app.buttons["tv.tab.launchpad"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        let open = app.buttons["tv.nav.probe.open"]
        for _ in 0..<8 {
            if open.hasFocus { break }
            XCUIRemote.shared.press(.down)
        }
        XCTAssertTrue(open.hasFocus)
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(app.staticTexts["tv.nav.probe.child.1"].waitForExistence(timeout: 3))
        XCTAssertFalse(tab.isHittable, "Global navigation must be absent from child pages")
        let next = app.buttons["tv.nav.probe.next"]
        for _ in 0..<4 {
            if next.hasFocus { break }
            XCUIRemote.shared.press(.down)
        }
        XCTAssertTrue(next.hasFocus)
        XCUIRemote.shared.press(.select)
        XCTAssertTrue(app.staticTexts["tv.nav.probe.child.2"].waitForExistence(timeout: 3))
        XCUIRemote.shared.press(.menu)
        XCTAssertTrue(next.waitForExistence(timeout: 3))
        XCTAssertFalse(tab.isHittable)
        XCUIRemote.shared.press(.menu)
        XCTAssertTrue(open.waitForExistence(timeout: 3))
        XCTAssertTrue(tab.isHittable)
        XCTAssertEqual(app.state, .runningForeground)
        let image = XCTAttachment(screenshot: app.screenshot()); image.lifetime = .keepAlways; add(image)
        app.terminate()
    }

    func testCastEdgesMoveUpToHeroAndDownToRelatedShelf() {
        let app = XCUIApplication()
        app.launchArguments = ["--tv-exit-probe", "detail-focus"]
        app.launchEnvironment = [:]
        app.launch()
        defer { app.terminate() }
        let play = app.buttons["tv.play"]
        XCTAssertTrue(play.waitForExistence(timeout: 10))
        XCTAssertTrue(play.hasFocus)
        XCUIRemote.shared.press(.down)
        let people = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "tv.detail.person."))
        for _ in 0..<15 {
            if app.descendants(matching: .any)["tv.detail.person.cast-0"].hasFocus { break }
            XCUIRemote.shared.press(.left)
        }
        let first = app.descendants(matching: .any)["tv.detail.person.cast-0"]
        XCTAssertTrue(first.hasFocus, "First cast member must be reachable")
        XCUIRemote.shared.press(.up)
        XCTAssertTrue(play.hasFocus || app.buttons["tv.play.restart"].hasFocus,
            "Up from the cast below the poster must bridge the leading gap")
        XCUIRemote.shared.press(.down)
        for _ in 0..<14 { XCUIRemote.shared.press(.right) }
        let last = app.descendants(matching: .any)["tv.detail.person.cast-11"]
        XCTAssertTrue(last.hasFocus, "Right must reach the last cast member")
        XCUIRemote.shared.press(.up)
        XCTAssertTrue(play.hasFocus || app.buttons["tv.play.restart"].hasFocus,
            "Up from the far edge must also reach the hero")
        XCUIRemote.shared.press(.down)
        XCTAssertTrue(people.allElementsBoundByIndex.contains(where: { $0.hasFocus }))
        XCUIRemote.shared.press(.down)
        XCTAssertTrue(app.buttons.allElementsBoundByIndex.contains(where: { $0.label.contains("相似影片") && $0.hasFocus }),
            "Down must enter the related shelf rather than strand focus on the cast")
        let image = XCTAttachment(screenshot: app.screenshot()); image.lifetime = .keepAlways; add(image)
    }

    /// Every key has an exact expected target. No corrective Left presses or
    /// "any item in the next region" assertion may conceal a wrong landing.
    func testOrderedDetailFocusRoundTrip() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--tv-exit-probe", "detail-focus"]
        app.launchEnvironment = [:]
        app.launch()
        defer { app.terminate() }
        func target(_ id: String) -> XCUIElement { app.descendants(matching: .any)[id] }
        func step(_ key: XCUIRemote.Button, _ id: String, file: StaticString = #filePath, line: UInt = #line) {
            let before = app.staticTexts["tv.detail.focus.events"].label
            XCUIRemote.shared.press(key)
            let element = target(id)
            let focused = NSPredicate(format: "hasFocus == true")
            let wait = XCTNSPredicateExpectation(predicate: focused, object: element)
            XCTAssertEqual(XCTWaiter.wait(for: [wait], timeout: 3), .completed,
                "\(key) must land on \(id). \(app.debugDescription)", file: file, line: line)
            let after = app.staticTexts["tv.detail.focus.events"].label
            let events = String(after.dropFirst(before.count)).split(separator: "|").map(String.init)
            XCTAssertTrue(events.allSatisfy { $0 == id }, "Unexpected intermediate native focus: \(events)", file: file, line: line)
        }
        XCTAssertTrue(app.buttons["tv.play"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["tv.play"].hasFocus)
        step(.down, "tv.detail.person.cast-0")
        step(.right, "tv.detail.person.cast-1")
        step(.right, "tv.detail.person.cast-2")
        step(.left, "tv.detail.person.cast-1")
        step(.down, "tv.detail.similar.related-0")
        step(.right, "tv.detail.similar.related-1")
        step(.right, "tv.detail.similar.related-2")
        step(.left, "tv.detail.similar.related-1")
        step(.up, "tv.detail.person.cast-1")
        step(.right, "tv.detail.person.cast-2")
        step(.left, "tv.detail.person.cast-1")
        step(.up, "tv.play")
        step(.right, "tv.play.restart")
        step(.down, "tv.detail.person.cast-0")
        step(.left, "tv.detail.person.cast-0")
        for index in 1..<12 { step(.right, "tv.detail.person.cast-\(index)") }
        step(.right, "tv.detail.person.cast-11")
        step(.down, "tv.detail.similar.related-0")
        for index in 1..<7 { step(.right, "tv.detail.similar.related-\(index)") }
        step(.right, "tv.detail.similar.related-6")
        step(.left, "tv.detail.similar.related-5")
        step(.up, "tv.detail.person.cast-11")
        step(.left, "tv.detail.person.cast-10")
        step(.up, "tv.play.restart")
        step(.down, "tv.detail.person.cast-0")
        step(.down, "tv.detail.similar.related-0")
        step(.up, "tv.detail.person.cast-0")
        step(.up, "tv.play.restart")
        step(.left, "tv.play")
        let image = XCTAttachment(screenshot: app.screenshot()); image.lifetime = .keepAlways; add(image)
    }

    private func assertPlayerMenu(mode: String) {
        let app = XCUIApplication()
        app.launchArguments = ["--tv-exit-probe", mode]
        app.launchEnvironment = [:]
        app.launch()
        XCTAssertTrue(app.buttons["tv.exit.probe.open"].waitForExistence(timeout: 10))
        XCUIRemote.shared.press(.select)
        let cover = app.staticTexts["tv.exit.probe.cover"]
        XCTAssertTrue(cover.waitForExistence(timeout: 5))
        for _ in 0..<3 {
            XCUIRemote.shared.press(.menu)
            if cover.waitForNonExistence(timeout: 1) { break }
        }
        let events = XCTAttachment(string: app.staticTexts["tv.exit.probe.events"].label + "\n" + app.debugDescription)
        events.lifetime = .keepAlways
        add(events)
        let image = XCTAttachment(screenshot: app.screenshot())
        image.lifetime = .keepAlways
        add(image)
        XCTAssertFalse(cover.exists, "Three Menu commands must close the full player surface")
        XCTAssertTrue(app.staticTexts["tv.exit.probe.receipt"].label.contains("disappeared=1"))
        app.terminate()
    }

    private func assertMenuClosesFullScreen(mode: String) {
        let app = XCUIApplication()
        app.launchArguments = ["--tv-exit-probe", mode]
        app.launchEnvironment = [:]
        app.launch()
        let open = app.buttons["tv.exit.probe.open"]
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        XCUIRemote.shared.press(.select)
        let cover = app.staticTexts["tv.exit.probe.cover"]
        XCTAssertTrue(cover.waitForExistence(timeout: 5))
        let target = app.descendants(matching: .any).matching(identifier: "tv.exit.probe.focus").firstMatch
        XCTAssertTrue(target.waitForExistence(timeout: 3))
        XCTAssertTrue(target.hasFocus, "The intended surface must own focus before Menu")
        add(XCTAttachment(string: app.debugDescription))
        XCUIRemote.shared.press(.menu)
        let closed = cover.waitForNonExistence(timeout: 3)
        let image = XCTAttachment(screenshot: app.screenshot())
        image.lifetime = .keepAlways
        add(image)
        XCTAssertTrue(closed, "Menu must dismiss the cover, not leave a focused playback control")
        XCTAssertTrue(app.staticTexts["tv.exit.probe.receipt"].label.contains("received=1 disappeared=1"))
        app.terminate()
    }

    func testNormalLaunchPresentsFocusableLogin() {
        let app = XCUIApplication()
        app.launchArguments = []
        app.launchEnvironment = [:]
        app.launch()
        XCTAssertTrue(app.textFields["tv.server"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.textFields["tv.username"].exists)
        XCTAssertTrue(app.secureTextFields["tv.password"].exists)
        XCTAssertTrue(app.buttons["tv.login"].exists)
        XCTAssertFalse(app.buttons["tv.login"].isEnabled)
        XCTAssertTrue(app.staticTexts["连接服务器"].exists)
        XCTAssertTrue(app.textFields["tv.otp"].exists, "DSM is the default connection, not Jellyfin-only onboarding")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Diagnostic probe (2026-11-20): entering Jellyfin from the Launchpad shows
    /// no media library on the TV although DSM is logged in. Reports findings
    /// with diagnostic output and acceptance assertions in the xcodebuild log. tvOS has no tap()/click() on XCUIElement: focus is moved with the
    /// remote and the element is activated with .select.
    func testJellyfinEntryProbe() {
        let app = XCUIApplication()
        app.launchArguments = []
        app.launchEnvironment = [:]
        app.launch()
        XCTAssertTrue(app.buttons["tv.tab.launchpad"].waitForExistence(timeout: 15), "Launchpad tab must appear")
        // Find a Jellyfin entry: disconnected tile, discovered service tile, or
        // the network-library shortcut (which contains a Jellyfin destination).
        var target: XCUIElement?
        var targetName = "none"
        if app.buttons["tv.open.networkLibrary"].exists {
            target = app.buttons["tv.open.networkLibrary"]; targetName = "tv.open.networkLibrary"
        } else if app.buttons["tv.open.jellyfin"].exists {
            target = app.buttons["tv.open.jellyfin"]; targetName = "tv.open.jellyfin"
        } else {
            let byLabel = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Jellyfin")).firstMatch
            if byLabel.exists { target = byLabel; targetName = "label~Jellyfin" }
            else if app.buttons["tv.open.networkLibrary"].exists {
                target = app.buttons["tv.open.networkLibrary"]; targetName = "tv.open.networkLibrary"
            }
        }
        var opened = false
        var mediaOpened = false
        var mediaEntryExists = false
        if let entry = target {
            opened = focusAndSelect(entry, app: app)
        }
        // Inside the network library, the Jellyfin entry is the saved-media link.
        if opened && targetName == "tv.open.networkLibrary" {
            let media = app.buttons["network.browse.media"]
            mediaEntryExists = media.waitForExistence(timeout: 8)
            if mediaEntryExists {
                mediaOpened = focusAndSelect(media, app: app)
            }
        }
        let needsConnect = app.buttons["tv.connect.jellyfin"].exists
        for title in ["电影", "电视剧", "继续观看"] {
            XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 25), "Missing row: \(title)")
        }
        var seen: [String] = []
        for hint in ["电影", "电视剧", "继续观看", "我的媒体", "音乐"] where app.staticTexts[hint].exists {
            seen.append(hint)
        }
        var errors: [String] = []
        for hint in ["失败", "无法", "错误", "未连接", "登录已失效", "请检查"] {
            if app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", hint)).count > 0 {
                errors.append(hint)
            }
        }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "jellyfin-entry-probe"
        attachment.lifetime = .keepAlways
        add(attachment)
        print("PROBE jellyfin: target=\(targetName) opened=\(opened) mediaEntryExists=\(mediaEntryExists) mediaOpened=\(mediaOpened) needsConnect=\(needsConnect) libraryTitles=\(seen) errorHints=\(errors)")
        XCTAssertTrue(opened)
        XCTAssertFalse(needsConnect)
        XCTAssertTrue(errors.isEmpty, "Unexpected errors: \(errors)")
        for title in ["电影", "电视剧", "继续观看"] { XCTAssertTrue(seen.contains(title), "Missing row: \(title)") }
        XCUIRemote.shared.press(.menu)
        sleep(2)
        if targetName == "tv.open.networkLibrary" {
            XCTAssertTrue(focusAndSelect(app.buttons["network.browse.media"], app: app))
        } else if let target { XCTAssertTrue(focusAndSelect(target, app: app)) }
        for title in ["电影", "电视剧", "继续观看"] { XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 12)) }
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "登录已失效")).firstMatch.exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "失败")).firstMatch.exists)
    }

    /// Diagnostic probe (2026-11-21): user reports subpages under Connection
    /// Management are compressed/squished on the TV. Captures the actual frame
    /// widths of the Connection Management page and its Storage & Media
    /// subpage, against the 1920pt viewport, so the layout defect is measured
    /// rather than described. Connected launchpad uses tv.settings.connections;
    /// disconnected uses tv.home.connections.
    func testConnectionsCompressionProbe() {
        let app = XCUIApplication()
        app.launchArguments = []
        app.launchEnvironment = [:]
        app.launch()
        XCTAssertTrue(app.buttons["tv.tab.launchpad"].waitForExistence(timeout: 15), "Launchpad tab must appear")
        // Connection Management lives on the Mine tab (TVSettingsView), not the
        // Launchpad. Move focus up to the tab bar, then select Mine.
        let mineTab = app.buttons["tv.tab.mine"]
        XCTAssertTrue(mineTab.waitForExistence(timeout: 10), "Mine tab must exist")
        var mineFocused = mineTab.hasFocus
        for _ in 0..<8 where !mineFocused {
            XCUIRemote.shared.press(.up)
            Thread.sleep(forTimeInterval: 0.4)
            mineFocused = mineTab.hasFocus
        }
        var mineOpened = false
        if mineFocused {
            XCUIRemote.shared.press(.select)
            sleep(3)
            mineOpened = true
        } else {
            mineOpened = focusAndSelect(mineTab, app: app)
        }
        var connections = app.buttons["tv.settings.connections"]
        var connID = "tv.settings.connections"
        if !connections.waitForExistence(timeout: 8) {
            connections = app.buttons["tv.home.connections"]
            connID = "tv.home.connections"
        }
        XCTAssertTrue(connections.exists, "Connection Management tile must exist")
        let opened = focusAndSelect(connections, app: app)
        sleep(3)
        let heading = app.descendants(matching: .any)["tv.connections.back"]
        let headingExists = heading.exists
        let headingFrame = headingExists ? "\(heading.frame)" : "missing"
        var widest: CGFloat = 0
        var widestLabel = ""
        for el in app.buttons.allElementsBoundByIndex {
            let w = el.frame.width
            if w > widest && el.frame.minX >= 0 && el.frame.maxX <= 1920 {
                widest = w; widestLabel = el.label
            }
        }
        let storageLink = app.buttons["tv.connections.storage"]
        let storageExists = storageLink.exists
        var storageFrame = "missing"
        var subWidest: CGFloat = 0
        var subWidestLabel = ""
        if storageExists {
            storageFrame = "\(storageLink.frame)"
            let subOpened = focusAndSelect(storageLink, app: app)
            sleep(3)
            if subOpened {
                for el in app.buttons.allElementsBoundByIndex {
                    let w = el.frame.width
                    if w > subWidest && el.frame.minX >= 0 && el.frame.maxX <= 1920 {
                        subWidest = w; subWidestLabel = el.label
                    }
                }
            }
        }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "connections-compression-probe"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTFail("PROBE connections-compression: mineOpened=\(mineOpened) connID=\(connID) viewport=\(app.frame) opened=\(opened) headingExists=\(headingExists) headingFrame=\(headingFrame) widestButtonWidth=\(widest) widestLabel=\(widestLabel) storageExists=\(storageExists) storageFrame=\(storageFrame) subWidestButtonWidth=\(subWidest) subWidestLabel=\(subWidestLabel)")
    }

    /// Diagnostic probe (2026-11-21): user reports pressing Menu/back inside a
    /// Docker container detail (e.g. Jellyfin) does nothing and the app must be
    /// force-quit. Containers are listed directly on the Launchpad as
    /// tv.service.item.container:<hash> buttons, so the probe taps one there,
    /// presses Menu once, and reports whether the detail dismissed.
    func testDockerBackButtonProbe() {
        let app = XCUIApplication()
        app.launchArguments = []
        app.launchEnvironment = [:]
        app.launch()
        XCTAssertTrue(app.buttons["tv.tab.launchpad"].waitForExistence(timeout: 15), "Launchpad tab must appear")
        sleep(8)
        let container = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "tv.service.item.container:")).firstMatch
        let containerExists = container.waitForExistence(timeout: 10)
        var containerLabel = "none"
        if containerExists { containerLabel = container.label }
        var detailOpened = false
        if containerExists { detailOpened = focusAndSelect(container, app: app) }
        sleep(3)
        let detail = app.descendants(matching: .any)["tv.service.detail"]
        let onDetailBeforeMenu = detail.exists
        var onDetailAfterMenu = onDetailBeforeMenu
        var menuPressed = false
        if onDetailBeforeMenu {
            XCUIRemote.shared.press(.menu)
            menuPressed = true
            sleep(3)
            onDetailAfterMenu = detail.exists
        }
        let backOnLaunchpad = app.buttons["tv.tab.launchpad"].exists && app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "tv.service.item.container:")).firstMatch.exists
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "docker-back-probe"
        attachment.lifetime = .keepAlways
        add(attachment)
        print("PROBE docker-back: containerExists=\(containerExists) containerLabel=\(containerLabel) detailOpened=\(detailOpened) onDetailBeforeMenu=\(onDetailBeforeMenu) menuPressed=\(menuPressed) onDetailAfterMenu=\(onDetailAfterMenu) backOnLaunchpad=\(backOnLaunchpad)")
        XCTAssertTrue(detailOpened && onDetailBeforeMenu)
        XCTAssertFalse(onDetailAfterMenu)
        XCTAssertTrue(backOnLaunchpad)
        let identifiers = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "tv.service.item.container:")).allElementsBoundByIndex.map(\.identifier)
        XCTAssertGreaterThanOrEqual(identifiers.count, 3, "Need three visible containers for repeated-entry acceptance")
        for identifier in identifiers.filter({ $0 != container.identifier }).prefix(2) {
            XCTAssertTrue(focusAndSelect(app.buttons[identifier], app: app))
            XCTAssertTrue(detail.waitForExistence(timeout: 5))
            XCUIRemote.shared.press(.menu)
            sleep(2)
            XCTAssertFalse(detail.exists)
        }
    }

    /// Move focus to `element` with a bounded remote sweep, then press .select.
    /// Returns true only if the element had focus and select was pressed.
    private func focusAndSelect(_ element: XCUIElement, app: XCUIApplication) -> Bool {
        if element.hasFocus {
            XCUIRemote.shared.press(.select)
            sleep(6)
            return true
        }
        let moves: [XCUIRemote.Button] = [.down, .right, .down, .right, .down, .left, .down, .right, .up, .right, .down, .left, .down, .right]
        for move in moves {
            XCUIRemote.shared.press(move)
            Thread.sleep(forTimeInterval: 0.4)
            if element.hasFocus {
                XCUIRemote.shared.press(.select)
                sleep(6)
                return true
            }
        }
        return false
    }

    /// Diagnostic probe (2026-11-21): measure the actual content width of two
    /// reachable subpages (Storage & Media via tv.open.networkLibrary, and a
    /// Docker service detail via a Launchpad container row) against the
    /// 1920pt viewport. The user reports Connection Management subpages are
    /// compressed; these reachable pages share the same tvPageInsets /
    /// tvPageTheme layout, so a narrow width here points at the same cause.
    func testSubpageWidthProbe() {
        let app = XCUIApplication()
        app.launchArguments = []
        app.launchEnvironment = [:]
        app.launch()
        XCTAssertTrue(app.buttons["tv.tab.launchpad"].waitForExistence(timeout: 15), "Launchpad tab must appear")
        // Page 1: Storage & Media (TVStorageEntry).
        let storage = app.buttons["tv.open.networkLibrary"]
        XCTAssertTrue(storage.waitForExistence(timeout: 10), "Storage & Media tile must exist")
        let storageOpened = focusAndSelect(storage, app: app)
        sleep(3)
        var storageWidest: CGFloat = 0
        var storageWidestLabel = ""
        for el in app.buttons.allElementsBoundByIndex {
            let w = el.frame.width
            if w > storageWidest && el.frame.minX >= 0 && el.frame.maxX <= 1920 {
                storageWidest = w; storageWidestLabel = el.label
            }
        }
        let storageViewport = "\(app.frame)"
        // Go back to the Launchpad, then open a Docker service detail.
        XCUIRemote.shared.press(.menu)
        sleep(3)
        let container = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "tv.service.item.container:")).firstMatch
        let containerExists = container.waitForExistence(timeout: 10)
        var detailOpened = false
        if containerExists { detailOpened = focusAndSelect(container, app: app) }
        sleep(3)
        var detailWidest: CGFloat = 0
        var detailWidestLabel = ""
        for el in app.buttons.allElementsBoundByIndex {
            let w = el.frame.width
            if w > detailWidest && el.frame.minX >= 0 && el.frame.maxX <= 1920 {
                detailWidest = w; detailWidestLabel = el.label
            }
        }
        let detailOnPage = app.descendants(matching: .any)["tv.service.detail"].exists
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "subpage-width-probe"
        attachment.lifetime = .keepAlways
        add(attachment)
        print("PROBE subpage-width: storageOpened=\(storageOpened) storageViewport=\(storageViewport) storageWidestButtonWidth=\(storageWidest) storageWidestLabel=\(storageWidestLabel) containerExists=\(containerExists) detailOpened=\(detailOpened) detailOnPage=\(detailOnPage) detailWidestButtonWidth=\(detailWidest) detailWidestLabel=\(detailWidestLabel)")
        XCTAssertTrue(storageOpened && detailOpened && detailOnPage)
        XCTAssertGreaterThanOrEqual(storageWidest, 1400)
        verifyServiceInfoCardFrame(in: app)
    }

    /// Supplementary acceptance probe (2026-11-21, Muse): verifies the two items
    /// the Codex probes could not settle on their own — Docker Menu return for
    /// three consecutive containers, and the service-detail info-card width.
    /// Uses firstMatch (not cached identifiers) so a re-rendered list cannot
    /// break the lookup.
    func testFixVerificationDockerAndWidth() {
        let app = XCUIApplication()
        app.launchArguments = []
        app.launchEnvironment = [:]
        app.launch()
        XCTAssertTrue(app.buttons["tv.tab.launchpad"].waitForExistence(timeout: 15), "Launchpad tab must appear")
        sleep(8)
        // --- Docker: three consecutive containers, Menu must return each time. ---
        var dockerResults: [String] = []
        var seenLabels: [String] = []
        for i in 1...3 {
            let container = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "tv.service.item.container:")).allElementsBoundByIndex.first(where: { !seenLabels.contains($0.label) })
            guard let row = container else {
                dockerResults.append("container\(i)=not-found")
                break
            }
            seenLabels.append(row.label)
            let opened = focusAndSelect(row, app: app)
            sleep(3)
            let detail = app.descendants(matching: .any)["tv.service.detail"].firstMatch
            let onDetail = detail.exists
            var returned = false
            if onDetail {
                XCUIRemote.shared.press(.menu)
                sleep(3)
                returned = !detail.exists
            }
            dockerResults.append("container\(i)=\(row.label) opened=\(opened) onDetail=\(onDetail) menuReturned=\(returned)")
            // Back on the Launchpad for the next container.
            if !app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "tv.service.item.container:")).firstMatch.exists {
                XCUIRemote.shared.press(.menu)
                sleep(2)
            }
        }
        // --- Width: info-card width on a service detail (first container). ---
        var infoWidth: CGFloat = -1
        var infoExists = false
        let first = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "tv.service.item.container:")).firstMatch
        if first.waitForExistence(timeout: 10) {
            let opened = focusAndSelect(first, app: app)
            sleep(3)
            let info = app.descendants(matching: .any)["tv.service.info"].firstMatch
            infoExists = info.exists
            if infoExists { infoWidth = info.frame.width }
            _ = opened
        }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "fix-verification-docker-width"
        attachment.lifetime = .keepAlways
        add(attachment)
        print("PROBE fix-verification: docker=[\(dockerResults.joined(separator: " | "))] infoExists=\(infoExists) infoWidth=\(infoWidth)")
        XCTAssertTrue(dockerResults.count == 3, "Need three containers: \(dockerResults)")
        XCTAssertTrue(dockerResults.allSatisfy { $0.contains("menuReturned=true") }, "Every container Menu must return: \(dockerResults)")
        XCTAssertTrue(infoExists, "Service info card must exist")
        XCTAssertGreaterThanOrEqual(infoWidth, 1400, "Service info card width must be >= 1400pt, got \(infoWidth)")
    }

    /// Supplementary acceptance probe round 2 (2026-11-21, Muse): Docker Menu
    /// return for three containers + service-detail info-card width, using a
    /// "press Down until focused" strategy instead of the fixed sweep, which
    /// could not reach the 2nd/3rd container rows after a Menu return.
    func testFixVerificationDockerAndWidth2() {
        let app = XCUIApplication()
        app.launchArguments = []
        app.launchEnvironment = [:]
        app.launch()
        XCTAssertTrue(app.buttons["tv.tab.launchpad"].waitForExistence(timeout: 15), "Launchpad tab must appear")
        sleep(8)
        // Helper: focus a container row by pressing Down until it has focus.
        func openContainer(label: String) -> (opened: Bool, onDetail: Bool, menuReturned: Bool) {
            let row = app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
            guard row.waitForExistence(timeout: 10) else { return (false, false, false) }
            var focused = row.hasFocus
            for _ in 0..<25 where !focused {
                XCUIRemote.shared.press(.down)
                Thread.sleep(forTimeInterval: 0.35)
                focused = row.hasFocus
            }
            if !focused {
                // Try moving right/left within the row's group, then down again.
                for _ in 0..<10 where !focused {
                    XCUIRemote.shared.press(.right)
                    Thread.sleep(forTimeInterval: 0.35)
                    if row.hasFocus { focused = true; break }
                    XCUIRemote.shared.press(.down)
                    Thread.sleep(forTimeInterval: 0.35)
                    focused = row.hasFocus
                }
            }
            guard focused else { return (false, false, false) }
            XCUIRemote.shared.press(.select)
            sleep(6)
            let detail = app.descendants(matching: .any)["tv.service.detail"].firstMatch
            let onDetail = detail.exists
            var returned = false
            if onDetail {
                XCUIRemote.shared.press(.menu)
                sleep(3)
                returned = !detail.exists
            }
            return (true, onDetail, returned)
        }
        // Discover the container labels present on this Launchpad.
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "tv.service.item.container:")).allElementsBoundByIndex
        let labels = rows.map(\.label)
        var dockerResults: [String] = []
        for label in labels.prefix(3) {
            let r = openContainer(label: label)
            dockerResults.append("\(label) opened=\(r.opened) onDetail=\(r.onDetail) menuReturned=\(r.menuReturned)")
            // Ensure we are back on the Launchpad before the next container.
            if !app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "tv.service.item.container:")).firstMatch.exists {
                XCUIRemote.shared.press(.menu)
                sleep(2)
            }
        }
        // Width: open the first container again and measure the info card.
        var infoWidth: CGFloat = -1
        var infoExists = false
        if let firstLabel = labels.first {
            let r = openContainer(label: firstLabel)
            if r.onDetail {
                let info = app.descendants(matching: .any)["tv.service.info"].firstMatch
                infoExists = info.exists
                if infoExists { infoWidth = info.frame.width }
            }
        }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "fix-verification2-docker-width"
        attachment.lifetime = .keepAlways
        add(attachment)
        print("PROBE fix-verification2: labels=\(labels) docker=[\(dockerResults.joined(separator: " | "))] infoExists=\(infoExists) infoWidth=\(infoWidth)")
        XCTAssertTrue(dockerResults.count == 3, "Need three containers, got \(dockerResults)")
        XCTAssertTrue(dockerResults.allSatisfy { $0.contains("menuReturned=true") }, "Every container Menu must return: \(dockerResults)")
        XCTAssertTrue(infoExists, "Service info card must exist")
        XCTAssertGreaterThanOrEqual(infoWidth, 1400, "Service info card width must be >= 1400pt, got \(infoWidth)")
    }

    /// Width-only probe (2026-11-21, Muse): opens the first Launchpad container
    /// with focusAndSelect (proven to work) and measures the service-detail
    /// info-card width. No Docker loop beforehand, so focus starts fresh.
    func testFixVerificationWidthOnly() {
        let app = XCUIApplication()
        app.launchArguments = []
        app.launchEnvironment = [:]
        app.launch()
        XCTAssertTrue(app.buttons["tv.tab.launchpad"].waitForExistence(timeout: 15), "Launchpad tab must appear")
        sleep(8)
        let container = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "tv.service.item.container:")).firstMatch
        let containerExists = container.waitForExistence(timeout: 10)
        var containerLabel = "none"
        if containerExists { containerLabel = container.label }
        var detailOpened = false
        if containerExists { detailOpened = focusAndSelect(container, app: app) }
        sleep(3)
        let detail = app.descendants(matching: .any)["tv.service.detail"].firstMatch
        let onDetail = detail.exists
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "fix-verification-width-only"
        attachment.lifetime = .keepAlways
        add(attachment)
        print("PROBE fix-verification-width-only: containerExists=\(containerExists) containerLabel=\(containerLabel) detailOpened=\(detailOpened) onDetail=\(onDetail)")
        XCTAssertTrue(detailOpened && onDetail, "Detail must open")
        guard detailOpened && onDetail else { return }
        verifyServiceInfoCardFrame(in: app)
    }

    private func verifyServiceInfoCardFrame(in app: XCUIApplication) {
        let detail = app.scrollViews.matching(identifier: "tv.service.detail").firstMatch
        XCTAssertTrue(detail.exists, "The service detail scroll view must exist")
        guard detail.exists else { return }
        let cards = detail.descendants(matching: .any).matching(identifier: "tv.service.info")
        XCTAssertEqual(cards.count, 1, "The ID must identify one info card, not its individual labels")
        guard cards.count == 1 else { return }

        let card = cards.element(boundBy: 0)
        let cardFrame = card.frame
        let viewport = detail.frame
        print("PROBE service-detail-card: type=\(card.elementType) frame=\(cardFrame) viewport=\(viewport)")
        XCTAssertGreaterThanOrEqual(cardFrame.width, 1400, "Service info card width")
        XCTAssertGreaterThanOrEqual(cardFrame.minX, viewport.minX - 1)
        XCTAssertLessThanOrEqual(cardFrame.maxX, viewport.maxX + 1)
    }

    /// Width probe per theme (2026-11-21, Muse): the app reads its theme from
    /// @AppStorage("appearance.launchpadTheme"); a launch argument of the same
    /// name overrides the stored value for this launch. Three entry points so
    /// xcodebuild -only-testing can run each theme in a fresh app launch.
    func testFixVerificationWidthCleanGrid() {
        verifyServiceDetailWidth(theme: "cleanGrid", themeName: "清流")
    }

    func testFixVerificationWidthCommandCenter() {
        verifyServiceDetailWidth(theme: "commandCenter", themeName: "栈列")
    }

    func testFixVerificationWidthGlassDeck() {
        verifyServiceDetailWidth(theme: "glassDeck", themeName: "流光")
    }

    private func verifyServiceDetailWidth(theme: String, themeName: String) {
        let app = XCUIApplication()
        app.launchArguments = ["-appearance.launchpadTheme", theme]
        app.launchEnvironment = [:]
        app.launch()
        XCTAssertTrue(app.buttons["tv.tab.launchpad"].waitForExistence(timeout: 15), "Launchpad tab must appear")
        sleep(8)
        let container = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "tv.service.item.container:")).firstMatch
        let containerExists = container.waitForExistence(timeout: 10)
        var containerLabel = "none"
        if containerExists { containerLabel = container.label }
        var detailOpened = false
        if containerExists { detailOpened = focusAndSelect(container, app: app) }
        sleep(3)
        let detail = app.descendants(matching: .any)["tv.service.detail"].firstMatch
        let onDetail = detail.exists
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "fix-verification-width-\(theme)"
        attachment.lifetime = .keepAlways
        add(attachment)
        print("PROBE fix-verification-width: theme=\(themeName)(\(theme)) containerExists=\(containerExists) containerLabel=\(containerLabel) detailOpened=\(detailOpened) onDetail=\(onDetail)")
        XCTAssertTrue(detailOpened && onDetail, "Detail must open (theme \(themeName))")
        guard detailOpened && onDetail else { return }
        verifyServiceInfoCardFrame(in: app)
    }

    /// Sheet width probe (2026-11-21, Muse): the user photographed the Manage
    /// Display and Connection Management sheets as narrow centred cards. The
    /// service-detail page fix does not cover sheets. Measure the Manage
    /// Display sheet (reachable from the Launchpad) and report its frame.
    func testSheetWidthManageDisplay() {
        let app = XCUIApplication()
        app.launchArguments = []
        app.launchEnvironment = [:]
        app.launch()
        XCTAssertTrue(app.buttons["tv.tab.launchpad"].waitForExistence(timeout: 15), "Launchpad tab must appear")
        sleep(8)
        let manageButton = app.buttons["tv.services.manageVisibility"]
        let buttonExists = manageButton.waitForExistence(timeout: 10)
        var opened = false
        if buttonExists { opened = focusAndSelect(manageButton, app: app) }
        sleep(3)
        // The sheet contains the "管理显示" heading. Measure the widest
        // element that belongs to the sheet (the sheet's own frame).
        let heading = app.staticTexts["管理显示"]
        let headingExists = heading.waitForExistence(timeout: 5)
        var sheetFrame = "missing"
        var sheetWidth: CGFloat = -1
        if headingExists {
            // Walk up to the sheet container: the heading's ancestors include
            // the sheet. Take the widest ancestor that is still within the
            // viewport and narrower than full screen (i.e. the sheet card).
            var widest: CGFloat = 0
            var widestFrame = "none"
            for el in app.descendants(matching: .any).allElementsBoundByIndex {
                let w = el.frame.width
                if w > widest && w < 1920 && el.frame.minX >= 0 && el.frame.maxX <= 1920 {
                    widest = w; widestFrame = "\(el.frame) id=\(el.identifier) type=\(el.elementType.rawValue)"
                }
            }
            sheetWidth = widest
            sheetFrame = widestFrame
        }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "sheet-width-manage-display"
        attachment.lifetime = .keepAlways
        add(attachment)
        print("PROBE sheet-width: view=管理显示 buttonExists=\(buttonExists) opened=\(opened) headingExists=\(headingExists) sheetWidth=\(sheetWidth) sheetFrame=\(sheetFrame)")
        XCTAssertTrue(buttonExists && opened && headingExists, "Manage Display sheet must open")
        XCTAssertGreaterThanOrEqual(sheetWidth, 1400, "Manage Display sheet width must be >= 1400pt, got \(sheetWidth)")
    }

    /// Management pages acceptance (2026-11-21, Muse): both pages were
    /// converted from narrow .sheet modals to full-page navigation
    /// destinations. Measure the VISIBLE group card frame (not the widest
    /// element in the hierarchy — that mistake voided the last sheet probe).
    /// A card is the smallest ancestor-like container that encloses its
    /// section title and stays inside the 1920pt viewport.

    /// Find the visible group card enclosing `anchor` (an element inside
    /// the card, e.g. a toggle or a row): among descendants that contain
    /// the anchor's centre and are >= 1400pt wide, take the one with the
    /// SMALLEST height. The page ScrollView (1840pt wide, whole-page tall)
    /// also contains the anchor, so "widest" is the wrong rule — it picks
    /// the ScrollView. The card is a single section, much shorter.
    private func visibleCardFrame(anchor: XCUIElement, in page: XCUIElement) -> CGRect {
        guard anchor.exists else { return .zero }
        let centre = CGPoint(x: anchor.frame.midX, y: anchor.frame.midY)
        var best = CGRect.zero
        var bestHeight = CGFloat.greatestFiniteMagnitude
        for el in page.descendants(matching: .any).allElementsBoundByIndex {
            let f = el.frame
            guard f.width >= 1400 && f.width < 1920 && f.height >= 40 else { continue }
            guard f.minX >= 0 && f.maxX <= 1920 else { continue }
            guard f.contains(centre) else { continue }
            if f.height < bestHeight {
                bestHeight = f.height
                best = f
            }
        }
        return best
    }

    func testMgmtManageDisplayAcceptance() {
        let app = XCUIApplication()
        app.launchArguments = []
        app.launchEnvironment = [:]
        app.launch()
        XCTAssertTrue(app.buttons["tv.tab.launchpad"].waitForExistence(timeout: 15), "Launchpad tab must appear")
        sleep(8)
        let manageButton = app.buttons["tv.services.manageVisibility"]
        let buttonExists = manageButton.waitForExistence(timeout: 10)
        var opened = false
        if buttonExists { opened = focusAndSelect(manageButton, app: app) }
        sleep(3)
        let page = app.descendants(matching: .any)["tv.services.visibility.page"].firstMatch
        let onPage = page.exists
        var cardFrame = CGRect.zero
        var cardTitle = "none"
        var serviceNames: [String] = []
        if onPage {
            // Service names in the two-column grid: each toggle button label.
            let toggles = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "tv.visibility.")).allElementsBoundByIndex
            serviceNames = toggles.map(\.label)
            // Measure the 收藏 group card, anchored on its first toggle.
            // (The section title sits above the card, so it cannot anchor it.)
            if let first = toggles.first {
                cardFrame = visibleCardFrame(anchor: first, in: page)
                cardTitle = "收藏"
            }
        }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "mgmt-manage-display"
        attachment.lifetime = .keepAlways
        add(attachment)
        print("PROBE mgmt-manage-display: buttonExists=\(buttonExists) opened=\(opened) onPage=\(onPage) cardTitle=\(cardTitle) cardFrame=\(cardFrame) serviceNames=\(serviceNames)")
        XCTAssertTrue(buttonExists && opened && onPage, "Manage Display must open as a full page")
        XCTAssertGreaterThanOrEqual(cardFrame.width, 1400, "Manage Display group card width must be >= 1400pt, got \(cardFrame.width)")
        XCTAssertGreaterThanOrEqual(cardFrame.minX, 0)
        XCTAssertLessThanOrEqual(cardFrame.maxX, 1920)
        // Back/Menu once must return to the Launchpad.
        XCUIRemote.shared.press(.menu)
        sleep(3)
        let backOnLaunchpad = app.buttons["tv.tab.launchpad"].exists && app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "tv.service.item.container:")).firstMatch.exists
        print("PROBE mgmt-manage-display-back: backOnLaunchpad=\(backOnLaunchpad)")
        XCTAssertTrue(backOnLaunchpad, "One Menu press must return to the Launchpad")
    }

    func testMgmtConnectionsAcceptance() {
        let app = XCUIApplication()
        app.launchArguments = []
        app.launchEnvironment = [:]
        app.launch()
        XCTAssertTrue(app.buttons["tv.tab.launchpad"].waitForExistence(timeout: 15), "Launchpad tab must appear")
        sleep(8)
        // Launchpad -> Storage & Media.
        let storage = app.buttons["tv.open.networkLibrary"]
        XCTAssertTrue(storage.waitForExistence(timeout: 10), "Storage & Media tile must exist")
        let storageOpened = focusAndSelect(storage, app: app)
        sleep(3)
        // Storage & Media -> Connection Management (header action, top
        // right). The focus sweep cannot reach a header button from the
        // content rows, so press Up repeatedly until it has focus.
        let manageButton = app.buttons["network.connections.manage"]
        let buttonExists = manageButton.waitForExistence(timeout: 10)
        var opened = false
        if buttonExists {
            for _ in 0..<8 {
                if manageButton.hasFocus { break }
                XCUIRemote.shared.press(.up)
                sleep(1)
            }
            if manageButton.hasFocus {
                XCUIRemote.shared.press(.select)
                opened = true
            } else {
                opened = focusAndSelect(manageButton, app: app)
            }
        }
        sleep(3)
        let page = app.descendants(matching: .any)["network.connections.page"].firstMatch
        let onPage = page.exists
        var cardFrame = CGRect.zero
        var dsmLabel = ""
        var webdavLabel = ""
        if onPage {
            // Synology DSM and WebDAV rows must display completely.
            let dsm = page.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Synology DSM")).firstMatch
            if dsm.exists { dsmLabel = dsm.label }
            let webdav = page.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "WebDAV")).firstMatch
            if webdav.exists { webdavLabel = webdav.label }
            // Measure the 存储连接 group card, anchored on the DSM row.
            if dsm.exists { cardFrame = visibleCardFrame(anchor: dsm, in: page) }
        }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "mgmt-connections"
        attachment.lifetime = .keepAlways
        add(attachment)
        print("PROBE mgmt-connections: storageOpened=\(storageOpened) buttonExists=\(buttonExists) opened=\(opened) onPage=\(onPage) cardFrame=\(cardFrame) dsmLabel=\(dsmLabel) webdavLabel=\(webdavLabel)")
        XCTAssertTrue(storageOpened && buttonExists && opened && onPage, "Connection Management must open as a full page")
        XCTAssertGreaterThanOrEqual(cardFrame.width, 1400, "Storage Connections group card width must be >= 1400pt, got \(cardFrame.width)")
        XCTAssertGreaterThanOrEqual(cardFrame.minX, 0)
        XCTAssertLessThanOrEqual(cardFrame.maxX, 1920)
        XCTAssertTrue(dsmLabel.contains("Synology DSM"), "Synology DSM row must display, got '\(dsmLabel)'")
        XCTAssertTrue(webdavLabel.contains("WebDAV"), "WebDAV row must display, got '\(webdavLabel)'")
        // Back/Menu once must return to Storage & Media.
        XCUIRemote.shared.press(.menu)
        sleep(3)
        let backOnStorage = app.staticTexts["存储与媒体"].exists || app.buttons["tv.open.networkLibrary"].exists
        print("PROBE mgmt-connections-back: backOnStorage=\(backOnStorage)")
        XCTAssertTrue(backOnStorage, "One Menu press must return to Storage & Media")
    }

    /// Debug probe (2026-11-21, Muse): dump the Manage Display page element
    /// tree so the card measurement can be fixed with real frames instead of
    /// guessing. Prints every element wider than 400pt on the page.
    func testMgmtDebugManageDisplayTree() {
        let app = XCUIApplication()
        app.launchArguments = []
        app.launchEnvironment = [:]
        app.launch()
        XCTAssertTrue(app.buttons["tv.tab.launchpad"].waitForExistence(timeout: 15), "Launchpad tab must appear")
        sleep(8)
        let manageButton = app.buttons["tv.services.manageVisibility"]
        guard manageButton.waitForExistence(timeout: 10) else { print("PROBE mgmt-debug: manage button missing"); return }
        guard focusAndSelect(manageButton, app: app) else { print("PROBE mgmt-debug: could not open Manage Display"); return }
        sleep(3)
        let page = app.descendants(matching: .any)["tv.services.visibility.page"].firstMatch
        guard page.exists else { print("PROBE mgmt-debug: visibility page missing"); return }
        print("PROBE mgmt-debug: page frame=\(page.frame)")
        // Dump every element wider than 400pt, with its identifier/type/frame.
        for el in page.descendants(matching: .any).allElementsBoundByIndex {
            let f = el.frame
            if f.width >= 400 && f.minX >= 0 && f.maxX <= 1920 {
                print("PROBE mgmt-debug-el: w=\(Int(f.width)) h=\(Int(f.height)) x=\(Int(f.minX)) y=\(Int(f.minY)) id='\(el.identifier)' label='\(el.label)' type=\(el.elementType.rawValue)")
            }
        }
        // Specifically: the 收藏 label and the first toggle button.
        let fav = page.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "收藏")).firstMatch
        print("PROBE mgmt-debug: 收藏 exists=\(fav.exists) frame=\(fav.frame)")
        let toggle = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "tv.visibility.")).firstMatch
        print("PROBE mgmt-debug: first toggle exists=\(toggle.exists) id='\(toggle.identifier)' label='\(toggle.label)' frame=\(toggle.frame)")
    }

    /// Focus a root tab: press Up to reach the tab bar, then step Right/Left
    /// until the target tab has focus, then Select.
    private func focusTab(_ identifier: String, app: XCUIApplication) -> Bool {
        let target = app.buttons[identifier]
        // Already there: if the tab is selected and focused, select it.
        if target.hasFocus {
            XCUIRemote.shared.press(.select)
            sleep(3)
            return true
        }
        // Move up to the tab bar (up to 5 ups), then walk sideways.
        for _ in 0..<5 {
            if target.hasFocus { break }
            XCUIRemote.shared.press(.up)
            Thread.sleep(forTimeInterval: 0.5)
            if target.hasFocus { break }
        }
        if target.hasFocus {
            XCUIRemote.shared.press(.select)
            sleep(3)
            return true
        }
        // Walk right across the tab bar (4 tabs max), then left if needed.
        for _ in 0..<4 {
            XCUIRemote.shared.press(.right)
            Thread.sleep(forTimeInterval: 0.5)
            if target.hasFocus {
                XCUIRemote.shared.press(.select)
                sleep(3)
                return true
            }
        }
        for _ in 0..<4 {
            XCUIRemote.shared.press(.left)
            Thread.sleep(forTimeInterval: 0.5)
            if target.hasFocus {
                XCUIRemote.shared.press(.select)
                sleep(3)
                return true
            }
        }
        return target.hasFocus
    }

    /// Focus a header button on a long page: first press Up to the top of the
    /// page (the button sits above the service cards, so a pure Down walk from
    /// a card never reaches it), then walk Down step by step until the
    /// element has focus, then Select.
    private func focusByDown(_ element: XCUIElement, app: XCUIApplication, maxMoves: Int = 60) -> Bool {
        if element.hasFocus {
            XCUIRemote.shared.press(.select)
            sleep(3)
            return true
        }
        for _ in 0..<10 {
            if element.hasFocus { break }
            XCUIRemote.shared.press(.up)
            Thread.sleep(forTimeInterval: 0.4)
        }
        if element.hasFocus {
            XCUIRemote.shared.press(.select)
            sleep(3)
            return true
        }
        for _ in 0..<maxMoves {
            XCUIRemote.shared.press(.down)
            Thread.sleep(forTimeInterval: 0.4)
            if element.hasFocus {
                XCUIRemote.shared.press(.select)
                sleep(3)
                return true
            }
        }
        return false
    }

    /// Focus the iCloud tile on the Mine tab. From the tab bar, Down walks
    /// the rightmost column (player -> help -> storage), so iCloud (row 2,
    /// col 1) is reached by Down, Down, Left, Left.
    private func focusICloudTile(app: XCUIApplication) -> Bool {
        let icloud = app.buttons["tv.settings.icloud"]
        if icloud.hasFocus {
            XCUIRemote.shared.press(.select)
            sleep(3)
            return true
        }
        for move in [XCUIRemote.Button.down, .down, .left, .left] {
            XCUIRemote.shared.press(move)
            Thread.sleep(forTimeInterval: 0.5)
            if icloud.hasFocus {
                XCUIRemote.shared.press(.select)
                sleep(3)
                return true
            }
        }
        return false
    }

    /// Piece 3 acceptance probe (2026-11-22): TV services sync.
    /// Verifies DSM login + service list, Manage Display toggles, cold-start
    /// persistence, and the iCloud page service-sync scope copy.
    /// The toggled service is restored to its original value at the end.
    /// Navigation follows testMgmtManageDisplayAcceptance: no tab switching;
    /// the Devices stack is retained, so the manageVisibility button is
    /// focused directly after an 8s settle.
    func testPiece03TVServicesAcceptance() {
        let app = XCUIApplication()
        app.launchArguments = []
        app.launchEnvironment = [:]
        app.launch()
        XCTAssertTrue(app.buttons["tv.tab.launchpad"].waitForExistence(timeout: 15), "Launchpad tab must appear")
        sleep(8)
        print("PROBE piece03: launched, launchpad tab present")

        // 1) DSM login + service list: the Manage Display entry exists only
        // when DSM discovery returned services.
        XCTAssertTrue(app.buttons["tv.services.manageVisibility"].waitForExistence(timeout: 20), "Manage Display entry must appear (DSM login + discovery)")
        let noServices = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "当前账号没有可见服务")).firstMatch
        XCTAssertFalse(noServices.exists, "DSM shows no visible services")
        print("PROBE piece03: manage-display entry present, DSM services discovered")

        // 2) Open Manage Display, pick the first enabled toggle, record its value.
        XCTAssertTrue(focusAndSelect(app.buttons["tv.services.manageVisibility"], app: app), "Cannot open Manage Display")
        sleep(3)
        XCTAssertTrue(app.descendants(matching: .any)["tv.services.visibility.page"].waitForExistence(timeout: 15), "Manage Display page must appear")
        let toggleQuery = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "tv.visibility."))
        XCTAssertTrue(toggleQuery.firstMatch.waitForExistence(timeout: 15), "Manage Display must have service toggles")
        var target: XCUIElement?
        var targetId = ""
        var initialValue = ""
        for i in 0..<toggleQuery.count {
            let el = toggleQuery.element(boundBy: i)
            if el.exists && el.isEnabled {
                target = el
                targetId = el.identifier
                initialValue = (el.value as? String) ?? ""
                break
            }
        }
        guard let toggle = target, !targetId.isEmpty, initialValue == "显示" || initialValue == "隐藏" else {
            XCTFail("No enabled service toggle found (id='\(targetId)' value='\(initialValue)')")
            return
        }
        let targetLabel = toggle.label
        let flippedValue = initialValue == "显示" ? "隐藏" : "显示"
        print("PROBE piece03: toggle target id='\(targetId)' label='\(targetLabel)' initial='\(initialValue)'")

        // 3) Toggle it and verify the value flips.
        XCTAssertTrue(focusAndSelect(toggle, app: app), "Cannot focus/select the toggle")
        sleep(2)
        let afterToggle = app.buttons[targetId]
        XCTAssertTrue(afterToggle.waitForExistence(timeout: 10), "Toggle must still exist after tap")
        let afterValue = (afterToggle.value as? String) ?? ""
        XCTAssertEqual(afterValue, flippedValue, "Toggle value must flip from \(initialValue) to \(flippedValue), got \(afterValue)")
        print("PROBE piece03: toggled to '\(afterValue)'")
        let shot1 = XCTAttachment(screenshot: app.screenshot())
        shot1.name = "piece03-after-toggle"
        shot1.lifetime = .keepAlways
        add(shot1)

        // 4) Cold start: terminate + relaunch, verify the toggle persisted.
        app.terminate()
        sleep(2)
        app.launch()
        XCTAssertTrue(app.buttons["tv.tab.launchpad"].waitForExistence(timeout: 15), "Launchpad tab must appear after cold start")
        sleep(8)
        XCTAssertTrue(app.buttons["tv.services.manageVisibility"].waitForExistence(timeout: 20), "Manage Display entry must appear after cold start")
        XCTAssertTrue(focusAndSelect(app.buttons["tv.services.manageVisibility"], app: app), "Cannot open Manage Display after cold start")
        sleep(3)
        XCTAssertTrue(app.descendants(matching: .any)["tv.services.visibility.page"].waitForExistence(timeout: 15), "Manage Display page must appear after cold start")
        let persisted = app.buttons[targetId]
        XCTAssertTrue(persisted.waitForExistence(timeout: 10), "Toggled service must still exist after cold start")
        let persistedValue = (persisted.value as? String) ?? ""
        XCTAssertEqual(persistedValue, flippedValue, "Toggle must persist after cold start (expected \(flippedValue), got \(persistedValue))")
        print("PROBE piece03: cold start persisted value='\(persistedValue)' for '\(targetLabel)'")

        // 5) Restore the toggle to its original value.
        XCTAssertTrue(focusAndSelect(persisted, app: app), "Cannot focus/select the toggle to restore")
        sleep(2)
        let restored = app.buttons[targetId]
        let restoredValue = (restored.value as? String) ?? ""
        XCTAssertEqual(restoredValue, initialValue, "Toggle must restore to \(initialValue), got \(restoredValue)")
        print("PROBE piece03: restored to '\(restoredValue)'")
        let shot2 = XCTAttachment(screenshot: app.screenshot())
        shot2.name = "piece03-after-restore"
        shot2.lifetime = .keepAlways
        add(shot2)

        // 6) iCloud page: Mine tab -> iCloud, verify service-sync scope copy.
        XCUIRemote.shared.press(.menu)
        sleep(2)
        XCTAssertTrue(focusTab("tv.tab.mine", app: app), "Cannot open Mine tab")
        XCTAssertTrue(app.buttons["tv.settings.icloud"].waitForExistence(timeout: 15), "iCloud settings entry must appear")
        XCTAssertTrue(focusICloudTile(app: app), "Cannot open iCloud page")
        XCTAssertTrue(app.staticTexts["服务显示同步"].waitForExistence(timeout: 15), "iCloud page must show 服务显示同步")
        let scopeText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "配置 iCloud 后可同步启动台的服务显示开关")).firstMatch
        XCTAssertTrue(scopeText.waitForExistence(timeout: 10), "iCloud page must show the service-sync scope copy")
        let unavailable = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "未开通")).firstMatch
        XCTAssertFalse(unavailable.exists, "iCloud page must not show the old 未开通 notice")
        let syncSection = app.descendants(matching: .any)["settings.sync.services"]
        XCTAssertTrue(syncSection.exists, "iCloud page must have the settings.sync.services section")
        print("PROBE piece03: icloud page shows 服务显示同步 scope copy, no 未开通 notice")
        let shot3 = XCTAttachment(screenshot: app.screenshot())
        shot3.name = "piece03-icloud-page"
        shot3.lifetime = .keepAlways
        add(shot3)
        print("PROBE piece03: PASS target='\(targetLabel)' initial='\(initialValue)' flipped='\(flippedValue)' persisted='\(persistedValue)' restored='\(restoredValue)'")
    }

    /// Diagnostic (2026-11-22): dump focused element after each Down press
    /// on the Mine tab, to find how to reach the iCloud tile.
    func testPiece03MineFocusDiag() {
        let app = XCUIApplication()
        app.launchArguments = []
        app.launchEnvironment = [:]
        app.launch()
        XCTAssertTrue(app.buttons["tv.tab.launchpad"].waitForExistence(timeout: 15), "Launchpad tab must appear")
        sleep(5)
        XCTAssertTrue(focusTab("tv.tab.mine", app: app), "Cannot open Mine tab")
        sleep(2)
        let icloud = app.buttons["tv.settings.icloud"]
        print("DIAG mine: icloud exists=\(icloud.exists) enabled=\(icloud.isEnabled)")
        for step in 0..<12 {
            let focused = app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true")).firstMatch
            print("DIAG mine: step=\(step) focused id='\(focused.identifier)' label='\(focused.label)' type=\(focused.elementType.rawValue) icloudHasFocus=\(icloud.hasFocus)")
            if icloud.hasFocus { break }
            XCUIRemote.shared.press(.down)
            Thread.sleep(forTimeInterval: 0.6)
        }
        print("DIAG mine: final icloudHasFocus=\(icloud.hasFocus)")
        if icloud.hasFocus {
            XCUIRemote.shared.press(.select)
            sleep(3)
            let syncLabel = app.staticTexts["服务显示同步"]
            print("DIAG mine: after select, sync label exists=\(syncLabel.exists)")
        }
    }
}
