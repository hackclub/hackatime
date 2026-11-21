import AppKit
import HackatimeDesktopCore
import WebKit

/// The app's window: the companion site in a WKWebView under a transparent,
/// full-size titlebar whose frame takes the page's colour. Pairing happens
/// inside it: the site posts the code here instead of opening a deep link.
/// Closing it leaves tracking running in the menu bar.
@MainActor
final class MainWindowController: NSObject, NSWindowDelegate, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    let agent: Agent
    var onChange: () -> Void = {}
    private var window: NSWindow?
    private var webView: WKWebView!
    private let toasts = NativeToastCenter.shared
    static let titlebarHeight: CGFloat = 32

    init(agent: Agent) { self.agent = agent }

    var isVisible: Bool { window?.isVisible == true }

    /// Brings the window forward, loading `url` or, the first time, the site.
    func show(_ url: URL? = nil) {
        let fresh = window == nil
        if fresh { makeWindow() }
        if let url { webView.load(URLRequest(url: url)) } else if fresh { webView.load(URLRequest(url: agent.settings.site)) }
        NSApp.setActivationPolicy(.regular)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        toasts.host = window
    }

    /// The site's pairing page with a fresh challenge from this process.
    func startPairing() { show(agent.beginPairing()) }

    func pair(code: String) async {
        toasts.show("Pairing this Mac…", style: .loading, id: "pair")
        if let error = await agent.completePairing(code: code) {
            toasts.show("Couldn't pair this Mac", detail: error, style: .error, id: "pair")
            send(["type": "pairFailed", "error": error])
        } else {
            toasts.show("This Mac is paired", detail: "Tracking runs from the menu bar, even with this window closed.",
                        style: .success, id: "pair")
            publishState()
            if window != nil { webView.load(URLRequest(url: agent.settings.site)) }
        }
        onChange()
    }

    /// Tells the page what changed on this side (paired, paused).
    func publishState() {
        guard let webView else { return }
        let controller = webView.configuration.userContentController
        controller.removeAllUserScripts()
        controller.addUserScript(stateScript())
        guard webView.url.map(isSite) == true else { return }
        webView.evaluateJavaScript("window.hackatimeDesktop = \(stateJSON()); window.dispatchEvent(new Event('hackatime-native'))")
    }

    private func makeWindow() {
        let config = WKWebViewConfiguration()
        config.applicationNameForUserAgent = "HackatimeDesktop/\(APIClient.version)"
        config.userContentController.add(self, name: "hackatime")
        config.userContentController.addUserScript(stateScript())
        if #available(macOS 15, *) { config.writingToolsBehavior = .none }

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = false
        webView.setValue(false, forKey: "drawsBackground")
        #if DEBUG
        webView.isInspectable = true
        #endif

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1120, height: 760),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.title = "Hackatime Desktop"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.tabbingMode = .disallowed
        window.minSize = NSSize(width: 760, height: 540)
        window.isReleasedWhenClosed = false
        window.delegate = self
        applyTheme(background: UserDefaults.standard.string(forKey: "windowBackground") ?? "#050505",
                   scheme: UserDefaults.standard.string(forKey: "windowScheme") ?? "dark", to: window)

        let container = NSView(frame: window.contentLayoutRect)
        webView.frame = container.bounds
        webView.autoresizingMask = [.width, .height]
        container.addSubview(webView)
        // WKWebView swallows clicks under a transparent titlebar, so a strip
        // over it moves the window. The site leaves that band empty.
        let strip = TitlebarDragView(frame: NSRect(x: 0, y: container.bounds.height - Self.titlebarHeight,
                                                   width: container.bounds.width, height: Self.titlebarHeight))
        strip.autoresizingMask = [.width, .minYMargin]
        container.addSubview(strip)
        window.contentView = container
        window.center()
        window.setFrameAutosaveName("Main")
        self.window = window
    }

    // MARK: Page → app

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, isSite(message.frameInfo.securityOrigin),
              let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        switch type {
        case "toast":
            guard let title = body["title"] as? String, !title.isEmpty else { return }
            toasts.show(title, detail: body["detail"] as? String,
                        style: NativeToast.Style(rawValue: body["style"] as? String ?? "") ?? .info,
                        id: body["id"] as? String ?? UUID().uuidString)
        case "pair":
            if let code = body["code"] as? String { Task { await pair(code: code) } }
        case "startPairing":
            webView.load(URLRequest(url: agent.beginPairing()))
        case "theme":
            if let window, let background = body["background"] as? String {
                let scheme = body["scheme"] as? String ?? "dark"
                UserDefaults.standard.set(background, forKey: "windowBackground")
                UserDefaults.standard.set(scheme, forKey: "windowScheme")
                applyTheme(background: background, scheme: scheme, to: window)
            }
        default:
            break
        }
    }

    private func send(_ event: [String: Any]) {
        guard let webView, webView.url.map(isSite) == true, let data = try? JSONSerialization.data(withJSONObject: event) else { return }
        webView.evaluateJavaScript("window.dispatchEvent(new CustomEvent('hackatime-native', { detail: \(String(decoding: data, as: UTF8.self)) }))")
    }

    private func stateJSON() -> String {
        let state: [String: Any] = ["paired": agent.isPaired, "paused": agent.settings.paused,
                                    "version": APIClient.version, "device": Host.current().localizedName ?? "Mac"]
        return (try? JSONSerialization.data(withJSONObject: state)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
    }

    private func stateScript() -> WKUserScript { Self.stateScript(stateJSON(), site: agent.settings.site) }

    /// The state, including this Mac's name, is only for the companion site:
    /// the window also loads Hackatime's sign-in pages and whatever they
    /// redirect to, so the script checks the page's origin before setting it.
    static func stateScript(_ json: String, site: URL) -> WKUserScript {
        let origin = (try? JSONSerialization.data(withJSONObject: origin(of: site), options: .fragmentsAllowed))
            .map { String(decoding: $0, as: UTF8.self) } ?? "null"
        return WKUserScript(source: "if (location.origin === \(origin)) { window.hackatimeDesktop = \(json); }",
                            injectionTime: .atDocumentStart, forMainFrameOnly: true)
    }

    /// What `location.origin` reads on `url`'s pages (no default port).
    static func origin(of url: URL) -> String {
        let scheme = url.scheme?.lowercased() ?? ""
        let port = url.port.flatMap { (scheme == "https" && $0 == 443) || (scheme == "http" && $0 == 80) ? nil : $0 }
        return "\(scheme)://\(url.host?.lowercased() ?? "")" + (port.map { ":\($0)" } ?? "")
    }

    private func applyTheme(background: String, scheme: String, to window: NSWindow) {
        if let color = NSColor(hex: background) { window.backgroundColor = color }
        window.appearance = NSAppearance(named: scheme == "light" ? .aqua : .darkAqua)
    }

    // MARK: Navigation

    private func isSite(_ origin: WKSecurityOrigin) -> Bool {
        var parts = URLComponents()
        parts.scheme = origin.protocol
        parts.host = origin.host
        parts.port = origin.port == 0 ? nil : origin.port
        return parts.url.map(isSite) == true
    }

    private func isSite(_ url: URL) -> Bool { Self.origin(of: url) == Self.origin(of: agent.settings.site) }

    /// The site and Hackatime (for signing in) stay in the window.
    private func belongsInWindow(_ url: URL) -> Bool {
        isSite(url) || URL(string: agent.settings.baseURL).map { Self.origin(of: $0) == Self.origin(of: url) } == true
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let url = action.request.url else { return .cancel }
        if url.scheme == "hackatime-desktop" {
            if let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "code" })?.value {
                Task { await pair(code: code) }
            }
            return .cancel
        }
        if !["http", "https", "about", "blob", "data"].contains(url.scheme ?? "") ||
            (action.navigationType == .linkActivated && action.targetFrame?.isMainFrame == true && !belongsInWindow(url)) {
            NSWorkspace.shared.open(url)
            return .cancel
        }
        return .allow
    }

    /// target=_blank links open in the browser.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = action.request.url { NSWorkspace.shared.open(url) }
        return nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        toasts.show("Can't reach Hackatime Desktop", detail: error.localizedDescription, style: .error, id: "offline",
                    action: .init(label: "Try again") { [weak self] in
                        guard let self else { return }
                        self.webView.load(URLRequest(url: self.webView.url ?? self.agent.settings.site))
                    })
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { toasts.dismiss("offline") }

    /// The site leaves room for the traffic lights; Hackatime's sign-in pages
    /// don't, so they sit below the titlebar instead of under it.
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        guard let container = webView.superview, let url = webView.url else { return }
        let inset = isSite(url) ? 0 : Self.titlebarHeight
        webView.frame = NSRect(x: 0, y: 0, width: container.bounds.width, height: container.bounds.height - inset)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { webView.reload() }

    // MARK: Window

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        // After the close finishes, or the toasts leave with the window.
        DispatchQueue.main.async { [self] in
            toasts.host = nil
            guard !UserDefaults.standard.bool(forKey: "toldAboutMenuBar") else { return }
            UserDefaults.standard.set(true, forKey: "toldAboutMenuBar")
            toasts.show("Still tracking", detail: "Hackatime Desktop keeps running in the menu bar.", style: .info)
        }
    }

    func windowDidResize(_ notification: Notification) { toasts.host = window }
    func windowDidDeminiaturize(_ notification: Notification) { toasts.host = window }
    func windowDidMiniaturize(_ notification: Notification) { toasts.host = nil }
}

/// Drags the window, and double-click zooms or minimises as System Settings says.
final class TitlebarDragView: NSView {
    override func mouseDown(with event: NSEvent) {
        guard event.clickCount == 2 else { window?.performDrag(with: event); return }
        switch UserDefaults.standard.string(forKey: "AppleActionOnDoubleClick") {
        case "Minimize": window?.performMiniaturize(nil)
        case "None": break
        default: window?.performZoom(nil)
        }
    }
}

extension NSColor {
    convenience init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespaces)
        guard value.hasPrefix("#") else { return nil }
        value.removeFirst()
        if value.count == 3 { value = value.map { "\($0)\($0)" }.joined() }
        guard value.count == 6, let rgb = UInt32(value, radix: 16) else { return nil }
        self.init(srgbRed: CGFloat(rgb >> 16 & 0xFF) / 255, green: CGFloat(rgb >> 8 & 0xFF) / 255, blue: CGFloat(rgb & 0xFF) / 255, alpha: 1)
    }
}
