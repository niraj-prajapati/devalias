import AppKit
import Foundation
import ServiceManagement

/// Launch at Login via `SMAppService.mainApp` (macOS 13+).
enum LoginItemService {
    enum LoginError: LocalizedError {
        case unsupported
        case requireApproval
        case disabled
        case other(String)

        var errorDescription: String? {
            switch self {
            case .unsupported:
                return "Launch at Login needs macOS 13 or later."
            case .requireApproval:
                return "macOS needs your approval in System Settings → General → Login Items."
            case .disabled:
                return "Launch at Login is disabled for DevAlias in System Settings."
            case .other(let message):
                return message
            }
        }
    }

    static var status: SMAppService.Status {
        SMAppService.mainApp.status
    }

    static var isEnabled: Bool {
        status == .enabled
    }

    static var statusSummary: String {
        switch status {
        case .enabled: return "Enabled"
        case .notRegistered: return "Off"
        case .notFound: return "Not found"
        case .requiresApproval: return "Needs approval in System Settings"
        @unknown default: return "Unknown"
        }
    }

    static func setEnabled(_ enabled: Bool) throws {
        let service = SMAppService.mainApp
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            switch service.status {
            case .requiresApproval:
                throw LoginError.requireApproval
            case .notFound:
                throw LoginError.other(error.localizedDescription)
            default:
                throw LoginError.other(error.localizedDescription)
            }
        }
        if enabled, service.status == .requiresApproval {
            throw LoginError.requireApproval
        }
        if enabled, service.status != .enabled, service.status != .requiresApproval {
            // Some macOS builds leave status transitional; surface disabled clearly.
            if service.status == .notFound {
                throw LoginError.disabled
            }
        }
    }

    static func openLoginItemsSettings() {
        // Ventura+ Login Items pane
        let urls = [
            "x-apple.systempreferences:com.apple.LoginItems-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.users?LoginItems",
        ]
        for raw in urls {
            if let url = URL(string: raw), NSWorkspace.shared.open(url) {
                return
            }
        }
    }
}
