import AppKit
import Foundation
import Network

/// Re-binds hub/mDNS and refreshes LAN IP after sleep / interface changes.
@MainActor
final class WakeRecovery {
    private weak var appState: AppState?
    private var pathMonitor: NWPathMonitor?
    private let monitorQueue = DispatchQueue(label: "com.nandroidex.devalias.path")

    func start(appState: AppState) {
        self.appState = appState

        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleWakeOrPathChange(reason: "wake")
            }
        }

        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                if path.status == .satisfied {
                    self.handleWakeOrPathChange(reason: "network")
                } else {
                    self.appState?.lastError = UserFacingErrors.noLANIP
                    self.appState?.lanIP = nil
                }
            }
        }
        monitor.start(queue: monitorQueue)
        pathMonitor = monitor
    }

    private func handleWakeOrPathChange(reason: String) {
        guard let appState else { return }
        _ = reason
        appState.refreshLANAddress()
        appState.refreshPort80StatusFromDisk()

        if appState.lanIP == nil {
            appState.mdnsWarning = UserFacingErrors.noLANIP
        }

        guard appState.runState == .running else { return }

        if appState.hubNeedsRestartAfterWake() {
            appState.restartHubAfterWake()
        } else {
            appState.republishMDNSAfterWake()
            appState.refreshDiscovery()
            appState.syncServersToHub()
        }
    }
}
