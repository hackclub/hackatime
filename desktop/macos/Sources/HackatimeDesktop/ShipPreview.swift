import AppKit
import HackatimeDesktopCore
import SwiftUI

/// The last step before a ship uploads anything, after the timeline: every
/// frame the server asked for, decrypted locally, where the user can drag
/// boxes to black out regions. Cancelling uploads nothing. A requested frame
/// can be redacted, not removed.
@MainActor
final class ShipPreviewModel: ObservableObject, ShipReviewStep {
    struct Frame: Identifiable {
        let id: String          // committed frame hash
        let image: CGImage
        var regions: [CGRect] = []   // frame pixels, top-left origin
    }

    let project: String
    @Published var frames: [Frame]
    @Published var selected = 0
    var finish: (Bool) -> Void = { _ in }

    init(project: String, frames: [Frame]) {
        self.project = project
        self.frames = frames
    }

    /// The upload for each frame: its redacted copy and regions, or nil to
    /// send the committed original.
    func uploads() -> [(hash: String, redacted: Data?, regions: [[String: Int]])] {
        frames.map { frame in
            guard !frame.regions.isEmpty, let image = FrameRedaction.apply(frame.regions, to: frame.image),
                  let data = FrameRedaction.encode(image) else { return (frame.id, nil, []) }
            return (frame.id, data, FrameRedaction.wire(frame.regions))
        }
    }
}

struct ShipPreviewView: View {
    @ObservedObject var model: ShipPreviewModel
    @State private var dragStart: CGPoint?
    @State private var dragEnd: CGPoint?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Preview \(model.project) before shipping").font(.title2.weight(.semibold))
                if !model.frames.isEmpty {
                    Text("Reviewers will see \(model.frames.count == 1 ? "this frame" : "these \(model.frames.count) frames"). Drag over anything to black it out.")
                        .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            if model.frames.isEmpty {
                Text("No frames to send").foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                editor
                strip
            }
            HStack {
                if !model.frames.isEmpty {
                    Button("Undo") { _ = model.frames[model.selected].regions.popLast() }
                        .disabled(model.frames[model.selected].regions.isEmpty)
                    Button("Clear") { model.frames[model.selected].regions.removeAll() }
                        .disabled(model.frames[model.selected].regions.isEmpty)
                }
                Spacer()
                Button("Cancel") { model.finish(false) }.keyboardShortcut(.cancelAction)
                Button("Ship") { model.finish(true) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 760, minHeight: 600)
    }

    private var editor: some View {
        let frame = model.frames[model.selected]
        let size = CGSize(width: frame.image.width, height: frame.image.height)
        return GeometryReader { geometry in
            let scale = min(geometry.size.width / size.width, geometry.size.height / size.height)
            let shown = CGSize(width: size.width * scale, height: size.height * scale)
            let origin = CGPoint(x: (geometry.size.width - shown.width) / 2, y: (geometry.size.height - shown.height) / 2)
            ZStack(alignment: .topLeading) {
                Image(decorative: frame.image, scale: 1).resizable().frame(width: shown.width, height: shown.height)
                ForEach(Array(frame.regions.enumerated()), id: \.offset) { _, region in
                    Rectangle().fill(.black)
                        .frame(width: region.width * scale, height: region.height * scale)
                        .offset(x: region.minX * scale, y: region.minY * scale)
                }
                if let rect = dragRect {
                    Rectangle().fill(.black.opacity(0.6)).overlay(Rectangle().stroke(.white, lineWidth: 1))
                        .frame(width: rect.width, height: rect.height).offset(x: rect.minX, y: rect.minY)
                }
            }
            .frame(width: shown.width, height: shown.height)
            .clipped()
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 2)
                .onChanged { value in dragStart = dragStart ?? value.startLocation; dragEnd = value.location }
                .onEnded { _ in
                    if let rect = dragRect, rect.width > 2, rect.height > 2 {
                        let pixels = CGRect(x: rect.minX / scale, y: rect.minY / scale, width: rect.width / scale, height: rect.height / scale)
                            .intersection(CGRect(origin: .zero, size: size))
                        if !pixels.isNull { model.frames[model.selected].regions.append(pixels) }
                    }
                    dragStart = nil; dragEnd = nil
                })
            .offset(x: origin.x, y: origin.y)
        }
        .background(Color.black.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var dragRect: CGRect? {
        guard let a = dragStart, let b = dragEnd else { return nil }
        return CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }

    private var strip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(Array(model.frames.enumerated()), id: \.element.id) { index, frame in
                    ZStack(alignment: .bottomTrailing) {
                        Image(decorative: FrameRedaction.apply(frame.regions, to: frame.image) ?? frame.image, scale: 1)
                            .resizable().aspectRatio(contentMode: .fit).frame(height: 70)
                        if !frame.regions.isEmpty {
                            Text("\(frame.regions.count)").font(.caption2.bold()).padding(3).background(.black).foregroundStyle(.white)
                        }
                    }
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(index == model.selected ? Color.accentColor : .clear, lineWidth: 3))
                    .onTapGesture { model.selected = index }
                }
            }.padding(4)
        }.frame(height: 84)
    }
}

/// A step of the ship flow shown in its own window, which ends when the
/// user goes on (`finish(true)`) or cancels.
@MainActor
protocol ShipReviewStep: AnyObject {
    var finish: (Bool) -> Void { get set }
}

/// Shows one step in a window and returns the user's choice. Closing the
/// window cancels.
@MainActor
enum ShipReviewWindow {
    static func run(title: String, size: NSSize, step: some ShipReviewStep, content: some View) async -> Bool {
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = title
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: content)
        // A hosting controller shrinks its window to the view's smallest
        // size; ask for ours, as far as the screen has room below the title
        // bar and above the Dock.
        let room = (NSScreen.main?.visibleFrame.size).map { NSSize(width: $0.width, height: $0.height - 32) } ?? size
        window.setContentSize(NSSize(width: min(size.width, room.width), height: min(size.height, room.height)))
        window.center()
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        let closer = CloseObserver()
        let result = await withCheckedContinuation { continuation in
            var resumed = false
            step.finish = { ship in
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: ship)
            }
            closer.onClose = { step.finish(false) }
            window.delegate = closer
        }
        window.delegate = nil
        window.close()
        if !NSApp.windows.contains(where: { $0.isVisible && $0.canBecomeMain }) { NSApp.setActivationPolicy(.accessory) }
        return result
    }

    private final class CloseObserver: NSObject, NSWindowDelegate {
        var onClose: () -> Void = {}
        func windowWillClose(_ notification: Notification) { onClose() }
    }
}
