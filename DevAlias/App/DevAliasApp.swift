import AppKit
import SwiftUI

@main
struct DevAliasApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("DevAlias", systemImage: "antenna.radiowaves.left.and.right") {
            MenuBarRootView(appState: appDelegate.appState)
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState(settings: SettingsStore())
    private let wakeRecovery = WakeRecovery()

    func applicationDidFinishLaunching(_ notification: Notification) {
        wakeRecovery.start(appState: appState)
        appState.refreshLANAddress()
        appState.refreshPort80StatusFromDisk()
        // Sync toggle with SMAppService reality (user may have changed Login Items in System Settings).
        appState.settings.launchAtLogin = LoginItemService.isEnabled

        // Auto-start hub is a separate preference (default off).
        if appState.settings.autoStartServer {
            appState.startHub()
        }
    }
}
