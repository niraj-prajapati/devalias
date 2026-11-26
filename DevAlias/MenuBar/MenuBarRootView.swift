import AppKit
import SwiftUI

struct MenuBarRootView: View {
    @ObservedObject var appState: AppState
    @State private var copiedFlash = false
    @State private var showingSettings = false

    var body: some View {
        Group {
            if showingSettings {
                settingsPanel
            } else {
                mainPanel
            }
        }
        // Pad first, then size the window — framing before padding crushed insets to 0.
        .padding(14)
        .frame(width: 340)
        .background(TerminalTheme.bg)
        .preferredColorScheme(.dark)
        .tint(TerminalTheme.accent)
        .onAppear {
            // Always land on home when the menu opens (not leftover Settings).
            showingSettings = false
            appState.refreshLANAddress()
            if appState.runState == .running {
                appState.refreshDiscovery()
            }
        }
        .onDisappear {
            showingSettings = false
        }
    }

    private var mainPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            ServerStatusHeader(appState: appState)
                .terminalPanel()

            metaStrip
                .padding(.top, 8)

            qrBlock
                .padding(.top, 8)

            if let warning = appState.mdnsWarning {
                Text(warning)
                    .font(TerminalTheme.mono(10))
                    .foregroundStyle(TerminalTheme.warn)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
                    .lineLimit(2)
            }

            listenersBlock
                .padding(.top, 8)

            footerBar
                .padding(.top, 8)
        }
    }

    private var metaStrip: some View {
        HStack(spacing: 0) {
            if let lan = appState.lanIP {
                Text(lan)
                    .foregroundStyle(TerminalTheme.accentDim)
            } else {
                Text("no lan ip")
                    .foregroundStyle(TerminalTheme.warn)
            }
            Text(" │ ")
                .foregroundStyle(TerminalTheme.mute)
            Text("\(appState.settings.hostnameAlias).local")
                .foregroundStyle(TerminalTheme.dim)
            Text(" │ ")
                .foregroundStyle(TerminalTheme.mute)
            Text(verbatim: ":\(appState.settings.highPort)")
                .foregroundStyle(TerminalTheme.dim)
            Spacer(minLength: 0)
        }
        .font(TerminalTheme.mono(10))
        .lineLimit(1)
    }

    private var qrBlock: some View {
        HStack(alignment: .top, spacing: 10) {
            QRCodeView(urlString: appState.preferredShareURLString)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text("qr")
                        .font(TerminalTheme.mono(11, weight: .medium))
                        .foregroundStyle(TerminalTheme.fg)
                    InfoHint(text: "Default encodes .local. If the phone cannot open it (common on Android), switch to ip.")
                }

                qrModePicker

                if let url = appState.preferredShareURLString {
                    Text(url)
                        .font(TerminalTheme.mono(10))
                        .foregroundStyle(TerminalTheme.accentDim)
                        .lineLimit(2)
                        .textSelection(.enabled)
                    Button(copiedFlash ? "copied" : "copy") {
                        copyToPasteboard(url)
                    }
                    .terminalGhostButton()
                } else if appState.runState != .running {
                    Text("start hub for qr")
                        .font(TerminalTheme.mono(10))
                        .foregroundStyle(TerminalTheme.dim)
                } else {
                    Text("join wifi for ip qr")
                        .font(TerminalTheme.mono(10))
                        .foregroundStyle(TerminalTheme.warn)
                }

                if appState.settings.shareURLMode == .aliasLocal {
                    Text("fails on phone? → ip")
                        .font(TerminalTheme.mono(9))
                        .foregroundStyle(TerminalTheme.mute)
                }
            }
            Spacer(minLength: 0)
        }
        .terminalPanel()
    }

    private var qrModePicker: some View {
        HStack(spacing: 0) {
            qrModeButton(title: ".local", mode: .aliasLocal)
            qrModeButton(title: "ip", mode: .lanIP)
        }
        .overlay(Rectangle().stroke(TerminalTheme.line, lineWidth: 1))
    }

    private func qrModeButton(title: String, mode: ShareURLMode) -> some View {
        let selected = appState.settings.shareURLMode == mode
        return Button {
            appState.settings.shareURLMode = mode
        } label: {
            Text(title)
                .font(TerminalTheme.mono(10, weight: .medium))
                .foregroundStyle(selected ? TerminalTheme.bg : TerminalTheme.dim)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .frame(minWidth: 52)
                .background(selected ? TerminalTheme.accent : Color.clear)
        }
        .buttonStyle(.plain)
    }

    private var listenersBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("listeners")
                    .font(TerminalTheme.mono(10))
                    .foregroundStyle(TerminalTheme.mute)
                Spacer()
                if appState.isDiscovering {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(TerminalTheme.accent)
                }
                Button("refresh") {
                    appState.refreshDiscovery()
                }
                .buttonStyle(.plain)
                .font(TerminalTheme.mono(10))
                .foregroundStyle(TerminalTheme.accentDim)
                .disabled(appState.runState != .running || appState.isDiscovering)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .overlay(alignment: .bottom) {
                Rectangle().fill(TerminalTheme.line).frame(height: 1)
            }

            Group {
                if appState.runState != .running {
                    Text("start hub to scan")
                        .font(TerminalTheme.mono(11))
                        .foregroundStyle(TerminalTheme.dim)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if appState.servers.isEmpty {
                    Text("no listeners")
                        .font(TerminalTheme.mono(11))
                        .foregroundStyle(TerminalTheme.dim)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(appState.servers.enumerated()), id: \.element.id) { index, server in
                            DiscoveredServerRow(server: server)
                            if index < appState.servers.count - 1 {
                                Rectangle().fill(TerminalTheme.line).frame(height: 1)
                            }
                        }
                    }
                }
            }
        }
        .background(TerminalTheme.panel)
        .overlay(
            Rectangle()
                .stroke(TerminalTheme.line, lineWidth: 1)
        )
    }

    private var footerBar: some View {
        HStack(spacing: 8) {
            Button("settings") {
                showingSettings = true
            }
            .terminalGhostButton()

            Spacer()

            Button("quit") {
                appState.stopHub()
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(TerminalTheme.mono(11, weight: .medium))
            .foregroundStyle(TerminalTheme.danger)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .overlay(Rectangle().stroke(TerminalTheme.line, lineWidth: 1))
            .keyboardShortcut("q")
        }
    }

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    showingSettings = false
                } label: {
                    Text("← back")
                        .font(TerminalTheme.mono(11, weight: .medium))
                        .foregroundStyle(TerminalTheme.accent)
                }
                .buttonStyle(.plain)
                Spacer()
                Text("settings")
                    .font(TerminalTheme.mono(12, weight: .medium))
                    .foregroundStyle(TerminalTheme.fg)
                Spacer()
                Color.clear.frame(width: 48, height: 1)
            }

            SettingsView(settings: appState.settings, appState: appState)
        }
    }

    private func copyToPasteboard(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
        copiedFlash = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            copiedFlash = false
        }
    }
}
