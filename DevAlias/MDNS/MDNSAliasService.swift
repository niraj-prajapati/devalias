import Foundation
import Network
import dnssd

/// Temporary Bonjour/mDNS `<alias>.local` → LAN IPv4 while the hub is running.
/// Uses `dnssd` `DNSServiceRegisterRecord` (A). Does **not** change system LocalHostName.
final class MDNSAliasService: @unchecked Sendable {
    enum PublishError: Error, LocalizedError {
        case invalidAlias
        case invalidIPv4
        case connectionFailed(Int32)
        case registerFailed(Int32)

        var errorDescription: String? {
            switch self {
            case .invalidAlias: return "Invalid mDNS alias"
            case .invalidIPv4: return "Invalid LAN IPv4 for mDNS"
            case .connectionFailed(let code): return "DNSServiceCreateConnection failed (\(code))"
            case .registerFailed(let code): return "DNSServiceRegisterRecord failed (\(code))"
            }
        }
    }

    private let queue = DispatchQueue(label: "com.nandroidex.devalias.mdns")
    private var connection: DNSServiceRef?
    private var record: DNSRecordRef?
    private var publishedAlias: String?
    private var publishedIP: String?
    private var publishedPort: Int = 49_200
    private var pathMonitor: NWPathMonitor?
    private var resolveWatchdog: DispatchWorkItem?

    /// Supplemental browseable service (not sufficient alone for hostname URLs).
    private var netService: NetService?

    var onPublished: (@Sendable (String, String) -> Void)?
    var onFailed: (@Sendable (String) -> Void)?
    var onUnpublished: (@Sendable () -> Void)?
    /// Soft warning when local resolve check fails after publish.
    var onResolveWarning: (@Sendable (String) -> Void)?

    var isPublished: Bool {
        queue.sync { connection != nil && record != nil }
    }

    var currentAlias: String? {
        queue.sync { publishedAlias }
    }

    func publish(alias: String, ipv4: String, port: Int) throws {
        let trimmed = SettingsStore.stripLocalSuffix(alias)
        try queue.sync {
            try publishLocked(alias: trimmed, ipv4: ipv4, port: port)
        }
        onPublished?(trimmed, ipv4)
    }

    func unpublish() {
        queue.sync {
            tearDownLocked(notify: true)
        }
    }

    /// Re-publish if LAN IP / alias changed while still advertised.
    func updateIfNeeded(alias: String, ipv4: String, port: Int) {
        let trimmed = SettingsStore.stripLocalSuffix(alias)
        queue.async { [weak self] in
            guard let self else { return }
            guard self.connection != nil else { return }
            let same =
                self.publishedAlias == trimmed
                && self.publishedIP == ipv4
                && self.publishedPort == port
            guard !same else { return }
            do {
                try self.publishLocked(alias: trimmed, ipv4: ipv4, port: port)
                DispatchQueue.main.async {
                    self.onPublished?(trimmed, ipv4)
                }
            } catch {
                DispatchQueue.main.async {
                    self.onFailed?(error.localizedDescription)
                }
            }
        }
    }

    private func publishLocked(alias: String, ipv4: String, port: Int) throws {
        guard SettingsStore.isValidAlias(alias) else { throw PublishError.invalidAlias }
        var addr = in_addr()
        let parsed = ipv4.withCString { inet_pton(AF_INET, $0, &addr) == 1 }
        guard parsed else { throw PublishError.invalidIPv4 }

        tearDownLocked(notify: false)

        var created: DNSServiceRef?
        var error = DNSServiceCreateConnection(&created)
        guard error == kDNSServiceErr_NoError, let created else {
            throw PublishError.connectionFailed(error)
        }

        error = DNSServiceSetDispatchQueue(created, queue)
        guard error == kDNSServiceErr_NoError else {
            DNSServiceRefDeallocate(created)
            throw PublishError.connectionFailed(error)
        }

        let fullName = "\(alias).local."
        // Prefer Unique; if the name is already claimed on the LAN, fall back to Shared
        // so we still answer (may coexist with another owner).
        var recordRef: DNSRecordRef?
        error = registerARecord(
            connection: created,
            recordRef: &recordRef,
            fullName: fullName,
            addr: &addr,
            flags: DNSServiceFlags(kDNSServiceFlagsUnique)
        )
        if error != kDNSServiceErr_NoError {
            error = registerARecord(
                connection: created,
                recordRef: &recordRef,
                fullName: fullName,
                addr: &addr,
                flags: DNSServiceFlags(kDNSServiceFlagsShared)
            )
        }

        guard error == kDNSServiceErr_NoError, recordRef != nil else {
            DNSServiceRefDeallocate(created)
            throw PublishError.registerFailed(error)
        }

        connection = created
        record = recordRef
        publishedAlias = alias
        publishedIP = ipv4
        publishedPort = port

        startSupplementalNetServiceLocked(alias: alias, ipv4: ipv4, port: port)
        startPathMonitorLocked()
        scheduleResolveWatchdogLocked(alias: alias)
    }

