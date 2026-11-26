import XCTest
@testable import DevAlias

@MainActor
final class AppStateTests: XCTestCase {
    func testPlaceholderStatusWhenStopped() {
        let suite = "DevAlias.AppStateTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = SettingsStore(defaults: defaults)
        _ = settings.setHostnameAlias("dev")
        let state = AppState(settings: settings)
        XCTAssertEqual(state.runState, .stopped)
        XCTAssertEqual(state.statusSummary, "Stopped")
        XCTAssertTrue(state.servers.isEmpty)
        XCTAssertNil(state.lastError)
        XCTAssertEqual(state.status.alias, "dev")
    }
}
