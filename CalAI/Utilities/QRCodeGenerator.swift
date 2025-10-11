import UIKit
import CoreImage.CIFilterBuiltins

/// Utility for generating QR codes
class QRCodeGenerator {

    /// Generate a QR code image from a string
    /// - Parameters:
    ///   - string: The content to encode in the QR code
    ///   - size: The desired size of the QR code image (default: 512x512)
    /// - Returns: UIImage of the QR code, or nil if generation fails
    static func generateQRCode(from string: String, size: CGSize = CGSize(width: 512, height: 512)) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()

        guard let data = string.data(using: .utf8) else {
            print("❌ Failed to convert string to data for QR code")
            return nil
        }

        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel") // High error correction

        guard let outputImage = filter.outputImage else {
            print("❌ Failed to generate QR code output image")
            return nil
        }

        // Scale the QR code to desired size
        let scaleX = size.width / outputImage.extent.size.width
        let scaleY = size.height / outputImage.extent.size.height
        let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        guard let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) else {
            print("❌ Failed to create CGImage from QR code")
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    /// Generate a QR code with a logo overlay in the center
    /// - Parameters:
    ///   - string: The content to encode in the QR code
    ///   - logo: The logo image to overlay
    ///   - size: The desired size of the QR code image
    ///   - logoSize: The size of the logo (default: 20% of QR code size)
    /// - Returns: UIImage of the QR code with logo, or nil if generation fails
    static func generateQRCode(
        from string: String,
        withLogo logo: UIImage,
        size: CGSize = CGSize(width: 512, height: 512),
        logoSize: CGSize? = nil
    ) -> UIImage? {
        guard let qrCode = generateQRCode(from: string, size: size) else {
            return nil
        }

        let actualLogoSize = logoSize ?? CGSize(width: size.width * 0.2, height: size.height * 0.2)

        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }

        // Draw QR code
        qrCode.draw(in: CGRect(origin: .zero, size: size))

        // Draw logo in center with white background
        let logoOrigin = CGPoint(
            x: (size.width - actualLogoSize.width) / 2,
            y: (size.height - actualLogoSize.height) / 2
        )
        let logoRect = CGRect(origin: logoOrigin, size: actualLogoSize)

        // White background for logo
        UIColor.white.setFill()
        let backgroundRect = logoRect.insetBy(dx: -8, dy: -8)
        UIBezierPath(roundedRect: backgroundRect, cornerRadius: 8).fill()

        // Draw logo
        logo.draw(in: logoRect)

        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