    private func registerARecord(
        connection: DNSServiceRef,
        recordRef: inout DNSRecordRef?,
        fullName: String,
        addr: inout in_addr,
        flags: DNSServiceFlags
    ) -> DNSServiceErrorType {
        // CRITICAL: pass pointer to the 4-byte in_addr, not a Swift Array header.
        withUnsafePointer(to: &addr) { ptr in
            DNSServiceRegisterRecord(
                connection,
                &recordRef,
                flags,
                UInt32(kDNSServiceInterfaceIndexAny),
                fullName,
                UInt16(kDNSServiceType_A),
                UInt16(kDNSServiceClass_IN),
                4,
                ptr,
                120,
                { _, _, _, errorCode, _ in
                    if errorCode == kDNSServiceErr_NameConflict {
                        // Conflict reported asynchronously; AppState resolve watchdog covers UX.
                    }
                },
                nil
            )
        }
    }

    private func tearDownLocked(notify: Bool) {
        resolveWatchdog?.cancel()
        resolveWatchdog = nil
        pathMonitor?.cancel()
        pathMonitor = nil

        if let netService {
            DispatchQueue.main.async {
                netService.stop()
            }
        }
        netService = nil

        if let connection {
            DNSServiceRefDeallocate(connection)
        }
        connection = nil
        record = nil
        publishedAlias = nil
        publishedIP = nil

        if notify {
            DispatchQueue.main.async { [weak self] in
                self?.onUnpublished?()
            }
        }
    }

    private func startSupplementalNetServiceLocked(alias: String, ipv4: String, port: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let service = NetService(
                domain: "local.",
                type: "_http._tcp.",
                name: "DevAlias",
                port: Int32(clamping: port)
            )
            service.includesPeerToPeer = true
            self.netService = service
            service.publish()
            _ = alias
            _ = ipv4
        }
    }

    private func startPathMonitorLocked() {
        let monitor = NWPathMonitor()
        pathMonitor = monitor
        monitor.pathUpdateHandler = { [weak self] _ in
            guard let self else { return }
            guard let alias = self.publishedAlias else { return }
            let port = self.publishedPort
            let currentIP = self.publishedIP
            guard let ip = LANAddressProvider.primaryIPv4(), ip != currentIP else { return }
            do {
                try self.publishLocked(alias: alias, ipv4: ip, port: port)
                DispatchQueue.main.async {
                    self.onPublished?(alias, ip)
                }
            } catch {
                DispatchQueue.main.async {
                    self.onFailed?(error.localizedDescription)
                }
            }
        }
        monitor.start(queue: queue)
    }

    private func scheduleResolveWatchdogLocked(alias: String) {
        resolveWatchdog?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Self.checkResolve(alias: alias) { ok, resolvedIP in
                guard let self else { return }
                if ok {
                    return
                }
                self.onResolveWarning?(
                    "\(alias).local is not resolving yet. Use the LAN IP URL (include :\(self.publishedPort)). Android mDNS is often flaky."
                )
                _ = resolvedIP
            }
        }
        resolveWatchdog = work
        queue.asyncAfter(deadline: .now() + 2.0, execute: work)
    }

    private static func checkResolve(alias: String, completion: @escaping (Bool, String?) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            var hints = addrinfo(
                ai_flags: AI_ADDRCONFIG,
                ai_family: AF_INET,
                ai_socktype: SOCK_STREAM,
                ai_protocol: 0,
                ai_addrlen: 0,
                ai_canonname: nil,
                ai_addr: nil,
                ai_next: nil
            )
            var result: UnsafeMutablePointer<addrinfo>?
            let code = getaddrinfo("\(alias).local", nil, &hints, &result)
            defer { if let result { freeaddrinfo(result) } }
            guard code == 0, let result, let addr = result.pointee.ai_addr else {
                completion(false, nil)
                return
            }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let gni = getnameinfo(
                addr,
                socklen_t(result.pointee.ai_addrlen),
                &host,
                socklen_t(host.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            let ip = gni == 0 ? String(cString: host) : nil
            completion(true, ip)
        }
    }

}
