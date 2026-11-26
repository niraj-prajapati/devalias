import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    var appState: AppState?
    var onSaved: (() -> Void)?

    @State private var aliasDraft: String = ""
    @State private var portDraft: String = ""
    @State private var aliasError: String?
    @State private var savedFlash = false
    @State private var hostActionMessage: String?
    @State private var hostActionError: String?
    @State private var confirmPermanent = false
    @State private var confirmRemovePort80 = false
    @State private var port80BusyHint: String?
    @State private var port80Message: String?
    @State private var port80Error: String?
    @State private var port80BusyWorking = false
    @State private var systemLocalHostName: String = HostNameHelper.currentLocalHostName() ?? "(unknown)"
    @State private var ignorePortsDraft: String = ""
    @State private var ignoreNamesDraft: String = ""
    @State private var loginMessage: String?
    @State private var loginError: String?
    @State private var showAdvanced = false
    @State private var showAbout = false

    init(settings: SettingsStore, appState: AppState? = nil, onSaved: (() -> Void)? = nil) {
        self.settings = settings
        self.appState = appState
        self.onSaved = onSaved
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            hubRow
            port80Row
            startupRows
            if hasMessages { messages }

            TerminalDisclosureRow(title: "advanced", isExpanded: $showAdvanced)
            if showAdvanced {
                advancedContent.padding(.leading, 22)
            }

            TerminalDisclosureRow(title: "about / uninstall", isExpanded: $showAbout)
            if showAbout {
                aboutContent.padding(.leading, 22)
            }
        }
        .tint(TerminalTheme.accent)
        .onAppear(perform: reloadDrafts)
        .confirmationDialog(
            "Set system LocalHostName to \"\(settings.hostnameAlias)\"?",
            isPresented: $confirmPermanent,
            titleVisibility: .visible
        ) {
            Button("Set LocalHostName", role: .destructive, action: applyPermanent)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Changes the Mac’s Bonjour name for all apps. Previous value can be restored.")
        }
        .confirmationDialog(
            "Remove Port 80 forwarding?",
            isPresented: $confirmRemovePort80,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive, action: removePort80)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(verbatim: "Phones will need :\(settings.highPort) again.")
        }
    }

    // MARK: - Compact rows

    private var hubRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("hub")
                    .font(TerminalTheme.mono(10))
                    .foregroundStyle(TerminalTheme.mute)
                InfoHint(text: "Alias → http://alias.local with Port 80. Hub listens on the high port (default 49200).")
                Spacer(minLength: 0)
                if savedFlash {
                    Text("saved")
                        .font(TerminalTheme.mono(10))
                        .foregroundStyle(TerminalTheme.accentDim)
                }
            }
            HStack(spacing: 6) {
                TextField("alias", text: $aliasDraft)
                    .terminalField()
                    .onSubmit(saveAlias)
                TextField("port", text: $portDraft)
                    .terminalField()
                    .frame(width: 64)
                    .onSubmit(savePort)
                Button("save") { saveAll() }
                    .buttonStyle(.plain)
                    .font(TerminalTheme.mono(11, weight: .medium))
                    .foregroundStyle(TerminalTheme.bg)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(TerminalTheme.accent)
                    .keyboardShortcut(.defaultAction)
            }
            Text(verbatim: settings.port80Installed
                 ? "→ http://\(previewAlias).local"
                 : "→ http://\(previewAlias).local:\(settings.highPort)")
                .font(TerminalTheme.mono(10))
                .foregroundStyle(TerminalTheme.dim)
            if let aliasError {
                Text(aliasError)
                    .font(TerminalTheme.mono(10))
                    .foregroundStyle(TerminalTheme.danger)
            }
        }
    }

    private var port80Row: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("port 80")
                    .font(TerminalTheme.mono(10))
                    .foregroundStyle(TerminalTheme.mute)
                InfoHint(text: "pf: phones → LAN IP:\(settings.highPort); Mac → lo0. Re-enable after Wi‑Fi IP changes.")
                Text(settings.port80Installed ? "on" : "off")
                    .font(TerminalTheme.mono(10, weight: .medium))
                    .foregroundStyle(settings.port80Installed ? TerminalTheme.accent : TerminalTheme.dim)
                Spacer(minLength: 0)
                if settings.port80Installed {
                    Button("remove") { confirmRemovePort80 = true }
                        .terminalGhostButton()
                        .disabled(port80BusyWorking)
                } else {
                    Button(port80BusyWorking ? "…" : "enable") { enablePort80() }
                        .terminalGhostButton()
                        .disabled(port80BusyWorking || port80BusyHint != nil)
                }
            }
            if let port80BusyHint {
                Text(port80BusyHint)
                    .font(TerminalTheme.mono(10))
                    .foregroundStyle(TerminalTheme.warn)
                    .lineLimit(2)
            }
        }
    }

    private var startupRows: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("startup")
                    .font(TerminalTheme.mono(10))
                    .foregroundStyle(TerminalTheme.mute)
                InfoHint(text: "Launch at Login = menu icon after reboot. Auto-start Hub = HTTP listener on launch.")
                Spacer(minLength: 0)
            }
            compactToggle(
                title: "launch at login",
                isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { applyLaunchAtLogin($0) }
                )
            )
            compactToggle(title: "auto-start hub", isOn: $settings.autoStartServer)
            if LoginItemService.status == .requiresApproval {
                Button("open login items…") {
                    LoginItemService.openLoginItemsSettings()
                }
                .terminalGhostButton()
            }
        }
    }

    private func compactToggle(title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(TerminalTheme.mono(11))
                .foregroundStyle(TerminalTheme.fg)
            Spacer(minLength: 0)
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
        }
        .padding(.vertical, 1)
    }

    private var advancedContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("ignore ports", text: $ignorePortsDraft)
                .terminalField()
                .onSubmit(saveIgnores)
            TextField("ignore process", text: $ignoreNamesDraft)
                .terminalField()
                .onSubmit(saveIgnores)
            HStack(spacing: 6) {
                Text(verbatim: "hostname \(systemLocalHostName)")
                    .font(TerminalTheme.mono(10))
                    .foregroundStyle(TerminalTheme.dim)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Button("set") { confirmPermanent = true }
                    .terminalGhostButton()
                    .disabled(!SettingsStore.isValidAlias(settings.hostnameAlias))
                if settings.previousLocalHostName != nil {
                    Button("restore") { restorePermanent() }
                        .terminalGhostButton()
                }
            }
        }
    }

    private var aboutContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: "devalias \(versionString) · mit")
                .font(TerminalTheme.mono(10))
                .foregroundStyle(TerminalTheme.dim)
            Text("uninstall: disable login → remove port 80 → quit → delete .app")
                .font(TerminalTheme.mono(10))
                .foregroundStyle(TerminalTheme.dim)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                Button("remove port 80") { confirmRemovePort80 = true }
                    .terminalGhostButton()
                    .disabled(!settings.port80Installed || port80BusyWorking)
                Button("disable login") { applyLaunchAtLogin(false) }
                    .terminalGhostButton()
                    .disabled(!LoginItemService.isEnabled)
            }
        }
    }

    private var hasMessages: Bool {
        port80Message != nil || port80Error != nil || hostActionMessage != nil
            || hostActionError != nil || loginMessage != nil || loginError != nil
    }

    private var messages: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let port80Message {
                Text(port80Message).font(TerminalTheme.mono(10)).foregroundStyle(TerminalTheme.dim)
            }
            if let port80Error {
                Text(port80Error).font(TerminalTheme.mono(10)).foregroundStyle(TerminalTheme.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let hostActionMessage {
                Text(hostActionMessage).font(TerminalTheme.mono(10)).foregroundStyle(TerminalTheme.dim)
            }
            if let hostActionError {
                Text(hostActionError).font(TerminalTheme.mono(10)).foregroundStyle(TerminalTheme.danger)
            }
            if let loginMessage {
                Text(loginMessage).font(TerminalTheme.mono(10)).foregroundStyle(TerminalTheme.dim)
            }
            if let loginError {
                Text(loginError).font(TerminalTheme.mono(10)).foregroundStyle(TerminalTheme.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Actions

    private var previewAlias: String {
        let draft = SettingsStore.stripLocalSuffix(aliasDraft)
        return draft.isEmpty ? settings.hostnameAlias : draft
    }

    private var versionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    private func reloadDrafts() {
        aliasDraft = settings.hostnameAlias
        portDraft = String(settings.highPort)
        ignorePortsDraft = settings.ignoredPortsCSV
        ignoreNamesDraft = settings.ignoredProcessSubstringsCSV
        savedFlash = false
        aliasError = nil
        loginMessage = nil
        loginError = nil
        systemLocalHostName = HostNameHelper.currentLocalHostName() ?? "(unknown)"
        settings.launchAtLogin = LoginItemService.isEnabled
        appState?.refreshPort80StatusFromDisk()
        port80BusyHint = Port80Occupancy.busyMessage()
    }

    private func saveAll() {
        saveAlias()
        savePort()
        saveIgnores()
        guard aliasError == nil else { return }
        savedFlash = true
        appState?.refreshDiscovery()
        onSaved?()
    }

    private func saveAlias() {
        if settings.setHostnameAlias(aliasDraft) {
            aliasError = nil
            aliasDraft = settings.hostnameAlias
        } else {
            aliasError = "letters, digits, hyphens only — no .local"
        }
    }

    private func savePort() {
        guard let value = Int(portDraft.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            portDraft = String(settings.highPort)
            return
        }
        settings.highPort = value
        portDraft = String(settings.highPort)
    }

    private func saveIgnores() {
        settings.setIgnoredPorts(fromCSV: ignorePortsDraft)
        settings.setIgnoredProcessSubstrings(fromCSV: ignoreNamesDraft)
        ignorePortsDraft = settings.ignoredPortsCSV
        ignoreNamesDraft = settings.ignoredProcessSubstringsCSV
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        loginError = nil
        loginMessage = nil
        do {
            try LoginItemService.setEnabled(enabled)
            settings.launchAtLogin = LoginItemService.isEnabled
            if LoginItemService.status == .requiresApproval {
                loginError = LoginItemService.LoginError.requireApproval.errorDescription
            } else {
                loginMessage = enabled ? "login enabled" : "login disabled"
            }
        } catch {
            settings.launchAtLogin = LoginItemService.isEnabled
            loginError = error.localizedDescription
        }
    }

    private func enablePort80() {
        port80Error = nil
        port80Message = nil
        port80BusyHint = Port80Occupancy.busyMessage()
        if port80BusyHint != nil { return }
        savePort()
        port80BusyWorking = true
        do {
            try appState?.enablePort80Forwarding()
            port80Message = "port 80 on → http://\(settings.hostnameAlias).local/"
        } catch {
            port80Error = error.localizedDescription
        }
        port80BusyWorking = false
    }

    private func removePort80() {
        port80Error = nil
        port80Message = nil
        port80BusyWorking = true
        do {
            try appState?.disablePort80Forwarding()
            port80Message = "port 80 removed"
        } catch {
            port80Error = error.localizedDescription
        }
        port80BusyWorking = false
    }

    private func applyPermanent() {
        hostActionError = nil
        hostActionMessage = nil
        do {
            saveAlias()
            guard aliasError == nil else { return }
            try appState?.setPermanentLocalHostName()
            systemLocalHostName = HostNameHelper.currentLocalHostName() ?? settings.hostnameAlias
            hostActionMessage = "LocalHostName → \(settings.hostnameAlias)"
        } catch {
            hostActionError = error.localizedDescription
        }
    }

    private func restorePermanent() {
        hostActionError = nil
        hostActionMessage = nil
        do {
            let previous = settings.previousLocalHostName ?? ""
            try appState?.restorePreviousLocalHostName()
            systemLocalHostName = HostNameHelper.currentLocalHostName() ?? previous
            hostActionMessage = "restored → \(previous)"
        } catch {
            hostActionError = error.localizedDescription
        }
    }
}
