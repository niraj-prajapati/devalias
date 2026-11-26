import SwiftUI

/// Shared terminal palette — matches `dashboard.html`.
enum TerminalTheme {
    static let bg = Color(red: 0.047, green: 0.051, blue: 0.039)       // #0c0d0a
    static let panel = Color(red: 0.071, green: 0.078, blue: 0.059)    // #12140f
    static let line = Color(red: 0.165, green: 0.180, blue: 0.141)     // #2a2e24
    static let fg = Color(red: 0.784, green: 0.831, blue: 0.659)       // #c8d4a8
    static let dim = Color(red: 0.431, green: 0.471, blue: 0.376)      // #6e7860
    static let mute = Color(red: 0.290, green: 0.322, blue: 0.251)     // #4a5240
    static let accent = Color(red: 0.718, green: 0.941, blue: 0.353)   // #b7f05a
    static let accentDim = Color(red: 0.478, green: 0.659, blue: 0.227)// #7aa83a
    static let warn = Color(red: 0.831, green: 0.627, blue: 0.090)     // #d4a017
    static let danger = Color(red: 0.878, green: 0.424, blue: 0.459)   // #e06c75

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

struct TerminalPanel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(TerminalTheme.panel)
            .overlay(
                Rectangle()
                    .stroke(TerminalTheme.line, lineWidth: 1)
            )
    }
}

extension View {
    func terminalPanel() -> some View {
        modifier(TerminalPanel())
    }

    func terminalField() -> some View {
        self
            .textFieldStyle(.plain)
            .font(TerminalTheme.mono(12))
            .foregroundStyle(TerminalTheme.fg)
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(TerminalTheme.bg)
            .overlay(Rectangle().stroke(TerminalTheme.line, lineWidth: 1))
    }

    func terminalGhostButton() -> some View {
        self
            .buttonStyle(.plain)
            .font(TerminalTheme.mono(11, weight: .medium))
            .foregroundStyle(TerminalTheme.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .overlay(Rectangle().stroke(TerminalTheme.line, lineWidth: 1))
    }

    func terminalPrimaryButton() -> some View {
        self
            .buttonStyle(.plain)
            .font(TerminalTheme.mono(12, weight: .medium))
            .foregroundStyle(TerminalTheme.bg)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(TerminalTheme.accent)
    }
}

/// Compact section label + optional help popover.
struct TerminalSectionLabel: View {
    let title: String
    var help: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(TerminalTheme.mono(10))
                .foregroundStyle(TerminalTheme.mute)
            if let help {
                InfoHint(text: help)
            }
        }
    }
}

/// Help affordance — hit target is exactly the icon (not the whole row).
struct InfoHint: View {
    let text: String
    @State private var show = false

    var body: some View {
        Button {
            show.toggle()
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(TerminalTheme.accentDim)
                .frame(width: 16, height: 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .popover(isPresented: $show, arrowEdge: .bottom) {
            Text(text)
                .font(TerminalTheme.mono(11))
                .foregroundStyle(TerminalTheme.fg)
                .padding(12)
                .frame(maxWidth: 260, alignment: .leading)
                .background(TerminalTheme.panel)
        }
        .help("Info")
    }
}

/// Expand/collapse — only the chevron toggles (label text is not a hit target).
struct TerminalDisclosureRow: View {
    let title: String
    @Binding var isExpanded: Bool

    var body: some View {
        HStack(spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(TerminalTheme.mute)
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .fixedSize()
            .help(isExpanded ? "Collapse" : "Expand")

            Text(title)
                .font(TerminalTheme.mono(10))
                .foregroundStyle(TerminalTheme.mute)
                .allowsHitTesting(false)

            Spacer(minLength: 0)
        }
    }
}
