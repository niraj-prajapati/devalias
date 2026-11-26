import SwiftUI

struct ServerStatusHeader: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text("devalias")
                    .font(TerminalTheme.mono(13, weight: .medium))
                    .foregroundStyle(TerminalTheme.accent)
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    Text(liveLabel)
                        .font(TerminalTheme.mono(11))
                        .foregroundStyle(TerminalTheme.dim)
                        .lineLimit(1)
                }
            }

            if let error = appState.lastError, appState.runState == .error {
                Text(error)
                    .font(TerminalTheme.mono(11))
                    .foregroundStyle(TerminalTheme.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                if appState.runState == .running || appState.runState == .starting {
                    appState.stopHub()
                } else {
                    appState.startHub()
                }
            } label: {
                Text(primaryActionTitle)
                    .font(TerminalTheme.mono(12, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .foregroundStyle(TerminalTheme.bg)
                    .background(TerminalTheme.accent)
            }
            .buttonStyle(.plain)
            .disabled(appState.runState == .starting || appState.runState == .stopping)
            .keyboardShortcut(.defaultAction)
            .opacity(appState.runState == .starting || appState.runState == .stopping ? 0.5 : 1)
        }
    }

    private var primaryActionTitle: String {
        switch appState.runState {
        case .running, .starting: return "stop hub"
        case .stopping: return "stopping…"
        case .stopped, .error: return "start hub"
        }
    }

    private var liveLabel: String {
        switch appState.runState {
        case .running: return appState.mdnsPublished ? "live · mdns" : "live"
        case .starting: return "starting"
        case .stopping: return "stopping"
        case .stopped: return "idle"
        case .error: return "error"
        }
    }

    private var statusColor: Color {
        switch appState.runState {
        case .stopped: return TerminalTheme.mute
        case .starting, .stopping: return TerminalTheme.warn
        case .running: return TerminalTheme.accent
        case .error: return TerminalTheme.danger
        }
    }
}
