import AppKit
import SwiftUI

/// Native toasts, modelled on Amp's Mac app: a small glass card that springs
/// in, morphs in place when the same toast is updated (pairing… → paired),
/// pauses while hovered and leaves on its own. They sit at the bottom of the
/// main window when it is open, otherwise under the menu bar, so menu bar
/// actions get the same feedback as the site.
struct NativeToast: Identifiable, Equatable {
    enum Style: String { case info, success, error, loading }

    let id: String
    var title: String
    var detail: String?
    var style: Style
    var action: Action?

    struct Action: Equatable {
        let label: String
        let perform: @MainActor () -> Void
        static func == (a: Action, b: Action) -> Bool { a.label == b.label }
    }

    var lifetime: Duration? {
        switch style {
        case .loading: nil
        case .error: .seconds(6)
        default: .seconds(detail == nil ? 3.2 : 4.5)
        }
    }
}

@MainActor
final class NativeToastCenter: ObservableObject {
    static let shared = NativeToastCenter()

    @Published private(set) var toasts: [NativeToast] = []
    private var timers: [String: Task<Void, Never>] = [:]
    private var panel: ToastPanel?
    /// The window toasts attach to while it is on screen.
    weak var host: NSWindow? { didSet { panel?.place(over: host) } }

    /// Shows a toast, or updates the one with the same id in place.
    func show(_ title: String, detail: String? = nil, style: NativeToast.Style = .info,
              id: String = UUID().uuidString, action: NativeToast.Action? = nil) {
        let toast = NativeToast(id: id, title: title, detail: detail, style: style, action: action)
        if panel == nil { panel = ToastPanel(center: self) }
        panel?.place(over: host)
        if let index = toasts.firstIndex(where: { $0.id == id }) {
            toasts[index] = toast
        } else {
            toasts.append(toast)
            if toasts.count > 3 { dismiss(toasts[0].id) }
        }
        panel?.ignoresMouseEvents = false
        schedule(toast)
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested,
                             userInfo: [.announcement: [title, detail].compactMap { $0 }.joined(separator: ". "),
                                        .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }

    func dismiss(_ id: String) {
        timers.removeValue(forKey: id)?.cancel()
        toasts.removeAll { $0.id == id }
        if toasts.isEmpty { panel?.ignoresMouseEvents = true }
    }

    /// Hovering holds a toast; leaving gives it a moment before it goes.
    func hold(_ id: String, _ holding: Bool) {
        guard let toast = toasts.first(where: { $0.id == id }) else { return }
        if holding { timers.removeValue(forKey: id)?.cancel() } else { schedule(toast, after: .seconds(1.6)) }
    }

    private func schedule(_ toast: NativeToast, after delay: Duration? = nil) {
        timers.removeValue(forKey: toast.id)?.cancel()
        guard let lifetime = delay ?? toast.lifetime else { return }
        timers[toast.id] = Task { [weak self] in
            try? await Task.sleep(for: lifetime)
            guard !Task.isCancelled else { return }
            self?.dismiss(toast.id)
        }
    }
}

/// A borderless, see-through panel holding the stack. Transparent pixels let
/// clicks through, so it never blocks the page underneath.
@MainActor
final class ToastPanel: NSPanel {
    static let size = NSSize(width: 440, height: 280)
    private let edge: EdgeBox

    init(center: NativeToastCenter) {
        edge = EdgeBox()
        super.init(contentRect: NSRect(origin: .zero, size: Self.size), styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isReleasedWhenClosed = false
        contentView = NSHostingView(rootView: NativeToastStack(center: center, edge: edge))
        orderFrontRegardless()
    }

    override var canBecomeKey: Bool { false }

    /// Bottom centre of the window when it is visible, else the top right of
    /// the screen below the menu bar.
    func place(over window: NSWindow?) {
        if let window, window.isVisible, !window.isMiniaturized {
            level = window.level
            appearance = window.appearance
            if parent !== window { parent?.removeChildWindow(self); window.addChildWindow(self, ordered: .above) }
            edge.value = .bottom
            setFrameOrigin(NSPoint(x: window.frame.midX - Self.size.width / 2, y: window.frame.minY + 14))
        } else {
            parent?.removeChildWindow(self)
            level = .statusBar
            appearance = nil
            edge.value = .top
            let screen = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
            setFrameOrigin(NSPoint(x: screen.maxX - Self.size.width - 6, y: screen.maxY - Self.size.height - 4))
            orderFrontRegardless()
        }
    }
}

@MainActor
final class EdgeBox: ObservableObject { @Published var value: VerticalEdge = .top }

struct NativeToastStack: View {
    @ObservedObject var center: NativeToastCenter
    @ObservedObject var edge: EdgeBox
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 8) {
            // Newest nearest the edge it came from.
            ForEach(edge.value == .top ? Array(center.toasts.reversed()) : center.toasts) { toast in
                NativeToastView(toast: toast, center: center)
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .move(edge: edge.value == .top ? .top : .bottom).combined(with: .scale(scale: 0.92)).combined(with: .opacity),
                        removal: .scale(scale: 0.96).combined(with: .opacity)))
            }
        }
        .padding(16)
        .frame(width: ToastPanel.size.width, height: ToastPanel.size.height,
               alignment: edge.value == .top ? .topTrailing : .bottom)
        .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.38, dampingFraction: 0.82), value: center.toasts)
    }
}

struct NativeToastView: View {
    let toast: NativeToast
    let center: NativeToastCenter
    @State private var hovering = false

    var body: some View {
        HStack(alignment: toast.detail == nil ? .center : .top, spacing: 10) {
            icon.frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title)
                    .font(.system(size: 13, weight: .semibold))
                    .contentTransition(.interpolate)
                if let detail = toast.detail {
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .contentTransition(.interpolate)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: 300, alignment: .leading)
            if let action = toast.action {
                Button(action.label) {
                    action.perform()
                    center.dismiss(toast.id)
                }
                .buttonStyle(.borderless)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.08), in: Capsule())
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, toast.action == nil ? 14 : 8)
        .padding(.vertical, 14)
        .fixedSize(horizontal: true, vertical: false)
        .modifier(Glass())
        .scaleEffect(hovering ? 1.015 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: hovering)
        .animation(.snappy(duration: 0.28), value: toast.title)
        .animation(.snappy(duration: 0.28), value: toast.style)
        .onHover { hovering = $0; center.hold(toast.id, $0) }
        .onTapGesture { center.dismiss(toast.id) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }

    @ViewBuilder private var icon: some View {
        switch toast.style {
        case .loading:
            ProgressView().controlSize(.small).scaleEffect(0.8)
        case .success:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).transition(.scale.combined(with: .opacity))
        case .error:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange).transition(.scale.combined(with: .opacity))
        case .info:
            Image(systemName: "info.circle.fill").foregroundStyle(.secondary)
        }
    }
}

/// Liquid Glass on macOS 26+, a material card before it.
private struct Glass: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            // Tinted so text stays readable over a busy page.
            content.glassEffect(.regular.tint(Color(nsColor: .windowBackgroundColor).opacity(0.6)), in: .rect(cornerRadius: 14))
        } else {
            content
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.primary.opacity(0.1)))
                .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
        }
    }
}
