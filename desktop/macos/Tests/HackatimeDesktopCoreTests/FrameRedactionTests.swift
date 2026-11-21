import CoreGraphics
import XCTest
@testable import HackatimeDesktopCore

final class FrameRedactionTests: XCTestCase {
    func testRegionsAreBlackedOutFromTheTopLeft() throws {
        let width = 40, height = 20
        let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let white = try XCTUnwrap(context.makeImage())

        // A box in the top-left corner, as the user drew it on screen.
        let region = CGRect(x: 2, y: 1, width: 10, height: 5)
        let redacted = try XCTUnwrap(FrameRedaction.apply([region], to: white))

        let out = try XCTUnwrap(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        out.draw(redacted, in: CGRect(x: 0, y: 0, width: width, height: height))
        let pixels = try XCTUnwrap(out.data).assumingMemoryBound(to: UInt8.self)
        // The bitmap's first row is the top of the image.
        func red(x: Int, y: Int) -> UInt8 { pixels[(y * width + x) * 4] }
        XCTAssertEqual(red(x: 5, y: 3), 0, "inside the box, near the top")
        XCTAssertEqual(red(x: 5, y: 16), 255, "the same column near the bottom stays")
        XCTAssertEqual(red(x: 20, y: 3), 255, "right of the box stays")

        let jpeg = try XCTUnwrap(FrameRedaction.encode(redacted))
        XCTAssertEqual(Array(jpeg.prefix(3)), [0xFF, 0xD8, 0xFF], "the server decodes JPEG, not HEIC")
        XCTAssertEqual(FrameRedaction.decode(jpeg)?.width, width)

        XCTAssertEqual(FrameRedaction.wire([CGRect(x: 2.4, y: 1.6, width: 9.2, height: 4.1)]), [["x": 2, "y": 1, "w": 10, "h": 5]])
    }
}
