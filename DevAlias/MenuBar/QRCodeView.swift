import SwiftUI

struct QRCodeView: View {
    let urlString: String?

    var body: some View {
        Group {
            if let urlString, let image = QRCodeGenerator.image(for: urlString, pixels: 220) {
                Image(nsImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .padding(6)
                    .background(TerminalTheme.bg)
                    .overlay(
                        Rectangle()
                            .stroke(TerminalTheme.line, lineWidth: 1)
                    )
                    .accessibilityLabel("QR code for \(urlString)")
            } else {
                Rectangle()
                    .fill(TerminalTheme.bg)
                    .frame(width: 108, height: 108)
                    .overlay(
                        Rectangle()
                            .stroke(TerminalTheme.line, lineWidth: 1)
                    )
                    .overlay {
                        Text("start hub\nto show qr")
                            .multilineTextAlignment(.center)
                            .font(TerminalTheme.mono(10))
                            .foregroundStyle(TerminalTheme.dim)
                    }
            }
        }
    }
}
