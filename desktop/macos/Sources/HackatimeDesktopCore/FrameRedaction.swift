import CoreGraphics
import Foundation
import ImageIO

/// The regions a user blacks out of a frame before shipping it. Regions are
/// in the frame's pixels with a top-left origin, as reviewers see them.
public enum FrameRedaction {
    public static func decode(_ data: Data) -> CGImage? {
        CGImageSourceCreateWithData(data as CFData, nil).flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) }
    }

    /// The frame with every region filled solid black.
    public static func apply(_ regions: [CGRect], to image: CGImage) -> CGImage? {
        let width = image.width, height = image.height
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        for region in regions {
            // Core Graphics counts y from the bottom.
            context.fill(CGRect(x: region.minX, y: CGFloat(height) - region.maxY, width: region.width, height: region.height))
        }
        return context.makeImage()
    }

    /// A redacted copy as the server accepts it: a JPEG, which it can decode
    /// to check the copy against the frame's committed perceptual hash.
    public static func encode(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.7] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }

    /// Regions as the server stores them (`redactions`: x, y, w, h).
    public static func wire(_ regions: [CGRect]) -> [[String: Int]] {
        regions.map { region in
            let rect = region.integral
            return ["x": Int(rect.minX), "y": Int(rect.minY), "w": Int(rect.width), "h": Int(rect.height)]
        }
    }
}
