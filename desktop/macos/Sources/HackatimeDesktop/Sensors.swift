import AppKit
import ApplicationServices
import CoreGraphics
import HackatimeDesktopCore

/// Focused-window sensor: NSWorkspace for the app, Accessibility for the
/// window title and (for browsers) the URL. Needs the Accessibility
/// permission; without it the app still works with app-level focus only.
/// Holds no state, so it is safe to use from any thread.
final class FocusSensor: Sendable {
    static var hasAccessibility: Bool { AXIsProcessTrusted() }

    static func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Samples off the main thread. Accessibility calls wait on the focused
    /// app, which walking a browser's tree makes slow and a hung app makes
    /// take seconds.
    func sampleInBackground() async -> (FocusSample, pid_t)? {
        await Task.detached(priority: .utility) { self.sampleWithPID() }.value
    }

    func sample() -> FocusSample? { sampleWithPID()?.0 }

    /// System helpers that take the front for a moment (permission prompts,
    /// the Dock, the login window). They are nobody's activity.
    static let systemBundleIDs: Set<String> = [
        "com.apple.loginwindow", "com.apple.screensaver.engine", "com.apple.usernotificationcenter", "com.apple.coreservices.uiagent",
        "com.apple.securityagent", "com.apple.systemuiserver", "com.apple.dock", "com.apple.unmountassistantagent",
        "com.apple.frameworks.diskimages.uiagent", "com.apple.netauthagent", "com.apple.followupui",
    ]

    /// How long one Accessibility call may wait on the focused app. A hung
    /// app would otherwise hold each call for seconds.
    static let messagingTimeout: Float = 0.35

    /// The sample and the process it came from.
    func sampleWithPID() -> (FocusSample, pid_t)? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let bundleID = app.bundleIdentifier ?? ""
        guard !Self.systemBundleIDs.contains(bundleID.lowercased()) else { return nil }
        var title = ""
        var url: String?
        if Self.hasAccessibility {
            let element = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(element, Self.messagingTimeout)
            // An app with no key window (a palette or sheet has focus) still has a main one.
            if let window: AXUIElement = attribute(element, kAXFocusedWindowAttribute) ?? attribute(element, kAXMainWindowAttribute) {
                title = attribute(window, kAXTitleAttribute) ?? ""
                url = attribute(window, kAXDocumentAttribute)
                // Safari names the page in AXDocument; Chromium browsers only
                // in a web area deep in the window. Other apps get a shallow
                // look, enough to find a web view showing a never-listed site.
                let browser = FocusClassifier.isBrowser(bundleID)
                if url == nil, let web = findWebArea(window, maxNodes: browser ? 600 : 150, maxDepth: browser ? 14 : 6) {
                    url = (attribute(web, kAXURLAttribute) as URL?)?.absoluteString
                    if title.isEmpty { title = attribute(web, kAXTitleAttribute) ?? "" }
                }
            }
        }
        return (FocusSample(bundleID: bundleID, appName: app.localizedName ?? bundleID, title: title, url: url), app.processIdentifier)
    }

    private func attribute<T>(_ element: AXUIElement, _ name: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? T
    }

    /// Breadth first, so a web area near the top is found before the node
    /// budget runs out in a wide toolbar.
    private func findWebArea(_ root: AXUIElement, maxNodes: Int, maxDepth: Int) -> AXUIElement? {
        var queue: [(AXUIElement, Int)] = [(root, 0)]
        var index = 0
        while index < queue.count, index < maxNodes {
            let (element, depth) = queue[index]
            index += 1
            if (attribute(element, kAXRoleAttribute) as String?) == "AXWebArea" { return element }
            if depth < maxDepth {
                queue.append(contentsOf: ((attribute(element, kAXChildrenAttribute) as [AXUIElement]?) ?? []).map { ($0, depth + 1) })
            }
        }
        return nil
    }
}

/// Listen-only event tap that counts input and records where it came from.
/// No key codes or characters are read. Events posted by another process
/// carry that process's PID in `eventSourceUnixProcessID`; hardware events
/// carry 0. Needs the Input Monitoring permission; without it, input scores
/// are simply absent (never a penalty on their own).
final class InputSensor {
    private var tap: CFMachPort?
    private let lock = NSLock()
    private var minute = InputMinute()
    private let ownPID = getpid()

    static var hasInputMonitoring: Bool { CGPreflightListenEventAccess() }
    static func requestInputMonitoring() { _ = CGRequestListenEventAccess() }

    /// Starts the tap if it is not running and the permission is granted,
    /// and returns whether it is running. Called every minute, so granting
    /// the permission later takes effect without a restart.
    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        guard Self.hasInputMonitoring else { return false }
        let mask: CGEventMask = [CGEventType.keyDown, .leftMouseDown, .rightMouseDown, .mouseMoved, .leftMouseDragged, .scrollWheel]
            .reduce(0) { $0 | (1 << $1.rawValue) }
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .listenOnly, eventsOfInterest: mask,
                                callback: { _, type, event, refcon in
                                    if let refcon { Unmanaged<InputSensor>.fromOpaque(refcon).takeUnretainedValue().handle(type, event) }
                                    return Unmanaged.passUnretained(event)
                                }, userInfo: refcon)
        guard let tap else { return false }
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        let sourcePID = event.getIntegerValueField(.eventSourceUnixProcessID)
        let stateID = event.getIntegerValueField(.eventSourceStateID)
        let injected = (sourcePID != 0 && sourcePID != Int64(ownPID)) || stateID == Int64(CGEventSourceStateID.privateState.rawValue)
        let now = ProcessInfo.processInfo.systemUptime
        lock.lock(); defer { lock.unlock() }
        switch type {
        case .keyDown: minute.recordKey(at: now, injected: injected)
        case .leftMouseDown, .rightMouseDown: minute.recordClick(injected: injected)
        default:
            let location = event.location
            minute.recordMove(x: location.x, y: location.y, at: now, injected: injected)
        }
    }

    /// Returns this minute's counts and starts a new one.
    func takeMinute() -> InputMinute {
        lock.lock(); defer { lock.unlock() }
        let taken = minute
        minute = InputMinute()
        return taken
    }

    /// Seconds since any input, from the window server (no permission needed).
    static var idleSeconds: Double {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
    }
}
