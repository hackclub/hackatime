import AppKit
import Combine
import HackatimeDesktopCore
import SwiftUI
import WebKit

/// Menu bar app with a window onto the companion site. The tray dot shows
/// whether tracking is on, whether screenshots are armed, and flashes when a
/// frame is taken. Tracking never depends on the window being open.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let agent = Agent()
    lazy var window = MainWindowController(agent: agent)
    let toasts = NativeToastCenter.shared
    var statusItem: NSStatusItem!
    private var agentChanges: AnyCancellable?
    private var flashEnd: DispatchWorkItem?
    private var shownSymbol: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(handleURL(_:reply:)),
                                                     forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
        agent.start()
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        rebuild()
        // The icon follows the agent's state; the menu is built when it opens.
        agentChanges = agent.objectWillChange.receive(on: DispatchQueue.main).sink { [weak self] in self?.rebuild() }
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
        if CommandLine.arguments.contains("--self-test") { Task { await SelfTest.run() } }
        else if agent.isPaired { window.show() } else { window.startPairing() }
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

    /// Updates the menu bar icon and tooltip when they changed.
    func rebuild() {
        let sinceFrame = agent.lastFrameAt.map { Date().timeIntervalSince($0) }
        let flashing = sinceFrame.map { $0 < 3 } ?? false
        let symbol = !agent.isPaired ? "circle.dashed" : agent.settings.paused ? "pause.circle" :
            flashing ? "camera.circle.fill" : "record.circle"
        if shownSymbol != symbol {
            shownSymbol = symbol
            statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Hackatime Desktop")
        }
        let tip = "Hackatime: \(agent.status)"
        if statusItem.button?.toolTip != tip { statusItem.button?.toolTip = tip }
        // Turn the camera off again when the flash ends.
        flashEnd?.cancel()
        if let sinceFrame, flashing {
            let work = DispatchWorkItem { [weak self] in self?.rebuild() }
            flashEnd = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 3 - sinceFrame, execute: work)
        }
    }

    /// Fills the status menu as it opens, so it is current without being
    /// rebuilt in the background.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
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
        let projects = agent.settings.projects.map { URL(fileURLWithPath: $0) }
        guard !projects.isEmpty else {
            toasts.show("Add a project folder first", detail: "Ships are made from a project folder's tracked time.", style: .info)
            return
        }
        let alert = NSAlert()
        alert.messageText = "Ship work"
        alert.informativeText = "Choose a project and how many hours of its tracked time to ship."
        let picker = NSPopUpButton(frame: NSRect(x: 0, y: 30, width: 240, height: 26))
        picker.addItems(withTitles: projects.map(\.lastPathComponent))
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.stringValue = "2"
        let box = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 56))
        box.addSubview(picker)
        box.addSubview(field)
        alert.accessoryView = box
        alert.addButton(withTitle: "Ship")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn, let hours = Double(field.stringValue.trimmingCharacters(in: .whitespaces)), hours > 0 else { return }
        let project = projects[picker.indexOfSelectedItem]
        guard let range = agent.ledger.range(project: project.lastPathComponent, hours: hours) else {
            toasts.show("Nothing to ship", detail: "Hackatime has no tracked minutes on \(project.lastPathComponent) since your last ship.", style: .info)
            return
        }
        Task {
            do {
                let name = project.lastPathComponent
                // Step 1, on this Mac only: the timeline, where the user
                // removes time before the server hears of the ship.
                let vault = agent.vault
                let timeline = ShipTimeline(project: name, entries: agent.ledger.entries, range: range, activity: agent.activity)
                let from = timeline.minutes.first?.startMs ?? 0, to = (timeline.minutes.last?.startMs ?? 0) + 60_000
                let review = ShipTimelineModel(timeline: timeline,
                                               frames: vault.frames.filter { from <= $0.capturedAtMs && $0.capturedAtMs < to }.map { ($0.hash, $0.capturedAtMs) },
                                               loadFrame: { hash in (try? vault.preview(hash)).flatMap(FrameRedaction.decode) })
                guard await ShipReviewWindow.run(title: "Review ship", size: NSSize(width: 1100, height: 800), step: review,
                                                 content: ShipTimelineView(model: review)) else {
                    toasts.show("Ship cancelled", detail: "Nothing was sent.", style: .info, id: "ship")
                    return
                }
                toasts.show("Shipping \(name)…", style: .loading, id: "ship")
                let shipper = Shipper(agent: agent)
                let finalFiles = try await Shipper.finalFiles(projectRoot: project)
                let plan = try await shipper.open(project: name, fromSeq: range.lowerBound, toSeq: range.upperBound,
                                                  excluded: review.timeline.excludedRanges)
                // Step 2: nothing is uploaded until the user has seen every frame the server asked for.
                let frames = try plan.requiredFrames.map { hash in
                    guard let image = FrameRedaction.decode(try agent.vault.preview(hash)) else { throw CocoaError(.fileReadCorruptFile) }
                    return ShipPreviewModel.Frame(id: hash, image: image)
                }
                toasts.dismiss("ship")
                let preview = ShipPreviewModel(project: name, frames: frames)
                guard await ShipReviewWindow.run(title: "Preview frames", size: NSSize(width: 900, height: 680), step: preview,
                                                 content: ShipPreviewView(model: preview)) else {
                    toasts.show("Ship cancelled", detail: "Nothing was uploaded.", style: .info, id: "ship")
                    return
                }
                toasts.show("Shipping \(project.lastPathComponent)…", style: .loading, id: "ship")
                for upload in preview.uploads() {
                    try await shipper.upload(frameHash: upload.hash, shipID: plan.shipID, redacted: upload.redacted, regions: upload.regions)
                }
                let result = try await shipper.submit(plan: plan, finalFiles: finalFiles)
                let flags = (result["flags"] as? [String] ?? []).joined(separator: ", ")
                toasts.show("Shipped for review",
                            detail: "Suggested credit: \((result["credited_seconds"] as? Int ?? 0) / 60) minutes." + (flags.isEmpty ? "" : " Flags: \(flags)"),
                            style: .success, id: "ship")
            } catch {
                toasts.show("Ship failed", detail: Shipper.message(for: error), style: .error, id: "ship")
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
        agent.forgetLocalEvidence()
        toasts.show("Local evidence deleted", detail: "Every screenshot key on this Mac is gone.", style: .success)
    }

    @objc func unpair() {
        Task {
            if let failure = await agent.unpair() {
                toasts.show("Could not unpair this Mac", detail: "Still paired and tracking. \(failure)", style: .error, id: "unpair")
                return
            }
            toasts.show("This Mac is unpaired", detail: "Tracking has stopped. Pair again from the window.", style: .info, id: "unpair")
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
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
