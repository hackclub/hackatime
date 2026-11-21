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

    func testRedactionCatchesSecretsButNotOrdinaryCode() {
        let secrets = [
            "API_KEY=sk_live_51HxQe2K8ZpL0vR9mN3", "API KEY _ = 8f3k29dk20fk30fk20", "password: hunter2", "PASSWORD=supersecret",
            #"DB_PASSWORD="correct horse battery staple""#, #""client_secret": "d1f9e8a7b6c5""#, "tok3n: a1b2c3d4e5f6g7h8",
            "export GITHUB_TOKEN=ghp_1a2B3c4D5e6F7g8H9i0JkLmNoPqRsTuVwXyZ", "OPENAI_API_KEY=sk-proj-Ab3dE5gH7jK9mN1pQ3sT5vX7z",
            "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0In0.abc", "-----BEGIN RSA PRIVATE KEY-----",
            "MIIEowIBAAKCAQEAu1SU1LfVLPHCozMxH2Mo4lgOEePzNm0tRgeLezV6ffAt0gun", "contact mahad @ hackclub.com",
            "DATABASE_URL=postgres://user:p4ssw0rd@db.example.com/app",
        ]
        for line in secrets { XCTAssertTrue(WindowCapture.looksSecret(line), line) }
        let code = [
            "let key = try? DeviceKey.loadOrCreate(store: store)", "api.token = token", "private func enrolKey() async {",
            "@MainActor final class Agent: ObservableObject {", "guard let key, !settings.keyEnrolled, let uid = settings.deviceUID else { return }",
            "body[\"public_key\"] = key.publicKeyDER.base64EncodedString()", "let session: URLSession", "payload.keys = inputs.keys",
        ]
        for line in code { XCTAssertFalse(WindowCapture.looksSecret(line), line) }
    }
}
