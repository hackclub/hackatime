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
    /// 30 to 60 KB, so up to about 10 MB per hour of work at three a minute).
    static let maxWidth = 1024
    static let quality = 0.35

    /// Captures the app's focused window: the one the classifier judged,
    /// matched by its Accessibility frame, never another window of the same
    /// app (a banking tab behind a docs window). Without Accessibility it
    /// falls back to the app's frontmost window. Returns nil when the focused
    /// window cannot be found or its title is no longer `expectedTitle`.
    static func captureFocusedWindow(pid: pid_t, expectedTitle: String? = nil) async throws -> CGImage? {
        let focused = focusedWindow(pid: pid)
        if let expectedTitle, let focused, focused.title != expectedTitle { return nil }
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        let order = frontToBackWindowIDs()
        let candidates = content.windows
            .filter { $0.owningApplication?.processID == pid && $0.isOnScreen && $0.windowLayer == 0 && $0.frame.width > 80 }
            .filter { window in focused.map { framesMatch($0.frame, window.frame) } ?? true }
            .sorted { (order[$0.windowID] ?? .max) < (order[$1.windowID] ?? .max) }
        guard let window = candidates.first else { return nil }
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        let scale = min(1, CGFloat(maxWidth) / window.frame.width)
        config.width = Int(window.frame.width * scale)
        config.height = Int(window.frame.height * scale)
        config.showsCursor = false
        config.ignoreShadowsSingleWindow = true
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }

    /// The focused window's frame (top-left origin, like SCWindow.frame) and
    /// title, or nil without Accessibility.
    static func focusedWindow(pid: pid_t) -> (frame: CGRect, title: String)? {
        guard AXIsProcessTrusted() else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(AXUIElementCreateApplication(pid), kAXFocusedWindowAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        let window = value as! AXUIElement
        func read(_ name: String) -> CFTypeRef? {
            var out: CFTypeRef?
            return AXUIElementCopyAttributeValue(window, name as CFString, &out) == .success ? out : nil
        }
        var origin = CGPoint.zero, size = CGSize.zero
        guard let position = read(kAXPositionAttribute), CFGetTypeID(position) == AXValueGetTypeID(),
              AXValueGetValue(position as! AXValue, .cgPoint, &origin),
              let extent = read(kAXSizeAttribute), CFGetTypeID(extent) == AXValueGetTypeID(),
              AXValueGetValue(extent as! AXValue, .cgSize, &size) else { return nil }
        return (CGRect(origin: origin, size: size), read(kAXTitleAttribute) as? String ?? "")
    }

    static func framesMatch(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) <= 2 && abs(a.minY - b.minY) <= 2 && abs(a.width - b.width) <= 2 && abs(a.height - b.height) <= 2
    }

    /// Window IDs ranked front to back, to break ties between windows with
    /// the same frame and for the fallback without Accessibility.
    static func frontToBackWindowIDs() -> [CGWindowID: Int] {
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        var order: [CGWindowID: Int] = [:]
        for (index, info) in list.enumerated() {
            if let number = info[kCGWindowNumber as String] as? CGWindowID, order[number] == nil { order[number] = index }
        }
        return order
    }

    /// Patterns that look like secrets: API keys, tokens, private keys,
    /// credentials in URLs, long base64/hex blobs, emails.
    static let secretPatterns: [NSRegularExpression] = [
        #"(?i)\bbearer\s+\S{10,}"#,
        #"\b(sk|pk|rk)_(live|test)_[A-Za-z0-9]{10,}"#,
        #"\bsk-[A-Za-z0-9_-]{20,}"#,
        #"\b(ghp|gho|ghu|ghs|github_pat)_[A-Za-z0-9_]{20,}"#,
        #"\bxox[abpr]-[A-Za-z0-9-]{10,}"#,
        #"\bAKIA[0-9A-Z]{16}\b"#,
        #"\bAIza[0-9A-Za-z_-]{30,}"#,
        #"(?i)-----BEGIN [A-Z ]*PRIVATE KEY"#,
        #"\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}"#,
        #"\b[A-Fa-f0-9]{32,}\b"#,
        #"://[^/\s:@]+:[^/\s@]+@"#,
        #"[A-Za-z0-9._%+-]+\s?@\s?[A-Za-z0-9-]+(\s?\.\s?[A-Za-z0-9-]+)*\s?\.\s?[A-Za-z]{2,}"#,
    ].compactMap { try? NSRegularExpression(pattern: $0) }

    /// OCR on small text is unreliable (fast mode turns "API_KEY" into
    /// "API KEY _" and "s3cret" into "s3cr3t"), so the secret-ish words are
    /// matched loosely: false positives cost a black bar, false negatives
    /// leak a secret. But the word alone is not enough, or most lines of
    /// code are blacked out (key, auth and token are everywhere): it must be
    /// assigned a value that looks like a secret, a quoted string with more
    /// than letters in it or a run of 6 or more characters with a digit.
    static let looseAssignment = try! NSRegularExpression(pattern:
        #"(?i)(key|tok[e3]n|s[e3]cr[e3]t|pass|pwd|auth|cred|session|cookie)[\w\s"'\]]{0,4}[:=]\s*"#
        + #"(["'][^"']*[^A-Za-z"'][^"']*["']|(?=[^\s()\[\]{},;]{6,})[^\s()\[\]{},;]*\d[^\s()\[\]{},;]*(?=[\s"',;]|$))"#)
    /// `PASSWORD=supersecret` in an env file or shell: an upper-case name
    /// with a secret-ish word, then a value.
    static let envAssignment = try! NSRegularExpression(pattern:
        #"\b[A-Z0-9_]*(KEY|TOK[E3]N|S[E3]CR[E3]T|PASS|PWD|AUTH|CRED|SESSION|COOKIE)[A-Z0-9_]*\s?=\s?[^\s=]{4,}"#)

    static func looksSecret(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        let patterns = secretPatterns + [looseAssignment, envAssignment]
        if patterns.contains(where: { $0.firstMatch(in: text, range: range) != nil }) { return true }
        // Long unbroken runs of letters and digits look like tokens or keys.
        return text.split(whereSeparator: { !($0.isLetter || $0.isNumber || "+/=_-".contains($0)) }).contains { run in
            run.count >= 20 && run.contains(where: \.isNumber) && run.contains(where: \.isLetter)
        }
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

    /// Redacts, fingerprints and encodes a frame off the main thread: text
    /// recognition alone takes about half a second.
    static func prepare(_ image: CGImage) async -> (thumbnail: [UInt8], phash: String, heic: Data)? {
        await Task.detached(priority: .utility) {
            guard let (redacted, _) = redact(image), let heic = encode(redacted) else { return nil }
            let thumbnail = thumbnail(redacted)
            return (thumbnail, perceptualHash(thumbnail), heic)
        }.value
    }

    static func encode(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.heic" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }

    static let thumbnailWidth = 160, thumbnailHeight = 120

    /// A 160 by 120 greyscale copy of a frame, fine enough that a rewritten
    /// line of 13pt code changes many of its pixels.
    static func thumbnail(_ image: CGImage) -> [UInt8] {
        let width = thumbnailWidth, height = thumbnailHeight
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return [] }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = context.data else { return [] }
        return Array(UnsafeBufferPointer(start: data.assumingMemoryBound(to: UInt8.self), count: width * height))
    }

    /// Whether the screen changed between two thumbnails. A blinking caret
    /// or a ticking clock moves a handful of pixels; editing a line moves
    /// dozens, so small changes still read as an unchanged screen.
    static func screenChanged(from old: [UInt8], to new: [UInt8]) -> Bool {
        guard old.count == new.count else { return true }
        return zip(old, new).lazy.filter { abs(Int($0) - Int($1)) > 24 }.count > 8
    }

    /// The `phash` committed for a frame: the thumbnail averaged into an 8 by
    /// 8 grid, one byte of brightness per cell, row by row from the top left,
    /// as 128 hex digits. It is too coarse to read or to notice an edit; the
    /// server uses it to check that a redacted copy is still this frame.
    static func perceptualHash(_ thumbnail: [UInt8]) -> String {
        let grid = 8, cellWidth = thumbnailWidth / grid, cellHeight = thumbnailHeight / grid
        guard thumbnail.count == thumbnailWidth * thumbnailHeight else { return "" }
        return (0 ..< grid * grid).map { cell in
            let left = cell % grid * cellWidth, top = cell / grid * cellHeight
            var sum = 0
            for y in top ..< top + cellHeight {
                for x in left ..< left + cellWidth { sum += Int(thumbnail[y * thumbnailWidth + x]) }
            }
            return String(format: "%02x", sum / (cellWidth * cellHeight))
        }.joined()
    }

    static func perceptualHash(_ image: CGImage) -> String { perceptualHash(thumbnail(image)) }
}
