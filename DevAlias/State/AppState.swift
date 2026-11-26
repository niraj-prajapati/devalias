import Combine
import Foundation

/// Central observable app state. Owns hub, mDNS, and discovery polling.
@MainActor
final class AppState: ObservableObject {
    @Published var runState: HubRunState = .stopped
    @Published var hubURL: URL?
    @Published var lanIP: String?
    @Published var servers: [DiscoveredServer] = []
    @Published var lastError: String?
    @Published var mdnsPublished = false
    @Published var mdnsWarning: String?
    @Published var isDiscovering = false

    let settings: SettingsStore
    private let hub: HubHTTPServer
    private let mdns: MDNSAliasService
    private var cancellables = Set<AnyCancellable>()
    private var discoveryTimer: AnyCancellable?

    init(
        settings: SettingsStore,
        hub: HubHTTPServer = HubHTTPServer(),
        mdns: MDNSAliasService = MDNSAliasService()
    ) {
        self.settings = settings
        self.hub = hub
        self.mdns = mdns
        self.lanIP = LANAddressProvider.primaryIPv4()

        settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
                self?.refreshHubURLIfRunning()
                self?.republishMDNSIfRunning()
            }
            .store(in: &cancellables)

        hub.onBindFailure = { [weak self] message in
            Task { @MainActor in
                self?.stopDiscoveryLoop()
                self?.mdns.unpublish()
                self?.mdnsPublished = false
                self?.runState = .error
                self?.lastError = UserFacingErrors.mapBindFailure(message)
                self?.hubURL = nil
            }
        }

