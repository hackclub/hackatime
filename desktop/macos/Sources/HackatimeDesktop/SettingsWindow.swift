import AppKit
import SwiftUI

/// Settings… (⌘,): what belongs to this Mac rather than the account, so it
/// lives in a native window instead of the site.
@MainActor
enum SettingsWindow {
    private static var window: NSWindow?

    static func show(agent: Agent, onChange: @escaping () -> Void) {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView(agent: agent, onChange: onChange))
            let window = NSWindow(contentViewController: hosting)
            window.title = "Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        // Same light or dark as the main window, which follows the theme.
        window?.appearance = NSAppearance(named: UserDefaults.standard.string(forKey: "windowScheme") == "light" ? .aqua : .darkAqua)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

private struct SettingsView: View {
    @ObservedObject var agent: Agent
    let onChange: () -> Void

    var body: some View {
        Form {
            Section("Tracking") {
                Toggle("Pause tracking", isOn: Binding(get: { agent.settings.paused },
                                                      set: { agent.settings.paused = $0; onChange() }))
                LabeledContent("Status", value: agent.status)
            }
            Section("Project folders") {
                if agent.settings.projects.isEmpty {
                    Text("Edits, commits and builds count in folders you add here.").foregroundStyle(.secondary)
                }
                ForEach(agent.settings.projects, id: \.self) { path in
                    HStack {
                        Image(systemName: "folder")
                        Text(URL(fileURLWithPath: path).lastPathComponent)
                        Spacer()
                        Button("Remove", role: .destructive) {
                            agent.settings.projects.removeAll { $0 == path }
                            agent.watchProjects()
                        }
                        .buttonStyle(.borderless)
                    }
                }
                Button("Add Folder…") {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    if panel.runModal() == .OK, let url = panel.url { agent.addProject(url) }
                }
            }
            Section("Permissions") {
                permission("Window titles", granted: FocusSensor.hasAccessibility, ask: FocusSensor.requestAccessibility)
                permission("Input counts", granted: InputSensor.hasInputMonitoring, ask: InputSensor.requestInputMonitoring)
                permission("Screenshots", granted: WindowCapture.hasPermission, ask: WindowCapture.requestPermission)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func permission(_ title: String, granted: Bool, ask: @escaping () -> Void) -> some View {
        LabeledContent(title) {
            if granted { Label("Allowed", systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
            else { Button("Allow…", action: ask) }
        }
    }
}
