import SwiftUI

struct DiscoveredServerRow: View {
    let server: DiscoveredServer

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(verbatim: ":\(server.port)")
                .font(TerminalTheme.mono(13, weight: .medium))
                .foregroundStyle(TerminalTheme.accent)
                .frame(width: 56, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(server.projectName.isEmpty ? server.processName : server.projectName)
                    .font(TerminalTheme.mono(12, weight: .medium))
                    .foregroundStyle(TerminalTheme.fg)
                    .lineLimit(1)
                Text(server.processName)
                    .font(TerminalTheme.mono(10))
                    .foregroundStyle(TerminalTheme.dim)
                    .lineLimit(1)
                if server.accessibility.showsBindWarning {
                    Text("localhost only — phone cannot reach")
                        .font(TerminalTheme.mono(10))
                        .foregroundStyle(TerminalTheme.warn)
                }
            }

            Spacer(minLength: 0)

            Text(server.stack.rawValue)
                .font(TerminalTheme.mono(10))
                .foregroundStyle(TerminalTheme.mute)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TerminalTheme.bg.opacity(0.35))
    }
}
