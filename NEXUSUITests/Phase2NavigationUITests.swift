import XCTest

final class Phase2NavigationUITests: XCTestCase {
    func testPhaseTenBootPrecedesDailyPlanAndCanBeSkipped() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.otherElements["boot.screen"].waitForExistence(timeout: 3))
        app.buttons["DAILY PLAN'E GEÇ"].click()
        XCTAssertTrue(app.otherElements["home.screen"].waitForExistence(timeout: 5))
    }

    func testDailyPlanIsDefaultHomeAndControlSystemOpens() {
        let app = XCUIApplication()
        app.launchArguments.append("--skip-boot")
        app.launch()
        XCTAssertTrue(app.otherElements["home.screen"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["dailyplan.week"].waitForExistence(timeout: 3))
        app.typeKey("k", modifierFlags: .command)
        XCTAssertTrue(app.otherElements["controlSystem.screen"].waitForExistence(timeout: 3))
        app.typeKey("5", modifierFlags: [])
        XCTAssertTrue(app.otherElements["notes.screen"].waitForExistence(timeout: 3))
    }

    func testPhaseTwelveTodayExposesTimelineAndLiveControls() {
        let app = XCUIApplication()
        app.launchArguments.append("--skip-boot")
        app.launch()
        XCTAssertTrue(app.otherElements["dailyplan.week"].waitForExistence(timeout: 5))
        let today = app.buttons["BUGÜN"]
        XCTAssertTrue(today.waitForExistence(timeout: 3))
        today.click()
        XCTAssertTrue(app.otherElements["dailyplan.today"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.otherElements["dailyPlan.taskProgress"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.otherElements["dailyPlan.tasks.panel"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.scrollViews["dailyPlan.timeline.grid"].waitForExistence(timeout: 3) || app.otherElements["dailyPlan.timeline.grid"].exists)
        XCTAssertTrue(app.buttons.matching(identifier: "dailyPlan.new").firstMatch.isEnabled)
        XCTAssertTrue(app.buttons.matching(identifier: "dailyPlan.nexusMenu").firstMatch.isEnabled)
    }

    func testPhaseTenControlSearchKeepsCommandFMeaningSeparate() {
        let app = XCUIApplication()
        app.launchArguments.append("--skip-boot")
        app.launch()
        app.typeKey("f", modifierFlags: [.command, .shift])
        XCTAssertTrue(app.textFields["controlSystem.search"].waitForExistence(timeout: 3))
        app.typeKey(XCUIKeyboardKey.escape.rawValue, modifierFlags: [])
        XCTAssertTrue(app.otherElements["home.screen"].waitForExistence(timeout: 3))
    }

    func testHotfixDailyPlanNewControlOpensARealCreationFlow() {
        let app = XCUIApplication()
        app.launchArguments.append("--skip-boot")
        app.launch()
        let newButton = app.buttons.matching(identifier: "dailyPlan.new").firstMatch
        XCTAssertTrue(newButton.waitForExistence(timeout: 3))
        XCTAssertTrue(newButton.isEnabled)
        newButton.click()
        let courseFlow = app.otherElements["courseEditor.screen"]
        let scheduleFlow = app.otherElements["dailyPlan.scheduleEditor"]
        XCTAssertTrue(courseFlow.waitForExistence(timeout: 2) || scheduleFlow.waitForExistence(timeout: 2))
    }

    func testHotfixCommandNUsesTheSameContextualCreationFlow() {
        let app = XCUIApplication()
        app.launchArguments.append("--skip-boot")
        app.launch()
        XCTAssertTrue(app.otherElements["home.screen"].waitForExistence(timeout: 5))
        app.typeKey("n", modifierFlags: .command)
        let courseFlow = app.otherElements["courseEditor.screen"]
        let scheduleFlow = app.otherElements["dailyPlan.scheduleEditor"]
        XCTAssertTrue(courseFlow.waitForExistence(timeout: 2) || scheduleFlow.waitForExistence(timeout: 2))
    }

    func testKeyboardRoutesOpenNotesAndCalendar() {
        let app = XCUIApplication()
        app.launchArguments.append("--skip-boot")
        app.launch()
        XCTAssertTrue(app.otherElements["home.screen"].waitForExistence(timeout: 5))

        app.typeKey("5", modifierFlags: [])
        XCTAssertTrue(app.otherElements["notes.screen"].waitForExistence(timeout: 3))

        app.typeKey(XCUIKeyboardKey.escape.rawValue, modifierFlags: [])
        XCTAssertTrue(app.otherElements["home.screen"].waitForExistence(timeout: 3))

        app.typeKey("6", modifierFlags: [])
        XCTAssertTrue(app.otherElements["calendar.screen"].waitForExistence(timeout: 3))
    }

    func testPhaseThreeKeyboardRoutesOpenAttendanceAndOBS() {
        let app = XCUIApplication()
        app.launchArguments.append("--skip-boot")
        app.launch()
        XCTAssertTrue(app.otherElements["home.screen"].waitForExistence(timeout: 5))
        app.typeKey("2", modifierFlags: [])
        XCTAssertTrue(app.otherElements["attendance.screen"].waitForExistence(timeout: 3))
        app.typeKey(XCUIKeyboardKey.escape.rawValue, modifierFlags: [])
        app.typeKey("7", modifierFlags: [])
        XCTAssertTrue(app.otherElements["obs.screen"].waitForExistence(timeout: 3))
    }

    func testPhaseFourKeyboardRoutesOpenGymAndFinance() {
        let app = XCUIApplication()
        app.launchArguments.append("--skip-boot")
        app.launch()
        XCTAssertTrue(app.otherElements["home.screen"].waitForExistence(timeout: 5))
        app.typeKey("3", modifierFlags: [])
        XCTAssertTrue(app.otherElements["gym.screen"].waitForExistence(timeout: 3))
        app.typeKey(XCUIKeyboardKey.escape.rawValue, modifierFlags: [])
        app.typeKey("4", modifierFlags: [])
        XCTAssertTrue(app.otherElements["finance.screen"].waitForExistence(timeout: 3))
    }

    func testPhaseSixKeyboardRouteOpensOrganization() {
        let app = XCUIApplication()
        app.launchArguments.append("--skip-boot")
        app.launch()
        XCTAssertTrue(app.otherElements["home.screen"].waitForExistence(timeout: 5))
        app.typeKey("8", modifierFlags: [])
        XCTAssertTrue(app.otherElements["organization.screen"].waitForExistence(timeout: 3))
    }

    func testPhaseSevenQuickEntryShortcutOpensGuardedDraftScreen() {
        let app = XCUIApplication()
        app.launchArguments.append("--skip-boot")
        app.launch()
        XCTAssertTrue(app.otherElements["home.screen"].waitForExistence(timeout: 5))
        app.typeKey("n", modifierFlags: [.command, .shift])
        XCTAssertTrue(app.otherElements["quickEntry.screen"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.textFields["quickEntry.input"].exists)
    }

    func testPhaseSevenProposedPlanOpensFromToday() {
        let app = XCUIApplication()
        app.launchArguments.append("--skip-boot")
        app.launch()
        XCTAssertTrue(app.otherElements["home.screen"].waitForExistence(timeout: 5))
        app.buttons["Plan öner"].click()
        XCTAssertTrue(app.otherElements["planner.proposal.screen"].waitForExistence(timeout: 3))
    }

    func testPhaseEightMorningBriefingCanBeForcedAndAcknowledged() {
        let app = XCUIApplication()
        app.launchArguments.append("--skip-boot")
        app.launchArguments.append("--force-morning-briefing")
        app.launch()
        XCTAssertTrue(app.otherElements["briefing.screen"].waitForExistence(timeout: 5))
        app.buttons["GÜNÜMÜ BAŞLAT"].click()
        XCTAssertTrue(app.otherElements["home.screen"].waitForExistence(timeout: 3))
    }

    func testPhaseEightFreeStudyFocusOpensNativeFocusScreen() {
        let app = XCUIApplication()
        app.launchArguments.append("--skip-boot")
        app.launch()
        XCTAssertTrue(app.otherElements["home.screen"].waitForExistence(timeout: 5))
        app.typeKey("1", modifierFlags: [])
        app.buttons["Serbest çalışma odağı başlat"].click()
        XCTAssertTrue(app.otherElements["focus.screen"].waitForExistence(timeout: 3))
    }

    func testPhaseNineSettingsExposeExplicitNotificationOptInWithoutRequestingPermission() {
        let app = XCUIApplication()
        app.launchArguments.append("--skip-boot")
        app.launch()
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(app.otherElements["settings.phase9.screen"].waitForExistence(timeout: 3))
        app.buttons["Yerel bildirimleri etkinleştir…"].click()
        XCTAssertTrue(app.otherElements["notifications.optIn"].waitForExistence(timeout: 3))
        // The test intentionally stops before the explicit macOS permission
        // action; host notification permission is not an automation premise.
    }

    func testSettingsHotfixControlSystemNineOpensSettingsAndEscapeReturns() {
        let app = XCUIApplication()
        app.launchArguments.append("--skip-boot")
        app.launch()
        XCTAssertTrue(app.otherElements["home.screen"].waitForExistence(timeout: 5))
        app.typeKey("k", modifierFlags: .command)
        XCTAssertTrue(app.otherElements["controlSystem.screen"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.otherElements["controlSystem.settings"].waitForExistence(timeout: 3))
        app.typeKey("9", modifierFlags: [])
        XCTAssertTrue(app.otherElements["settings.phase9.screen"].waitForExistence(timeout: 3))
        app.typeKey(XCUIKeyboardKey.escape.rawValue, modifierFlags: [])
        XCTAssertTrue(app.otherElements["controlSystem.screen"].waitForExistence(timeout: 3))
    }

    func testSettingsHotfixCommandCommaOpensFromDailyPlan() {
        let app = XCUIApplication()
        app.launchArguments.append("--skip-boot")
        app.launch()
        XCTAssertTrue(app.otherElements["home.screen"].waitForExistence(timeout: 5))
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(app.otherElements["settings.phase9.screen"].waitForExistence(timeout: 3))
    }

    func testPhaseFourteenVoicePanelOpensOffWithoutRequestingPermission() {
        let app = XCUIApplication()
        app.launchArguments.append("--skip-boot")
        app.launch()
        XCTAssertTrue(app.otherElements["home.screen"].waitForExistence(timeout: 5))
        app.typeKey("v", modifierFlags: [.command, .shift])
        XCTAssertTrue(app.otherElements["voice.assistant.screen"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.textFields["voice.textInput"].exists)
        XCTAssertFalse(app.dialogs.matching(NSPredicate(format: "label CONTAINS[c] %@", "microphone")).firstMatch.exists)
    }

    func testPhaseFifteenTypedVoiceCommandShowsNoWritePreviewBeforeConfirmation() {
        let app = XCUIApplication()
        app.launchArguments.append("--skip-boot")
        app.launch()
        XCTAssertTrue(app.otherElements["home.screen"].waitForExistence(timeout: 5))
        app.typeKey("v", modifierFlags: [.command, .shift])
        let input = app.textFields["voice.textInput"]
        XCTAssertTrue(input.waitForExistence(timeout: 3))
        input.click()
        input.typeText("Yarın saat 17'de UI TEST çalışma görevi, 30 dakika")
        app.typeKey(XCUIKeyboardKey.return.rawValue, modifierFlags: [])
        XCTAssertTrue(app.otherElements["voice.action.preview"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Onayla ve uygula"].exists)
        // Stop at the inert preview: UI automation must never seed a live store.
        app.typeKey(XCUIKeyboardKey.escape.rawValue, modifierFlags: [])
    }
}
