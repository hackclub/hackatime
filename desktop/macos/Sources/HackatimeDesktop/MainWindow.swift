import AppKit
import AuthenticationServices
import HackatimeDesktopCore
import Network
import SwiftUI
import WebKit

/// The app's window: the companion site in a WKWebView over a native window
/// material, under a unified toolbar-sized titlebar. Before the page loads,
/// the app tells it where the traffic lights are; the site then draws its own
/// toolbar row beside them and a translucent sidebar (MacShell.svelte).
/// Pairing and sign-in happen here too: the site posts pairing codes to the
/// app, and Hackatime's sign-in runs in the system sheet. Closing the window
/// leaves tracking running in the menu bar.
@MainActor
final class MainWindowController: NSObject, NSWindowDelegate, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler,
    ASWebAuthenticationPresentationContextProviding {
    let agent: Agent
    var onChange: () -> Void = {}
    private var window: NSWindow?
    private var webView: HackatimeWebView!
    private var overlayView: NSView!
    private let overlay = WindowOverlayModel()
    private let toasts = NativeToastCenter.shared
    private var lastMouseDown: NSEvent?
    private var observations: [NSKeyValueObservation] = []
    private let network = NWPathMonitor()
    private var authSession: ASWebAuthenticationSession?
    /// The last site page the window asked for, to retry or return to.
    private var lastSiteURL: URL?
    private var revealFallback: Task<Void, Never>?

    init(agent: Agent) {
        self.agent = agent
        super.init()
        NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            MainActor.assumeIsolated { self?.lastMouseDown = event }
            return event
        }
        network.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { @MainActor in
                guard let self, case .offline = self.overlay.state else { return }
                self.retry()
            }
        }
        network.start(queue: .main)
    }

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
        updateChrome()
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

    /// Tells the page what changed on this side (paired, paused, history).
    func publishState() {
        guard let webView else { return }
        refreshUserScript()
        guard webView.url.map(isSite) == true else { return }
        webView.evaluateJavaScript("window.hackatimeDesktop = \(stateJSON()); window.dispatchEvent(new Event('hackatime-native'))")
    }

    // MARK: Menu commands

    @objc func goBack(_ sender: Any?) { webView?.goBack() }
    @objc func goForward(_ sender: Any?) { webView?.goForward() }
    @objc func reloadPage(_ sender: Any?) { webView?.reload() }
    @objc func toggleSidebar(_ sender: Any?) { send(["type": "command", "name": "toggleSidebar"]) }
    @objc func zoomIn(_ sender: Any?) { setZoom((webView?.pageZoom ?? 1) + 0.1) }
    @objc func zoomOut(_ sender: Any?) { setZoom((webView?.pageZoom ?? 1) - 0.1) }
    @objc func actualSize(_ sender: Any?) { setZoom(1) }

    private func setZoom(_ zoom: CGFloat) {
        let clamped = min(2, max(0.6, (zoom * 10).rounded() / 10))
        webView?.pageZoom = clamped
        UserDefaults.standard.set(clamped, forKey: "pageZoom")
    }

    // MARK: Window

    private func makeWindow() {
        let config = WKWebViewConfiguration()
        config.applicationNameForUserAgent = "HackatimeDesktop/\(APIClient.version)"
        config.userContentController.add(self, name: "hackatime")
        if #available(macOS 15, *) { config.writingToolsBehavior = .none }

        webView = HackatimeWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = false
        webView.setValue(false, forKey: "drawsBackground")
        let zoom = UserDefaults.standard.double(forKey: "pageZoom")
        if zoom > 0 { webView.pageZoom = zoom }
        #if DEBUG
        webView.isInspectable = true
        #else
        webView.isInspectable = UserDefaults.standard.bool(forKey: "WebInspector")
        #endif
        observations = [
            webView.observe(\.canGoBack) { [weak self] _, _ in Task { @MainActor in self?.publishState() } },
            webView.observe(\.canGoForward) { [weak self] _, _ in Task { @MainActor in self?.publishState() } },
        ]

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1120, height: 760),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.title = "Hackatime Desktop"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        // An empty unified toolbar gives the titlebar a toolbar's height and
        // toolbar-sized traffic lights; the site draws the controls in it.
        window.toolbar = NSToolbar(identifier: "HackatimeDesktop")
        window.toolbarStyle = .unifiedCompact
        window.titlebarSeparatorStyle = .none
        window.tabbingMode = .disallowed
        window.minSize = NSSize(width: 760, height: 540)
        window.isReleasedWhenClosed = false
        window.delegate = self
        applyAppearance(scheme: UserDefaults.standard.string(forKey: "windowScheme") ?? "dark", to: window)

        // The material shows through the page's transparent background.
        let material = NSVisualEffectView(frame: window.contentLayoutRect)
        material.material = .sidebar
        material.blendingMode = .behindWindow
        material.state = .followsWindowActiveState
        webView.frame = material.bounds
        webView.autoresizingMask = [.width, .height]
        webView.alphaValue = 0
        material.addSubview(webView)

        overlay.background = NSColor(hex: UserDefaults.standard.string(forKey: "windowBackground") ?? "") ?? .black
        overlayView = NSHostingView(rootView: WindowOverlay(model: overlay, retry: { [weak self] in self?.retry() },
                                                            signIn: { [weak self] in self?.retry() }))
        overlayView.frame = material.bounds
        overlayView.autoresizingMask = [.width, .height]
        material.addSubview(overlayView)

        window.contentView = material
        window.center()
        window.setFrameAutosaveName("Main")
        self.window = window
        refreshUserScript()
    }

    /// Shows a native state over the page, or reveals the page.
    private func setOverlay(_ state: WindowOverlayModel.State) {
        overlay.state = state
        let covered = state != .hidden
        if covered { overlayView.isHidden = false }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            webView.animator().alphaValue = covered ? 0 : 1
            overlayView.animator().alphaValue = covered ? 1 : 0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                if self?.overlay.state == .hidden { self?.overlayView.isHidden = true }
            }
        }
    }

    private func retry() {
        setOverlay(.loading)
        webView.load(URLRequest(url: lastSiteURL ?? agent.settings.site))
    }

    // MARK: Page ↔ app

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, isSite(message.frameInfo.securityOrigin),
              let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        switch type {
        case "ready":
            revealFallback?.cancel()
            if overlay.state == .loading { setOverlay(.hidden) }
        case "windowDrag":
            dragWindow(clicks: body["clicks"] as? Int ?? 1)
        case "navigate":
            if body["to"] as? String == "back" { webView.goBack() } else { webView.goForward() }
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
                overlay.background = NSColor(hex: background) ?? overlay.background
                applyAppearance(scheme: scheme, to: window)
            }
        default:
            break
        }
    }

    /// The page decides what counts as titlebar (data-drag in MacShell); the
    /// app does the drag with the mouse-down that started it.
    private func dragWindow(clicks: Int) {
        guard let window, let event = lastMouseDown, event.window === window,
              ProcessInfo.processInfo.systemUptime - event.timestamp < 1 else { return }
        if clicks >= 2 {
            switch UserDefaults.standard.string(forKey: "AppleActionOnDoubleClick") {
            case "Minimize": window.performMiniaturize(nil)
            case "None": break
            default: window.performZoom(nil)
            }
        } else if NSEvent.pressedMouseButtons & 1 == 1 {
            window.performDrag(with: event)
        }
    }

    private func send(_ event: [String: Any]) {
        guard let webView, webView.url.map(isSite) == true, let data = try? JSONSerialization.data(withJSONObject: event) else { return }
        webView.evaluateJavaScript("window.dispatchEvent(new CustomEvent('hackatime-native', { detail: \(String(decoding: data, as: UTF8.self)) }))")
    }

    private func stateJSON() -> String {
        let state: [String: Any] = ["paired": agent.isPaired, "paused": agent.settings.paused,
                                    "version": APIClient.version, "device": Host.current().localizedName ?? "Mac",
                                    "canGoBack": webView?.canGoBack ?? false, "canGoForward": webView?.canGoForward ?? false]
        return (try? JSONSerialization.data(withJSONObject: state)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
    }

    /// The state, including this Mac's name, is only for the companion site:
    /// the window also loads Hackatime's sign-in pages and whatever they
    /// redirect to, so the script checks the page's origin before setting it.
    static func stateScript(_ json: String, chrome: String = "", site: URL) -> WKUserScript {
        let origin = (try? JSONSerialization.data(withJSONObject: origin(of: site), options: .fragmentsAllowed))
            .map { String(decoding: $0, as: UTF8.self) } ?? "null"
        return WKUserScript(source: "if (location.origin === \(origin)) { window.hackatimeDesktop = \(json);\n\(chrome) }",
                            injectionTime: .atDocumentStart, forMainFrameOnly: true)
    }

    /// What `location.origin` reads on `url`'s pages (no default port).
    static func origin(of url: URL) -> String {
        let scheme = url.scheme?.lowercased() ?? ""
        let port = url.port.flatMap { (scheme == "https" && $0 == 443) || (scheme == "http" && $0 == 80) ? nil : $0 }
        return "\(scheme)://\(url.host?.lowercased() ?? "")" + (port.map { ":\($0)" } ?? "")
    }

    /// Where the traffic lights are and how tall the titlebar is, as CSS
    /// variables on <html>, plus the flag that the page sits on a material.
    private func chromeJS() -> String {
        guard let window else { return "" }
        let fullScreen = window.styleMask.contains(.fullScreen)
        let titlebar = fullScreen ? 38 : Int((window.frame.height - window.contentLayoutRect.height).rounded())
        let inset = fullScreen ? 12 : Int(((window.standardWindowButton(.zoomButton)?.frame.maxX ?? 70) + 14).rounded())
        return """
        (() => { const html = document.documentElement; html.dataset.nativeMaterial = '1';
        html.style.setProperty('--native-titlebar', '\(titlebar)px'); html.style.setProperty('--native-controls-inset', '\(inset)px');
        if (\(fullScreen)) html.dataset.nativeFullScreen = '1'; else delete html.dataset.nativeFullScreen; })();
        """
    }

    /// Runs before any of the page's own scripts on every load.
    private func refreshUserScript() {
        let controller = webView.configuration.userContentController
        controller.removeAllUserScripts()
        controller.addUserScript(Self.stateScript(stateJSON(), chrome: chromeJS(), site: agent.settings.site))
    }

    private func updateChrome() {
        guard webView != nil else { return }
        refreshUserScript()
        webView.evaluateJavaScript(chromeJS())
    }

    private func applyAppearance(scheme: String, to window: NSWindow) {
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
        // The site asked Hackatime to send the sign-in back to the app: run
        // it in the system sheet, which already knows the student's session.
        // The redirect back to this app identifies it, whichever origin the
        // site uses for Hackatime.
        if url.path == "/oauth/authorize",
           URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
               .first(where: { $0.name == "redirect_uri" })?.value?.hasPrefix("hackatime-desktop://") == true {
            signIn(url)
            return .cancel
        }
        if action.targetFrame?.isMainFrame == true, isSite(url), !url.path.hasPrefix("/auth/") { lastSiteURL = url }
        let inWindow = belongsInWindow(url)
        if !["http", "https", "about", "blob", "data"].contains(url.scheme ?? "") ||
            (action.navigationType == .linkActivated && action.targetFrame?.isMainFrame == true && !inWindow) {
            NSWorkspace.shared.open(url)
            return .cancel
        }
        return .allow
    }

    private func signIn(_ url: URL) {
        authSession?.cancel()
        let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "hackatime-desktop") { [weak self] callback, error in
            Task { @MainActor in
                guard let self else { return }
                self.authSession = nil
                guard let callback else {
                    // Cancelled: offer to try again instead of an empty window.
                    if self.overlay.state != .hidden || self.webView.url == nil { self.setOverlay(.signedOut) }
                    if let error, (error as? ASWebAuthenticationSessionError)?.code != .canceledLogin {
                        self.toasts.show("Couldn't sign in", detail: error.localizedDescription, style: .error)
                    }
                    return
                }
                var components = URLComponents(url: self.agent.settings.site.appendingPathComponent("auth/callback"),
                                               resolvingAgainstBaseURL: false)!
                components.query = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.query
                if self.overlay.state != .hidden { self.setOverlay(.loading) }
                self.webView.load(URLRequest(url: components.url!))
            }
        }
        session.presentationContextProvider = self
        authSession = session
        session.start()
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated { window ?? NSApp.keyWindow ?? NSWindow() }
    }

    /// target=_blank links open in the browser.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = action.request.url { NSWorkspace.shared.open(url) }
        return nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let error = error as NSError
        guard error.code != NSURLErrorCancelled else { return }
        let offline = error.domain == NSURLErrorDomain && [
            NSURLErrorNotConnectedToInternet, NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost,
            NSURLErrorTimedOut, NSURLErrorNetworkConnectionLost, NSURLErrorDNSLookupFailed,
        ].contains(error.code)
        if offline, network.currentPath.status == .satisfied {
            // The network is fine but the site isn't answering, so nothing
            // will tell us when it's back: try again every so often.
            setOverlay(.unreachable(error.localizedDescription))
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(15))
                guard let self, case .unreachable = self.overlay.state else { return }
                self.retry()
            }
        } else if offline { setOverlay(.offline(error.localizedDescription)) } else {
            toasts.show("Couldn't open that page", detail: error.localizedDescription, style: .error)
            if overlay.state == .loading { setOverlay(.hidden) }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // The site says when it's ready; anything else is shown once loaded,
        // and the site too if it never says so.
        guard overlay.state == .loading else { return }
        if let url = webView.url, isSite(url) {
            revealFallback = Task { [weak self] in
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled, self?.overlay.state == .loading else { return }
                self?.setOverlay(.hidden)
            }
        } else {
            setOverlay(.hidden)
        }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { setOverlay(.crashed) }

    // MARK: Window delegate

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
    func windowDidEnterFullScreen(_ notification: Notification) { updateChrome() }
    func windowDidExitFullScreen(_ notification: Notification) { updateChrome() }
}

