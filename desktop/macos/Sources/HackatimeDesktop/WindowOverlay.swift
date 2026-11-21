import AppKit
import SwiftUI

/// What the window shows instead of the page: a quiet placeholder while the
/// site loads, and native empty states when it can't be shown.
@MainActor
final class WindowOverlayModel: ObservableObject {
    enum State: Equatable {
        case hidden, loading, crashed, signedOut
        case offline(String), unreachable(String)
    }

    @Published var state: State = .loading
    @Published var background: NSColor = .black
}

struct WindowOverlay: View {
    @ObservedObject var model: WindowOverlayModel
    let retry: () -> Void
    let signIn: () -> Void

    var body: some View {
        ZStack {
            // Tinted towards the theme, with the window material showing through.
            Color(nsColor: model.background).opacity(0.86)
            content
                .frame(maxWidth: 340)
                .multilineTextAlignment(.center)
                .transition(.opacity)
        }
        .animation(.easeOut(duration: 0.2), value: model.state)
        .ignoresSafeArea()
    }

    @ViewBuilder private var content: some View {
        switch model.state {
        case .hidden:
            EmptyView()
        case .loading:
            VStack(spacing: 14) {
                AppMark()
                ProgressView().controlSize(.small)
            }
        case .offline(let detail):
            message(symbol: "wifi.slash", title: "You're offline",
                    detail: "Hackatime Desktop will reconnect by itself when the network is back. Tracking carries on in the meantime.\n\(detail)",
                    button: "Try Again", action: retry)
        case .unreachable(let detail):
            message(symbol: "bolt.horizontal.circle", title: "Can't reach Hackatime",
                    detail: "Hackatime Desktop will keep trying. Tracking carries on in the meantime.\n\(detail)",
                    button: "Try Again", action: retry)
        case .crashed:
            message(symbol: "exclamationmark.triangle", title: "This window stopped unexpectedly",
                    detail: "Tracking wasn't affected. Reload to pick up where you left off.",
                    button: "Reload", action: retry)
        case .signedOut:
            message(symbol: "person.crop.circle.badge.questionmark", title: "Sign in to Hackatime",
                    detail: "Sign in to see your stats and pair this Mac.",
                    button: "Sign In…", action: signIn)
        }
    }

    private func message(symbol: String, title: String, detail: String, button: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)
            Text(title).font(.system(size: 15, weight: .semibold))
            Text(detail).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button(button, action: action)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .padding(.top, 6)
        }
    }
}

/// The app icon, or a clock glyph when the bundle has none.
private struct AppMark: View {
    var body: some View {
        if let icon = NSApp.applicationIconImage, NSImage(named: "AppIcon") != nil {
            Image(nsImage: icon).resizable().frame(width: 56, height: 56)
        } else {
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.secondary)
        }
    }
}
