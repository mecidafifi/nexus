import XCTest
@testable import NEXUS

@MainActor
final class Phase10NavigationTests: XCTestCase {
    func testNumericControlRoutingCoversAllEightStableModules() {
        XCTAssertEqual((1...8).compactMap(ManualNavigationPolicy.route(forNumber:)), AppRoute.allCases)
        XCTAssertEqual(ManualNavigationPolicy.route(forNumber: 1), .study)
        XCTAssertEqual(ManualNavigationPolicy.route(forNumber: 8), .organization)
    }

    func testNumericControlRoutingRejectsUnsupportedKeys() {
        XCTAssertNil(ManualNavigationPolicy.route(forNumber: 0))
        XCTAssertNil(ManualNavigationPolicy.route(forNumber: 9))
    }

    func testSettingsHotfixAddsNineWithoutChangingStableModuleRoutes() {
        XCTAssertEqual(ManualNavigationPolicy.controlDestination(forNumber: 1), .route(.study))
        XCTAssertEqual(ManualNavigationPolicy.controlDestination(forNumber: 8), .route(.organization))
        XCTAssertEqual(ManualNavigationPolicy.controlDestination(forNumber: 9), .settings)
        XCTAssertNil(ManualNavigationPolicy.controlDestination(forNumber: 0))
        XCTAssertNil(ManualNavigationPolicy.controlDestination(forNumber: 10))
        XCTAssertNil(ManualNavigationPolicy.route(forNumber: 9))
    }

    func testSettingsHotfixMapsPhysicalTopRowAndKeypadNumbersDeterministically() {
        XCTAssertEqual([18, 19, 20, 21, 23, 22, 26, 28, 25].compactMap {
            ManualNavigationPolicy.controlNumber(forMacKeyCode: UInt16($0))
        }, Array(1...9))
        XCTAssertEqual([83, 84, 85, 86, 87, 88, 89, 91, 92].compactMap {
            ManualNavigationPolicy.controlNumber(forMacKeyCode: UInt16($0))
        }, Array(1...9))
        XCTAssertNil(ManualNavigationPolicy.controlNumber(forMacKeyCode: 0))
    }

    func testEscapeClosesControlSystemBeforeReturningDashboard() {
        XCTAssertEqual(ManualNavigationPolicy.escapeDestination(controlSystemPresented: true), .controlSystemToDashboard)
        XCTAssertEqual(ManualNavigationPolicy.escapeDestination(controlSystemPresented: false), .dashboard)
    }

    func testDefaultLaunchStateIsBootBeforeDashboardWithNoFeatureRoute() {
        let boot = BootSequenceCoordinator()
        XCTAssertEqual(boot.stage, .booting)
        XCTAssertFalse(boot.hasStarted)
        let appState = AppState(bootSequence: boot)
        XCTAssertNil(appState.route)
        XCTAssertTrue(appState.bootSequence.isBooting)
    }

    func testExplicitBootSkipIsImmediateAndOneShot() {
        let boot = BootSequenceCoordinator()
        boot.begin(reduceMotion: false, forceSkip: true)
        XCTAssertEqual(boot.stage, .dashboard)
        XCTAssertTrue(boot.hasStarted)
        boot.begin(reduceMotion: false)
        XCTAssertEqual(boot.stage, .dashboard)
    }

    func testReducedMotionUsesStaticShortContinuationPolicy() {
        XCTAssertEqual(BootPresentationPolicy.duration(reduceMotion: false), 2.4)
        XCTAssertEqual(BootPresentationPolicy.duration(reduceMotion: true), 0.35)
        XCTAssertLessThan(BootPresentationPolicy.duration(reduceMotion: true), BootPresentationPolicy.duration(reduceMotion: false))
    }

    func testTerminalRevealProgressIsDeterministicAndSkippable() {
        var progress = TerminalRevealProgress(finalText: "NEXUS")
        progress.advance(by: 2)
        XCTAssertEqual(progress.visibleText, "NE")
        XCTAssertFalse(progress.isComplete)
        progress.complete()
        XCTAssertEqual(progress.visibleText, "NEXUS")
        XCTAssertTrue(progress.isComplete)
    }

    func testTerminalRevealCountsExtendedCharactersWithoutBreakingThem() {
        var progress = TerminalRevealProgress(finalText: "AĞ🌐")
        progress.advance(by: 2)
        XCTAssertEqual(progress.visibleText, "AĞ")
        progress.advance(by: 99)
        XCTAssertEqual(progress.visibleText, "AĞ🌐")
        XCTAssertTrue(progress.isComplete)
    }

    func testDailyPlanNewItemRequestsCourseFormWhenNoCourseExists() {
        XCTAssertEqual(DailyPlanNewItemPolicy.nextStep(courseCount: 0), .createCourse)
    }

    func testDailyPlanNewItemOpensScheduleWhenCourseExists() {
        XCTAssertEqual(DailyPlanNewItemPolicy.nextStep(courseCount: 1), .createSchedule)
        XCTAssertEqual(DailyPlanNewItemPolicy.nextStep(courseCount: 20), .createSchedule)
    }

    func testPhaseTenTwoDefaultsDailyPlanToWeek() {
        XCTAssertEqual(DailyPlanPresentationPolicy.defaultMode, .week)
        let appState = AppState(bootSequence: BootSequenceCoordinator())
        XCTAssertEqual(appState.consumeDailyPlanLaunchDefault(), .week)
        XCTAssertNil(appState.consumeDailyPlanLaunchDefault())
    }

    func testPhaseTenTwoBackdropIsDashboardOnlyAndControlSystemExcludesIt() {
        XCTAssertTrue(DailyPlanPresentationPolicy.showsNetworkBackdrop(route: nil, controlSystemPresented: false))
        XCTAssertFalse(DailyPlanPresentationPolicy.showsNetworkBackdrop(route: nil, controlSystemPresented: true))
        for route in AppRoute.allCases {
            XCTAssertFalse(DailyPlanPresentationPolicy.showsNetworkBackdrop(route: route, controlSystemPresented: false))
        }
        XCTAssertTrue(DailyPlanPresentationPolicy.pausesNetworkAnimation(reduceMotion: true))
        XCTAssertFalse(DailyPlanPresentationPolicy.pausesNetworkAnimation(reduceMotion: false))
    }

    func testPhaseTenTwoDefaultWindowMaximizeIsOneShot() {
        XCTAssertTrue(PrimaryWindowLaunchPolicy.shouldApplyDefaultMaximize(hasAppliedDefault: false))
        XCTAssertFalse(PrimaryWindowLaunchPolicy.shouldApplyDefaultMaximize(hasAppliedDefault: true))
    }
}
