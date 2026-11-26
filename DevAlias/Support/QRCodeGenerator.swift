import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

enum QRCodeGenerator {
    /// Terminal theme: phosphor modules on near-black (scannable on phone cameras).
    struct TerminalColors {
        /// Module / “black” pixels — keep fairly bright for camera contrast.
        var module: (r: CGFloat, g: CGFloat, b: CGFloat) = (0.72, 0.94, 0.35) // #b7f05a
        /// Background / “white” pixels
        var background: (r: CGFloat, g: CGFloat, b: CGFloat) = (0.05, 0.05, 0.04) // #0c0d0a
    }

    /// Renders a QR code for `string` at roughly `pixels` square.
    static func image(
        for string: String,
        pixels: CGFloat = 256,
        terminal: TerminalColors? = .init()
    ) -> NSImage? {
        guard !string.isEmpty else { return nil }

        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard var output = filter.outputImage else { return nil }

        if let terminal {
            let falseColor = CIFilter.falseColor()
            falseColor.inputImage = output
            falseColor.color0 = CIColor(
                red: terminal.module.r,
                green: terminal.module.g,
                blue: terminal.module.b
            )
            falseColor.color1 = CIColor(
                red: terminal.background.r,
                green: terminal.background.g,
                blue: terminal.background.b
            )
            if let colored = falseColor.outputImage {
                output = colored
            }
        }

        let scale = pixels / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: pixels, height: pixels))
    }
}
