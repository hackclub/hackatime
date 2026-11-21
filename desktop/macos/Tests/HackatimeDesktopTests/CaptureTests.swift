import AppKit
@testable import HackatimeDesktop
import XCTest

/// A 1024 by 700 dark editor showing `lines` of 13pt code, with an optional
/// text caret on one line.
func editorFrame(_ lines: [String], caretLine: Int? = nil) -> CGImage {
    let width = 1024, height = 700
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setFillColor(CGColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
                                                     .foregroundColor: NSColor(white: 0.85, alpha: 1)]
    for (index, line) in lines.enumerated() {
        NSAttributedString(string: line, attributes: attributes).draw(at: NSPoint(x: 60, y: CGFloat(height - 30 - index * 17)))
    }
    if let caretLine {
        context.setFillColor(CGColor(gray: 0.9, alpha: 1))
        context.fill(CGRect(x: 300, y: height - 30 - caretLine * 17, width: 2, height: 16))
    }
    NSGraphicsContext.current = nil
    return context.makeImage()!
}

final class CaptureTests: XCTestCase {
    let code = (0 ..< 38).map { "    let value\($0) = compute(input: items[\($0)], scale: \($0 * 3))" }

    func changed(_ a: CGImage, _ b: CGImage) -> Bool {
        WindowCapture.screenChanged(from: WindowCapture.thumbnail(a), to: WindowCapture.thumbnail(b))
    }

    func testEditingCodeChangesTheScreenButACaretBlinkDoesNot() {
        var oneLine = code
        oneLine[12] = "    guard let user = lookup(id: request.userID) else { return nil }"
        XCTAssertTrue(changed(editorFrame(code), editorFrame(oneLine)), "rewriting one line")

        let short = Array(code.prefix(20))
        XCTAssertTrue(changed(editorFrame(short), editorFrame(short + ["    return total"])), "typing a new line")

        XCTAssertFalse(changed(editorFrame(code), editorFrame(code, caretLine: 12)), "a caret blink")
        XCTAssertFalse(changed(editorFrame(code), editorFrame(code)))
        XCTAssertNotEqual(WindowCapture.perceptualHash(editorFrame(code)), WindowCapture.perceptualHash(editorFrame(oneLine)))
    }
}