/// A WKWebView without the browser's context menu items: no Reload, Back,
/// Forward, Inspect Element or "Open in New Window". Copy, Look Up, Share and
/// the like stay.
final class HackatimeWebView: WKWebView {
    private static let browserItems: Set<String> = [
        "WKMenuItemIdentifierReload", "WKMenuItemIdentifierGoBack", "WKMenuItemIdentifierGoForward",
        "WKMenuItemIdentifierInspectElement", "WKMenuItemIdentifierOpenLinkInNewWindow",
        "WKMenuItemIdentifierDownloadLinkedFile", "WKMenuItemIdentifierOpenImageInNewWindow",
        "WKMenuItemIdentifierDownloadImage", "WKMenuItemIdentifierOpenFrameInNewWindow",
        "WKMenuItemIdentifierOpenMediaInNewWindow", "WKMenuItemIdentifierDownloadMedia",
    ]

    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        menu.items.removeAll { Self.browserItems.contains($0.identifier?.rawValue ?? "") }
        var previousWasSeparator = true
        for item in menu.items {
            if item.isSeparatorItem, previousWasSeparator { menu.removeItem(item) } else { previousWasSeparator = item.isSeparatorItem }
        }
        if menu.items.last?.isSeparatorItem == true { menu.removeItem(at: menu.items.count - 1) }
        super.willOpenMenu(menu, with: event)
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
