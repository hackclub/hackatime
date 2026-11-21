import AppKit
import ApplicationServices
import CoreGraphics
import HackatimeDesktopCore

/// Focused-window sensor: NSWorkspace for the app, Accessibility for the
/// window title and (for browsers) the URL. Needs the Accessibility
/// permission; without it the app still works with app-level focus only.
@MainActor
final class FocusSensor {
    static var hasAccessibility: Bool { AXIsProcessTrusted() }

    static func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func sample() -> FocusSample? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let bundleID = app.bundleIdentifier ?? ""
        var title = ""
        var url: String?
        if Self.hasAccessibility {
            let element = AXUIElementCreateApplication(app.processIdentifier)
            if let window: AXUIElement = attribute(element, kAXFocusedWindowAttribute) {
                title = attribute(window, kAXTitleAttribute) ?? ""
                url = attribute(window, "AXDocument")
                if url == nil, let web = findWebArea(window, depth: 0) {
                    url = (attribute(web, "AXURL") as URL?)?.absoluteString
                }
            }
        }
        return FocusSample(bundleID: bundleID, appName: app.localizedName ?? bundleID, title: title, url: url)
    }

    private func attribute<T>(_ element: AXUIElement, _ name: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? T
    }

    private func findWebArea(_ element: AXUIElement, depth: Int) -> AXUIElement? {
        guard depth < 6 else { return nil }
        if (attribute(element, kAXRoleAttribute) as String?) == "AXWebArea" { return element }
        for child in (attribute(element, kAXChildrenAttribute) as [AXUIElement]?) ?? [] {
            if let found = findWebArea(child, depth: depth + 1) { return found }
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

    func start() {
        guard tap == nil, Self.hasInputMonitoring else { return }
        let mask: CGEventMask = [CGEventType.keyDown, .leftMouseDown, .rightMouseDown, .mouseMoved, .leftMouseDragged, .scrollWheel]
            .reduce(0) { $0 | (1 << $1.rawValue) }
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .listenOnly, eventsOfInterest: mask,
                                callback: { _, type, event, refcon in
                                    if let refcon { Unmanaged<InputSensor>.fromOpaque(refcon).takeUnretainedValue().handle(type, event) }
                                    return Unmanaged.passUnretained(event)
                                }, userInfo: refcon)
        guard let tap else { return }
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
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