        mdns.onPublished = { [weak self] _, ip in
            Task { @MainActor in
                self?.mdnsPublished = true
                self?.lanIP = ip
                self?.mdnsWarning = nil
            }
        }
        mdns.onFailed = { [weak self] message in
            Task { @MainActor in
                self?.mdnsPublished = false
                self?.mdnsWarning = message
            }
        }
        mdns.onUnpublished = { [weak self] in
            Task { @MainActor in
                self?.mdnsPublished = false
            }
        }
        mdns.onResolveWarning = { [weak self] message in
            Task { @MainActor in
                self?.mdnsWarning = message
            }
        }
    }

    var status: HubStatus {
        HubStatus(
            runState: runState,
            highPort: settings.highPort,
            alias: settings.hostnameAlias,
            lanIP: lanIP,
            lastError: lastError
        )
    }

    var statusSummary: String {
        switch runState {
        case .stopped: return "Stopped"
        case .starting: return "Starting…"
        case .running: return mdnsPublished ? "Running · mDNS" : "Running"
        case .stopping: return "Stopping…"
        case .error: return lastError ?? "Error"
        }
    }

    var aliasURLString: String {
        let alias = settings.hostnameAlias
        if settings.port80Installed {
            return "http://\(alias).local"
        }
        return "http://\(alias).local:\(settings.highPort)"
    }

    var lanURLString: String? {
        guard let lanIP else { return nil }
        // Phones should use LAN IP — `.local` is often broken on Android and some iOS/Wi‑Fi setups.
        if settings.port80Installed {
            return "http://\(lanIP)/"
        }
        return "http://\(lanIP):\(settings.highPort)/"
    }

    /// QR / copy URL — mode from Settings (`.local` first; LAN fallback).
    var preferredShareURLString: String? {
        guard runState == .running else { return nil }
        switch settings.shareURLMode {
        case .aliasLocal:
            return aliasURLString
        case .lanIP:
            return lanURLString ?? aliasURLString
        }
    }

    func refreshLANAddress() {
        lanIP = LANAddressProvider.primaryIPv4()
    }

    func startHub() {
        guard runState == .stopped || runState == .error else { return }
        lastError = nil
        mdnsWarning = nil
        runState = .starting
        refreshLANAddress()
        hub.updateServers(servers)

        let port = UInt16(clamping: settings.highPort)
        do {
            try hub.start(port: port)
        } catch {
            runState = .error
            lastError = UserFacingErrors.mapBindFailure(error.localizedDescription)
            return
        }

        if lanIP == nil {
            mdnsWarning = UserFacingErrors.noLANIP
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard self.runState == .starting else { return }
            if self.hub.isRunning {
                self.runState = .running
                self.hubURL = URL(string: self.aliasURLString)
                self.syncServersToHub()
                self.publishMDNS()
                self.startDiscoveryLoop()
                self.refreshDiscovery()
            }
        }
    }

    func stopHub() {
        guard runState == .running || runState == .starting || runState == .error else { return }
        runState = .stopping
        stopDiscoveryLoop()
        mdns.unpublish()
        mdnsPublished = false
        mdnsWarning = nil
        hub.stop()
        runState = .stopped
        hubURL = nil
        lastError = nil
    }

    func syncServersToHub() {
        hub.updateServers(servers)
        hub.updateStatus(
            alias: settings.hostnameAlias,
            highPort: settings.highPort,
            lanIP: lanIP,
            port80: settings.port80Installed
        )
    }

    /// Manual / timer-driven discovery refresh (off main thread for scan).
    func refreshDiscovery() {
        guard !isDiscovering else { return }
        isDiscovering = true
        let ignored = settings.ignoredPorts + [settings.highPort]
        let nameFilters = settings.ignoredProcessSubstrings
        Task.detached(priority: .utility) {
            let found = DiscoveryEngine.discover(
                ignoredPorts: ignored,
                ignoredProcessSubstrings: nameFilters
            )
            await MainActor.run {
                self.servers = found
                self.syncServersToHub()
                self.isDiscovering = false
            }
        }
    }

    func enablePort80Forwarding() throws {
        refreshLANAddress()
        guard lanIP != nil else {
            throw PrivilegedOperations.OperationError.failed(UserFacingErrors.noLANIP)
        }
        do {
            try PrivilegedOperations.enablePort80Forwarding(
                highPort: settings.highPort,
                interface: LANAddressProvider.primaryAddress()?.interface,
                redirectIPv4: lanIP
            )
        } catch let error as PrivilegedOperations.OperationError {
            throw PrivilegedOperations.OperationError.failed(
                UserFacingErrors.mapPrivilegedFailure(error.localizedDescription)
            )
        } catch {
            throw PrivilegedOperations.OperationError.failed(
                UserFacingErrors.mapPrivilegedFailure(error.localizedDescription)
            )
        }
        settings.port80Installed = true
        refreshHubURLIfRunning()
        syncServersToHub()
    }

    func disablePort80Forwarding() throws {
        try PrivilegedOperations.disablePort80Forwarding()
        settings.port80Installed = false
        refreshHubURLIfRunning()
    }

    /// True when the hub process thinks it is running but the listener is gone (post-sleep).
    func hubNeedsRestartAfterWake() -> Bool {
        runState == .running && !hub.isRunning
    }

    func restartHubAfterWake() {
        stopHub()
        startHub()
    }

    func republishMDNSAfterWake() {
        republishMDNSIfRunning()
        if lanIP == nil {
            mdnsWarning = UserFacingErrors.noLANIP
        } else if !mdnsPublished {
            publishMDNS()
        }
    }

    func refreshPort80StatusFromDisk() {
        let status = PrivilegedOperations.status()
        settings.port80Installed = status.installed
    }

    func setPermanentLocalHostName() throws {
        let alias = settings.hostnameAlias
        guard SettingsStore.isValidAlias(alias) else {
            throw HostNameHelper.HostError.invalidAlias
        }
        let current = HostNameHelper.currentLocalHostName()
        if let current, current != alias {
            settings.previousLocalHostName = current
        }
        try HostNameHelper.setLocalHostName(alias)
    }

    func restorePreviousLocalHostName() throws {
        guard let previous = settings.previousLocalHostName, !previous.isEmpty else {
            throw HostNameHelper.HostError.emptyValue
        }
        try HostNameHelper.restoreLocalHostName(previous)
        settings.previousLocalHostName = nil
    }

    private func startDiscoveryLoop() {
        stopDiscoveryLoop()
        discoveryTimer = Timer.publish(every: 3.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshDiscovery()
            }
    }

    private func stopDiscoveryLoop() {
        discoveryTimer?.cancel()
        discoveryTimer = nil
        isDiscovering = false
    }

    private func publishMDNS() {
        guard let lanIP else {
            mdnsWarning = "No LAN IPv4 — mDNS alias not published. Use Wi‑Fi or the IP URL when available."
            mdnsPublished = false
            return
        }
        do {
            try mdns.publish(alias: settings.hostnameAlias, ipv4: lanIP, port: settings.highPort)
            mdnsPublished = true
        } catch {
            mdnsPublished = false
            mdnsWarning = error.localizedDescription
        }
    }

    private func republishMDNSIfRunning() {
        guard runState == .running else { return }
        refreshLANAddress()
        guard let lanIP else { return }
        mdns.updateIfNeeded(alias: settings.hostnameAlias, ipv4: lanIP, port: settings.highPort)
    }

    private func refreshHubURLIfRunning() {
        guard runState == .running else { return }
        hubURL = URL(string: aliasURLString)
    }
}
