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
}
