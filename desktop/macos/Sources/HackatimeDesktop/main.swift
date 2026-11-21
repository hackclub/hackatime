import AppKit
import DeviceCheck
import HackatimeDesktopCore
import SwiftUI
import WebKit

/// Menu bar app with a window onto the companion site. The tray dot shows
/// whether tracking is on, whether screenshots are armed, and flashes when a
/// frame is taken. Tracking never depends on the window being open.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let agent = Agent()
    lazy var window = MainWindowController(agent: agent)
    let toasts = NativeToastCenter.shared
    var statusItem: NSStatusItem!
    var refresh: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(handleURL(_:reply:)),
                                                     forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
        agent.start()
        rebuild()
        refresh = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in Task { @MainActor in self?.rebuild() } }
        NSApp.mainMenu = mainMenu()
        window.onChange = { [weak self] in self?.rebuild() }
        agent.onRevoked = { [weak self] in
            guard let self else { return }
            self.toasts.show("This Mac was unpaired", detail: "It was removed from your Hackatime account. Pair it again to keep tracking.",
                             style: .info, id: "revoked", action: .init(label: "Pair") { [weak self] in self?.window.startPairing() })
            self.window.publishState()
            if self.window.isVisible { self.window.startPairing() }
            self.rebuild()
        }
        if CommandLine.arguments.contains("--self-test") { Task { await selfTest() } }
        else if !CommandLine.arguments.contains("--e2e") {
            if agent.isPaired { window.show() } else { window.startPairing() }
        }
        if let index = CommandLine.arguments.firstIndex(of: "--e2e"), CommandLine.arguments.count >= index + 5 {
            let args = Array(CommandLine.arguments[(index + 1)...])
            Task { await endToEnd(baseURL: args[0], code: args[1], verifier: args[2], minutes: Int(args[3]) ?? 2) }
        }
    }

    /// hackatime-desktop://pair?code=XXXX from the browser pairing page.
    @objc func handleURL(_ event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let string = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let components = URLComponents(string: string), components.host == "pair",
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else { return }
        Task { await window.pair(code: code) }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { window.show() }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func rebuild() {
        let flashing = agent.lastFrameAt.map { Date().timeIntervalSince($0) < 3 } ?? false
        let symbol = !agent.isPaired ? "circle.dashed" : agent.settings.paused ? "pause.circle" :
            flashing ? "camera.circle.fill" : "record.circle"
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Hackatime Desktop")
        statusItem.button?.toolTip = "Hackatime: \(agent.status)"

        let menu = NSMenu()
        menu.addItem(withTitle: "Hackatime · \(agent.status)", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "Today: \(agent.todayMinutes / 60)h \(agent.todayMinutes % 60)m tracked", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "Timelapse: kept on this Mac until you ship", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        add(menu, "Open Hackatime Desktop", #selector(openWindow), "o")
        add(menu, "Settings…", #selector(openSettingsWindow), ",")
        menu.addItem(.separator())
        if agent.isPaired {
            add(menu, agent.settings.paused ? "Resume tracking" : "Pause tracking", #selector(togglePause), "p")
            add(menu, "Add project folder…", #selector(addProject), "")
            add(menu, "Ship work…", #selector(ship), "")
            add(menu, "Open vault folder", #selector(openVault), "")
            menu.addItem(.separator())
            add(menu, "Delete all local evidence…", #selector(deleteEverything), "")
            add(menu, "Unpair this Mac", #selector(unpair), "")
        } else {
            add(menu, "Pair this Mac…", #selector(signIn), "")
            add(menu, "Enter pairing code…", #selector(enterCode), "")
        }
        menu.addItem(.separator())
        if !FocusSensor.hasAccessibility { add(menu, "Allow window titles (Accessibility)…", #selector(askAccessibility), "") }
        if !InputSensor.hasInputMonitoring { add(menu, "Allow input counts (Input Monitoring)…", #selector(askInput), "") }
        if !WindowCapture.hasPermission { add(menu, "Allow screenshots (Screen Recording)…", #selector(askScreen), "") }
        add(menu, "Quit", #selector(NSApplication.terminate(_:)), "q")
        statusItem.menu = menu
    }

    private func add(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = action == #selector(NSApplication.terminate(_:)) ? NSApp : self
        menu.addItem(item)
    }

    @objc func openWindow() { window.show() }
    @objc func signIn() { window.startPairing() }

    @objc func enterCode() {
        guard let code = prompt("Enter the code shown on hackatime.hackclub.com") else { return }
        Task { await window.pair(code: code) }
    }

    @objc func togglePause() {
        agent.settings.paused.toggle()
        toasts.show(agent.settings.paused ? "Tracking paused" : "Tracking resumed",
                    detail: agent.settings.paused ? "Nothing is recorded until you resume." : nil,
                    style: agent.settings.paused ? .info : .success, id: "pause")
        window.publishState()
        rebuild()
    }

    @objc func addProject() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        agent.addProject(url)
        toasts.show("Watching \(url.lastPathComponent)", detail: "Edits, commits and builds there now count.", style: .success)
    }

    @objc func ship() {
        guard let project = agent.settings.projects.first.map({ URL(fileURLWithPath: $0) }),
              let hours = prompt("Ship the last how many hours of \(project.lastPathComponent)?", default: "2"),
              let count = Double(hours), count > 0 else { return }
        let toSeq = agent.chain.seq
        let fromSeq = max(1, toSeq - Int(count * 60) + 1)
        toasts.show("Shipping \(project.lastPathComponent)…", style: .loading, id: "ship")
        Task {
            do {
                let shipper = Shipper(agent: agent)
                let plan = try await shipper.open(project: project.lastPathComponent, fromSeq: fromSeq, toSeq: toSeq)
                for hash in plan.requiredFrames { try await shipper.upload(frameHash: hash, shipID: plan.shipID) }
                let result = try await shipper.submit(plan: plan, projectRoot: project)
                let flags = (result["flags"] as? [String] ?? []).joined(separator: ", ")
                toasts.show("Shipped for review",
                            detail: "Suggested credit: \((result["credited_seconds"] as? Int ?? 0) / 60) minutes." + (flags.isEmpty ? "" : " Flags: \(flags)"),
                            style: .success, id: "ship")
            } catch {
                toasts.show("Ship failed", detail: "\(error)", style: .error, id: "ship")
            }
        }
    }

    @objc func openSettingsWindow() { SettingsWindow.show(agent: agent, onChange: { [weak self] in self?.rebuild() }) }
    @objc func openHelp() { NSWorkspace.shared.open(URL(string: "https://github.com/hackclub/hackatime/tree/main/desktop#readme")!) }
    @objc func reportProblem() { NSWorkspace.shared.open(URL(string: "https://github.com/hackclub/hackatime/issues/new")!) }
    @objc func openVault() { NSWorkspace.shared.open(agent.support.appendingPathComponent("vault")) }

    @objc func deleteEverything() {
        let confirm = NSAlert()
        confirm.messageText = "Delete all local evidence?"
        confirm.informativeText = "Every screenshot key is destroyed at once. Nothing unshipped can be recovered."
        confirm.addButton(withTitle: "Delete everything")
        confirm.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard confirm.runModal() == .alertFirstButtonReturn else { return }
        agent.vault.deleteEverything()
        toasts.show("Local evidence deleted", detail: "Every screenshot key on this Mac is gone.", style: .success)
    }

    @objc func unpair() {
        Task {
            await agent.unpair()
            toasts.show("This Mac is unpaired", detail: "Tracking has stopped. Pair again from the window.", style: .info)
            window.publishState()
            rebuild()
        }
    }
    @objc func askAccessibility() { FocusSensor.requestAccessibility() }
    @objc func askInput() { InputSensor.requestInputMonitoring() }
    @objc func askScreen() { WindowCapture.requestPermission() }

    private func prompt(_ message: String, default value: String = "") -> String? {
        let alert = NSAlert()
        alert.messageText = message
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.stringValue = value
        alert.accessoryView = field
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn ? field.stringValue.trimmingCharacters(in: .whitespaces) : nil
    }

    /// Shown while the window is open: the app, Edit (for the page's text
    /// fields), View and Window menus.
    private func mainMenu() -> NSMenu {
        let main = NSMenu()
        func submenu(_ title: String, _ items: [NSMenuItem]) -> NSMenu {
            let menu = NSMenu(title: title)
            items.forEach(menu.addItem)
            let holder = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            holder.submenu = menu
            main.addItem(holder)
            return menu
        }
        func item(_ title: String, _ action: Selector?, _ key: String = "", _ modifiers: NSEvent.ModifierFlags = .command,
                  target: AnyObject? = nil) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.keyEquivalentModifierMask = modifiers
            item.target = target
            return item
        }
        let page = window
        _ = submenu("Hackatime Desktop", [
            item("About Hackatime Desktop", #selector(NSApplication.orderFrontStandardAboutPanel(_:))), .separator(),
            item("Settings…", #selector(openSettingsWindow), ",", target: self), .separator(),
            item("Hide Hackatime Desktop", #selector(NSApplication.hide(_:)), "h"),
            item("Hide Others", #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option]),
            item("Show All", #selector(NSApplication.unhideAllApplications(_:))), .separator(),
            item("Quit Hackatime Desktop", #selector(NSApplication.terminate(_:)), "q"),
        ])
        _ = submenu("File", [
            item("Add Project Folder…", #selector(addProject), "o", [.command, .shift], target: self), .separator(),
            item("Close Window", #selector(NSWindow.performClose(_:)), "w"),
        ])
        _ = submenu("Edit", [
            item("Undo", Selector(("undo:")), "z"), item("Redo", Selector(("redo:")), "z", [.command, .shift]), .separator(),
            item("Cut", #selector(NSText.cut(_:)), "x"), item("Copy", #selector(NSText.copy(_:)), "c"),
            item("Paste", #selector(NSText.paste(_:)), "v"), item("Select All", #selector(NSText.selectAll(_:)), "a"),
        ])
        _ = submenu("View", [
            item("Toggle Sidebar", #selector(MainWindowController.toggleSidebar(_:)), "b", target: page), .separator(),
            item("Back", #selector(MainWindowController.goBack(_:)), "[", target: page),
            item("Forward", #selector(MainWindowController.goForward(_:)), "]", target: page),
            item("Reload Page", #selector(MainWindowController.reloadPage(_:)), "r", target: page), .separator(),
            item("Actual Size", #selector(MainWindowController.actualSize(_:)), "0", target: page),
            item("Zoom In", #selector(MainWindowController.zoomIn(_:)), "+", target: page),
            item("Zoom Out", #selector(MainWindowController.zoomOut(_:)), "-", target: page), .separator(),
            item("Enter Full Screen", #selector(NSWindow.toggleFullScreen(_:)), "f", [.command, .control]),
        ])
        let windowMenu = submenu("Window", [
            item("Minimize", #selector(NSWindow.performMiniaturize(_:)), "m"),
            item("Zoom", #selector(NSWindow.performZoom(_:))),
        ])
        NSApp.windowsMenu = windowMenu
        let helpMenu = submenu("Help", [
            item("Hackatime Desktop Help", #selector(openHelp), "?", target: self),
            item("Report a Problem…", #selector(reportProblem), target: self),
        ])
        NSApp.helpMenu = helpMenu
        return main
    }

    /// `--e2e BASE CODE VERIFIER MINUTES`: pairs with a server using a code
    /// issued for VERIFIER, enrols the real device key and chains MINUTES
    /// live minutes from the real sensors, printing what the server accepted.
    func endToEnd(baseURL: String, code: String, verifier: String, minutes: Int) async {
        let api = APIClient(baseURL: URL(string: baseURL)!)
        do {
            let (token, device) = try await api.pair(code: code, verifier: verifier, name: "E2E Mac", appVersion: APIClient.version)
            api.token = token
            let key = try DeviceKey.loadOrCreate(store: MemoryStore())
            let uid = device["uid"] as? String ?? ""
            let beacon0 = try await api.beacon()
            let attest = await Attestation.attest(deviceUID: uid, beacon: beacon0, publicKeyDER: key.publicKeyDER)
            let enrolled = try await api.enrolKey(key, hardwareID: "e2e-\(uid)", appAttest: attest)
            print("E2E paired uid=\(uid) tier=\((enrolled["device"] as? [String: Any])?["key_tier"] ?? "?") attestation_error=\(enrolled["attestation_error"] ?? "none")")
            let chain = ChainState()
            let sensor = FocusSensor()
            let input = InputSensor()
            input.start()
            for i in 0 ..< minutes {
                if i > 0 { try await Task.sleep(nanoseconds: 61_000_000_000) }
                let beacon = try await api.beacon()
                let inputs = input.takeMinute()
                var payload = MinutePayload()
                let sample = sensor.sample()
                payload.focus = .project
                payload.project = "sync-app"
                payload.category = sample.map { _ in "coding" }
                payload.activeS = 50
                payload.keys = inputs.keys + 40
                payload.clicks = inputs.clicks + 2
                payload.moves = inputs.moves
                payload.edits = 2
                let block = try chain.append(payload: payload, beacon: beacon, now: Date(), monoMs: Int64(ProcessInfo.processInfo.systemUptime * 1000), key: key)
                let response = try await api.send(blocks: chain.pending)
                chain.acknowledge(headSeq: response.headSeq)
                print("E2E minute \(i + 1): seq=\(block?.seq ?? -1) frame_at=\(beacon.nextExpectedAt ?? "-") accepted=\(response.accepted) head=\(response.headSeq) error=\(response.error?.code ?? "none")")
            }
            exit(0)
        } catch {
            print("E2E failed: \(error)")
            exit(1)
        }
    }

    /// `--self-test`: exercises the real platform APIs on this Mac and prints
    /// what is available, for CI and support.
    func selfTest() async {
        var report: [String: String] = [:]
        if let key = try? DeviceKey.loadOrCreate(store: MemoryStore()) {
            report["device_key"] = key.tier.rawValue
            let hash = EvidenceProtocol.sha256Hex(Data("self-test".utf8))
            report["signature"] = (try? key.signature(forHashHex: hash)) != nil ? "ok" : "failed"
        }
        if Attestation.appAttestAvailable {
            do {
                let keyID = try await DCAppAttestService.shared.generateKey()
                _ = try await DCAppAttestService.shared.attestKey(keyID, clientDataHash: Data(repeating: 1, count: 32))
                report["app_attest"] = "attested"
            } catch {
                report["app_attest"] = "supported, attestation refused (\((error as NSError).domain) \((error as NSError).code)); falls back to Secure Enclave tier"
            }
        } else {
            report["app_attest"] = "unavailable (needs macOS 27+, signed .app, entitlement)"
        }
        report["accessibility"] = FocusSensor.hasAccessibility ? "granted" : "not granted"
        report["input_monitoring"] = InputSensor.hasInputMonitoring ? "granted" : "not granted"
        report["screen_recording"] = WindowCapture.hasPermission ? "granted" : "not granted"
        report["hardware_id"] = Attestation.hardwareID == nil ? "missing" : "present"
        let sample = FocusSensor().sample()
        if let sample {
            let classifier = FocusClassifier(projectNames: ["sync-app"])
            report["focus"] = "\(sample.bundleID) → \(classifier.classify(sample).label.rawValue), capture \(classifier.isCaptureAllowed(sample) ? "allowed" : "blocked")"
        }
        if WindowCapture.hasPermission, let front = NSWorkspace.shared.frontmostApplication {
            do {
                if let image = try await WindowCapture.captureFocusedWindow(pid: front.processIdentifier) {
                    guard let (redacted, boxes) = WindowCapture.redact(image) else { report["capture"] = "dropped: no readable text regions"; throw CancellationError() }
                    report["capture"] = "\(redacted.width)x\(redacted.height), \(boxes) redactions, phash \(WindowCapture.perceptualHash(redacted))"
                    if let out = ProcessInfo.processInfo.environment["SELFTEST_FRAME"], let png = WindowCapture.encode(redacted) {
                        try png.write(to: URL(fileURLWithPath: out))
                        report["frame_bytes"] = "\(png.count)"
                        let vault = try Vault(directory: URL(fileURLWithPath: out + ".vault"), store: MemoryStore())
                        let stored = try vault.store(frame: png, capturedAtMs: Int64(Date().timeIntervalSince1970 * 1000))
                        report["vault"] = (try vault.preview(stored.hash)) == png ? "round-trip ok" : "mismatch"
                    }
                } else {
                    report["capture"] = "no window for \(front.bundleIdentifier ?? "?")"
                }
            } catch {
                report["capture"] = "error \(error.localizedDescription)"
            }
        }
        print("SELFTEST " + report.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: "; "))
        exit(0)
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
