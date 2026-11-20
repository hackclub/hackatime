import AppKit
import CoreImage
import HackatimeDesktopCore
import ScreenCaptureKit
import Vision

/// Captures the focused allowlisted window only, never the whole screen,
/// redacts secrets on device and returns a small HEIC frame. Needs the
/// Screen Recording permission.
enum WindowCapture {
    static var hasPermission: Bool { CGPreflightScreenCaptureAccess() }
    static func requestPermission() { _ = CGRequestScreenCaptureAccess() }

    /// Timelapse frames only need to show what you were working on, so they
    /// are kept small: at most 1024px wide, HEIC at low quality (typically
    /// 30 to 60 KB, about 2 to 3 MB per hour of work).
    static let maxWidth = 1024
    static let quality = 0.35

    static func captureFocusedWindow(pid: pid_t) async throws -> CGImage? {
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        guard let window = content.windows
            .filter({ $0.owningApplication?.processID == pid && $0.isOnScreen && $0.windowLayer == 0 && $0.frame.width > 80 })
            .max(by: { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }) else { return nil }
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        let scale = min(1, CGFloat(maxWidth) / window.frame.width)
        config.width = Int(window.frame.width * scale)
        config.height = Int(window.frame.height * scale)
        config.showsCursor = false
        config.ignoreShadowsSingleWindow = true
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }

    /// Patterns that look like secrets: API keys, tokens, private keys,
    /// passwords in assignments, long base64/hex blobs, emails.
    static let secretPatterns: [NSRegularExpression] = [
        #"(?i)(api[_-]?key|secret|token|passw(or)?d|bearer|authorization)\s*[:=]\s*\S+"#,
        #"\b(sk|pk|rk)_(live|test)_[A-Za-z0-9]{10,}"#,
        #"\b(ghp|gho|ghu|ghs|github_pat)_[A-Za-z0-9_]{20,}"#,
        #"\bxox[abpr]-[A-Za-z0-9-]{10,}"#,
        #"\bAKIA[0-9A-Z]{16}\b"#,
        #"\bAIza[0-9A-Za-z_-]{30,}"#,
        #"-----BEGIN [A-Z ]*PRIVATE KEY-----"#,
        #"\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}"#,
        #"\b[A-Fa-f0-9]{32,}\b"#,
        #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#,
    ].compactMap { try? NSRegularExpression(pattern: $0) }

    /// OCR on small text is unreliable (fast mode turns "API_KEY" into
    /// "API KEY _" and drops "@"), so matching is deliberately loose: false
    /// positives cost a black bar, false negatives leak a secret.
    static let looseMarkers = try! NSRegularExpression(pattern:
        #"(?i)(key|tok[e3]n|s[e3]cr[e3]t|pass|pwd|auth|bearer|api|private|cred|sk[_-]|pk[_-]|ghp|xox|akia|begin|session|cookie)"#)

    static func looksSecret(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        if secretPatterns.contains(where: { $0.firstMatch(in: text, range: range) != nil }) { return true }
        if looseMarkers.firstMatch(in: text, range: range) != nil { return true }
        if text.contains("@") { return true }
        // Long unbroken runs look like tokens, hashes or addresses.
        return text.split(whereSeparator: { $0 == " " || $0 == "\t" }).contains { $0.count >= 20 }
    }

    enum OCRResult {
        case lines([(String, CGRect)])
        case unreadable([CGRect])   // text found but not recognised: redact all of it
    }

    static func recognise(_ image: CGImage) -> OCRResult {
        for level in [VNRequestTextRecognitionLevel.accurate, .fast] {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = level
            request.usesLanguageCorrection = false
            if (try? VNImageRequestHandler(cgImage: image).perform([request])) != nil, let results = request.results {
                return .lines(results.compactMap { observation in
                    observation.topCandidates(1).first.map { ($0.string, observation.boundingBox) }
                })
            }
        }
        let detect = VNDetectTextRectanglesRequest()
        try? VNImageRequestHandler(cgImage: image).perform([detect])
        return .unreadable((detect.results ?? []).map(\.boundingBox))
    }

    /// Blacks out secret-looking text before the frame is encrypted. Fails
    /// closed: text that cannot be read is redacted as a whole, and if even
    /// text detection fails the frame is dropped (nil).
    static func redact(_ image: CGImage, layoutOnly: Bool = false) -> (CGImage, Int)? {
        let boxes: [CGRect]
        switch recognise(image) {
        case .lines(let lines): boxes = lines.filter { layoutOnly || looksSecret($0.0) }.map(\.1)
        case .unreadable(let regions):
            boxes = regions
            if regions.isEmpty { return nil }
        }
        let width = image.width, height = image.height
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        for box in boxes {
            context.fill(CGRect(x: box.minX * CGFloat(width) - 12, y: box.minY * CGFloat(height) - 3,
                                width: box.width * CGFloat(width) + 24, height: box.height * CGFloat(height) + 6))
        }
        return context.makeImage().map { ($0, boxes.count) }
    }

    static func encode(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.heic" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }

    /// 64-bit average hash, used to spot frozen or replayed screens.
    static func perceptualHash(_ image: CGImage) -> String {
        let size = 8
        guard let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size,
                                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return "" }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
        guard let data = context.data else { return "" }
        let pixels = (0 ..< size * size).map { data.load(fromByteOffset: $0, as: UInt8.self) }
        let mean = pixels.reduce(0) { $0 + Int($1) } / pixels.count
        var bits: UInt64 = 0
        for (index, pixel) in pixels.enumerated() where Int(pixel) >= mean { bits |= 1 << UInt64(index) }
        return String(format: "%016llx", bits)
    }
}
