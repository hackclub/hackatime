import AppKit
import HackatimeDesktopCore
import SwiftUI

/// The first step of a ship: its minutes laid out like clips in a video
/// editor, with the timelapse frames, the apps that were in front and which
/// minutes count. The user removes what should not be in the ship, by
/// dragging over time, clicking a window's stretch, or taking out an app
/// altogether. Everything shown is read from this Mac; nothing is sent
/// until the next step.
@MainActor
final class ShipTimelineModel: ObservableObject, ShipReviewStep {
    struct FrameMark: Identifiable, Equatable {
        let id: String        // frame hash
        let position: Double  // minute index plus the fraction of the minute
    }

    @Published var timeline: ShipTimeline
    /// Selected minutes, as positions on the timeline.
    @Published var selection: ClosedRange<Int>?
    @Published var playhead: Double = 0
    /// 1 fits the whole ship in the window.
    @Published var zoom: CGFloat = 1
    @Published private(set) var thumbnails: [String: CGImage] = [:]
    let frames: [FrameMark]
    /// A colour for each app, told apart from its neighbours in the list.
    let colors: [String: Color]
    var finish: (Bool) -> Void = { _ in }

    private let loadFrame: @Sendable (String) -> CGImage?
    private var shown: (hash: String, image: CGImage)?

    /// `frames` are the vault's frames by capture time; `loadFrame`
    /// decrypts one locally.
    init(timeline: ShipTimeline, frames: [(hash: String, capturedAtMs: Int64)], loadFrame: @escaping @Sendable (String) -> CGImage?) {
        self.timeline = timeline
        self.loadFrame = loadFrame
        colors = Dictionary(uniqueKeysWithValues: timeline.apps.enumerated().map { index, app in
            // The golden angle keeps any two neighbouring hues far apart.
            (app.bundleID, Color(hue: (Double(index) * 0.618 + 0.75).truncatingRemainder(dividingBy: 1), saturation: 0.55, brightness: 0.64))
        })
        self.frames = frames.sorted { $0.capturedAtMs < $1.capturedAtMs }.compactMap { frame in
            guard let index = timeline.minutes.firstIndex(where: { $0.startMs <= frame.capturedAtMs && frame.capturedAtMs < $0.startMs + 60_000 }) else { return nil }
            return FrameMark(id: frame.hash, position: Double(index) + Double(frame.capturedAtMs - timeline.minutes[index].startMs) / 60_000)
        }
        loadThumbnails()
    }

    private func loadThumbnails() {
        let hashes = frames.map(\.id), load = loadFrame
        Task { [weak self] in
            for hash in hashes {
                // Decrypting and decoding a frame takes a few milliseconds each; keep it off the main thread.
                let image = await Task.detached(priority: .userInitiated) { load(hash).flatMap { Self.thumbnail($0) } }.value
                guard let self else { return }
                if let image { thumbnails[hash] = image }
            }
        }
    }

    nonisolated static func thumbnail(_ image: CGImage, height: Int = 96) -> CGImage? {
        let width = max(1, image.width * height / max(1, image.height))
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        context?.interpolationQuality = .medium
        context?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context?.makeImage()
    }

    var playheadIndex: Int { min(max(0, Int(playhead)), max(0, timeline.minutes.count - 1)) }

    /// The frame taken in the playhead's minute, if one was: a window that
    /// is not on the capture list, or a screen that had not changed, leaves
    /// a minute without one, and an older frame would misstate what it holds.
    var frameAtPlayhead: FrameMark? {
        frames.last { Int($0.position) == playheadIndex }
    }

    func image(for frame: FrameMark) -> CGImage? {
        if let shown, shown.hash == frame.id { return shown.image }
        guard let image = loadFrame(frame.id) else { return thumbnails[frame.id] }
        shown = (frame.id, image)
        return image
    }

    /// The window in front at the playhead.
    var windowAtPlayhead: ActivitySegment? {
        guard timeline.minutes.indices.contains(playheadIndex) else { return nil }
        let minute = timeline.minutes[playheadIndex]
        let ms = minute.startMs + Int64((playhead - Double(playheadIndex)) * 60_000)
        return minute.activity.last { $0.startMs <= ms } ?? minute.activity.first
    }

    func setSelectionRemoved(_ removed: Bool) {
        guard let selection else { return }
        timeline.setRemoved(removed, positions: selection)
    }

    var selectionIsRemoved: Bool { selection.map { $0.allSatisfy(timeline.removed.contains) } ?? false }

    func color(_ bundleID: String) -> Color { colors[bundleID] ?? .gray }
}

struct ShipTimelineView: View {
    @ObservedObject var model: ShipTimelineModel
    @State private var dragStart: Double?

    private static let labelWidth: CGFloat = 64
    private static let playheadID = "playhead"
    private static let rulerHeight: CGFloat = 22, framesHeight: CGFloat = 60, appsHeight: CGFloat = 34, countedHeight: CGFloat = 14, gap: CGFloat = 6
    private static var tracksHeight: CGFloat { rulerHeight + framesHeight + appsHeight + countedHeight + gap * 3 }
    private static let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static func time(_ ms: Int64) -> String { clock.string(from: Date(timeIntervalSince1970: Double(ms) / 1000)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Review \(model.timeline.project) before shipping").font(.title2.weight(.semibold))
                Text("This is the time the ship covers. Remove anything you do not want in it: a removed minute earns no time and nothing from it is sent. Nothing has been sent yet.")
                    .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            HStack(alignment: .top, spacing: 12) {
                viewer
                appList.frame(width: 270)
            }
            toolbar
            tracks
            footer
        }
        .padding(20)
        .frame(minWidth: 900, minHeight: 560)
    }

    // MARK: Viewer

    private var viewer: some View {
        let frame = model.frameAtPlayhead
        let removed = model.timeline.removed.contains(model.playheadIndex)
        return VStack(alignment: .leading, spacing: 6) {
            ZStack {
                Color.black.opacity(0.85)
                if let frame, let image = model.image(for: frame) {
                    Image(decorative: image, scale: 1).resizable().aspectRatio(contentMode: .fit).opacity(removed ? 0.25 : 1)
                } else if !removed {
                    Text("No new frame was taken in this minute.").foregroundStyle(.white.opacity(0.7))
                }
                if removed {
                    Label("Removed: not in the ship", systemImage: "scissors")
                        .font(.headline).padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.red.opacity(0.85), in: Capsule()).foregroundStyle(.white)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(caption).font(.callout).lineLimit(1).truncationMode(.middle)
                .accessibilityIdentifier("timeline-caption")
        }
    }

    private var caption: String {
        guard model.timeline.minutes.indices.contains(model.playheadIndex) else { return " " }
        let minute = model.timeline.minutes[model.playheadIndex]
        var parts = [Self.time(minute.startMs)]
        if let window = model.windowAtPlayhead {
            parts.append(window.app)
            if !window.title.isEmpty { parts.append(window.title) } else if window.label == .unrelated { parts.append("window not recorded") }
            if let site = window.site { parts.append(site) }
        } else {
            parts.append("nothing recorded in front")
        }
        return parts.joined(separator: "  ·  ")
    }

    // MARK: Apps

    private var appList: some View {
        let apps = model.timeline.apps
        return VStack(alignment: .leading, spacing: 6) {
            Text("Apps in this time").font(.headline)
            if apps.isEmpty {
                Text("No app history was recorded for this time. You can still drag over the timeline to remove minutes.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(apps) { app in appRow(app) }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func appRow(_ app: ShipTimeline.AppUse) -> some View {
        let gone = app.minutes.allSatisfy(model.timeline.removed.contains)
        return HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2).fill(model.color(app.bundleID)).frame(width: 4, height: 28)
            Group {
                if let icon = AppIcons.icon(app.bundleID) { Image(nsImage: icon).resizable() } else { Color.clear }
            }
            .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 0) {
                Text(app.app).lineLimit(1).strikethrough(gone)
                Text("\(Self.duration(app.seconds)) in \(app.minutes.count) minute\(app.minutes.count == 1 ? "" : "s")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Button(gone ? "Put back" : "Remove") { model.timeline.setRemoved(!gone, bundleID: app.bundleID) }
                .controlSize(.small)
                .help(gone ? "Put every minute with \(app.app) back in the ship" : "Remove every minute \(app.app) was in front in")
        }
        .padding(.vertical, 3).padding(.horizontal, 4)
        .opacity(gone ? 0.6 : 1)
    }

    static func duration(_ seconds: Int) -> String {
        seconds < 60 ? "\(seconds) s" : seconds < 3600 ? "\(seconds / 60) min" : "\(seconds / 3600) h \(seconds % 3600 / 60) min"
    }

    // MARK: Toolbar and footer

    private var toolbar: some View {
        HStack(spacing: 10) {
            Button { model.setSelectionRemoved(true) } label: { Label("Remove from ship", systemImage: "scissors") }
                .disabled(model.selection == nil || model.selectionIsRemoved)
                .keyboardShortcut(.delete, modifiers: [])
            Button { model.setSelectionRemoved(false) } label: { Label("Put back", systemImage: "arrow.uturn.backward") }
                .disabled(model.selection == nil || !model.selection!.contains(where: model.timeline.removed.contains))
            Text(selectionText).font(.callout).foregroundStyle(.secondary)
            Spacer()
            Image(systemName: "minus.magnifyingglass").foregroundStyle(.secondary)
            Slider(value: $model.zoom, in: 1 ... 40).frame(width: 140).accessibilityLabel("Zoom")
            Image(systemName: "plus.magnifyingglass").foregroundStyle(.secondary)
        }
    }

    private var selectionText: String {
        guard let selection = model.selection, model.timeline.minutes.indices.contains(selection.upperBound) else {
            return "Drag over the timeline to select time, or click a window on the Apps track."
        }
        let minutes = model.timeline.minutes
        return "\(Self.time(minutes[selection.lowerBound].startMs)) to \(Self.time(minutes[selection.upperBound].startMs + 60_000))  ·  \(selection.count) min selected"
    }

    private var footer: some View {
        let timeline = model.timeline
        let counted = timeline.minutes.filter(\.counts).count
        return HStack {
            Text("\(timeline.minutes.count) minutes, \(counted) of them count towards \(timeline.project). You removed \(timeline.removed.count); \(timeline.keptCountedMinutes) counted minutes will be shipped.")
                .font(.callout).foregroundStyle(.secondary).accessibilityIdentifier("timeline-summary")
            Spacer()
            Button("Cancel") { model.finish(false) }.keyboardShortcut(.cancelAction)
            Button("Continue") { model.finish(true) }.keyboardShortcut(.defaultAction)
                .disabled(timeline.keptCountedMinutes == 0)
                .help(timeline.keptCountedMinutes == 0 ? "Nothing that counts is left in the ship" : "Ask the server which frames it needs")
        }
    }

    // MARK: Tracks

    private var tracks: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Color.clear.frame(height: Self.rulerHeight + Self.gap)
                Text("Frames").frame(height: Self.framesHeight + Self.gap, alignment: .leading)
                Text("Apps").frame(height: Self.appsHeight + Self.gap, alignment: .leading)
                Text("Counts").frame(height: Self.countedHeight, alignment: .leading)
            }
            .font(.caption).foregroundStyle(.secondary).frame(width: Self.labelWidth, alignment: .leading)
            GeometryReader { geometry in
                let count = max(1, model.timeline.minutes.count)
                // Zooming stops where the canvas would get too wide to draw.
                let fit = geometry.size.width / CGFloat(count)
                let cell = max(fit, min(140, fit * model.zoom, 16_000 / CGFloat(count)))
                let width = max(geometry.size.width, cell * CGFloat(count))
                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        Canvas { context, size in draw(&context, size: size, cell: cell) }
                            .frame(width: width, height: Self.tracksHeight)
                            .contentShape(Rectangle())
                            .gesture(DragGesture(minimumDistance: 0)
                                .onChanged { value in drag(value, cell: cell, ended: false) }
                                .onEnded { value in drag(value, cell: cell, ended: true) })
                            .accessibilityIdentifier("timeline-tracks")
                            // Marks where the playhead is, for zooming to stay on it.
                            .overlay(alignment: .topLeading) {
                                Color.clear.frame(width: 1, height: 1).id(Self.playheadID).padding(.leading, CGFloat(model.playhead) * cell)
                            }
                    }
                    .onChange(of: model.zoom) {
                        DispatchQueue.main.async { proxy.scrollTo(Self.playheadID, anchor: .center) }
                    }
                }
            }
            .frame(height: Self.tracksHeight + 14)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
        }
    }

    private func position(_ x: CGFloat, cell: CGFloat) -> Double {
        min(max(0, Double(x / cell)), Double(model.timeline.minutes.count) - 0.0001)
    }

    private func drag(_ value: DragGesture.Value, cell: CGFloat, ended: Bool) {
        let start = dragStart ?? position(value.startLocation.x, cell: cell)
        let now = position(value.location.x, cell: cell)
        dragStart = ended ? nil : start
        model.playhead = now
        let moved = abs(value.translation.width) > 3
        if moved {
            model.selection = Int(min(start, now)) ... Int(max(start, now))
        } else if ended {
            // A click on the Apps track selects the window under it, as far as it stays in front.
            let appsTop = Self.rulerHeight + Self.framesHeight + Self.gap * 2
            let onApps = value.location.y >= appsTop && value.location.y <= appsTop + Self.appsHeight
            model.selection = onApps ? model.timeline.positions(ofWindowAt: now) : nil
        }
    }

    private func draw(_ context: inout GraphicsContext, size: CGSize, cell: CGFloat) {
        let minutes = model.timeline.minutes
        let framesTop = Self.rulerHeight + Self.gap
        let appsTop = framesTop + Self.framesHeight + Self.gap
        let countedTop = appsTop + Self.appsHeight + Self.gap

        // Ruler: a label wherever there is room, and at every break in time.
        let step = [1, 2, 5, 10, 15, 30, 60, 120, 240].first { CGFloat($0) * cell >= 56 } ?? 480
        var lastLabel: CGFloat = -.infinity
        for (index, minute) in minutes.enumerated() {
            let x = CGFloat(index) * cell
            let breaks = index > 0 && minute.startMs - minutes[index - 1].startMs > 60_000
            if breaks {
                context.stroke(Path { $0.move(to: CGPoint(x: x, y: 0)); $0.addLine(to: CGPoint(x: x, y: size.height)) },
                               with: .color(.primary.opacity(0.35)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
            guard breaks || index % step == 0, x - lastLabel >= 44 else { continue }
            lastLabel = x
            context.fill(Path(CGRect(x: x, y: Self.rulerHeight - 6, width: 1, height: 6)), with: .color(.primary.opacity(0.4)))
            context.draw(Text(Self.time(minute.startMs)).font(.caption2).foregroundColor(.secondary), at: CGPoint(x: x + 3, y: 7), anchor: .leading)
        }

        // Frames: a tick for each, and a thumbnail wherever one fits.
        context.fill(Path(roundedRect: CGRect(x: 0, y: framesTop, width: size.width, height: Self.framesHeight), cornerRadius: 4), with: .color(.black.opacity(0.35)))
        var nextFree: CGFloat = 0
        for frame in model.frames {
            let x = CGFloat(frame.position) * cell
            context.fill(Path(CGRect(x: x, y: framesTop + Self.framesHeight - 3, width: 1.5, height: 3)), with: .color(.white.opacity(0.8)))
            guard x >= nextFree else { continue }
            let image = model.thumbnails[frame.id]
            let width = image.map { CGFloat($0.width) / CGFloat($0.height) * (Self.framesHeight - 8) } ?? 76
            let rect = CGRect(x: x, y: framesTop + 3, width: width, height: Self.framesHeight - 8)
            if let image {
                context.draw(Image(decorative: image, scale: 1), in: rect)
            } else {
                context.fill(Path(rect), with: .color(.white.opacity(0.12)))
            }
            nextFree = x + width + 2
        }

        // Apps: one block per window in front, joined while the app stays the same.
        var run: (bundleID: String, app: String, from: CGFloat, to: CGFloat)?
        func flush() {
            guard let block = run else { return }
            let rect = CGRect(x: block.from, y: appsTop, width: max(1, block.to - block.from), height: Self.appsHeight)
            context.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(model.color(block.bundleID)))
            if rect.width >= 46 {
                var inner = context
                inner.clip(to: Path(rect))
                inner.draw(Text(block.app).font(.caption).foregroundColor(.white), at: CGPoint(x: rect.minX + 6, y: rect.midY), anchor: .leading)
            }
            run = nil
        }
        for (index, minute) in minutes.enumerated() {
            for segment in minute.activity {
                let from = (CGFloat(index) + CGFloat(segment.startMs - minute.startMs) / 60_000) * cell
                let to = (CGFloat(index) + CGFloat(segment.endMs - minute.startMs) / 60_000) * cell
                if let block = run, block.bundleID == segment.bundleID, from - block.to < 1.5 {
                    run = (block.bundleID, block.app, block.from, to)
                } else {
                    flush()
                    run = (segment.bundleID, segment.app, from, to)
                }
            }
        }
        flush()

        // Counts: which minutes earn time on this project.
        for (index, minute) in minutes.enumerated() {
            let rect = CGRect(x: CGFloat(index) * cell, y: countedTop, width: max(1, cell - (cell > 4 ? 1 : 0)), height: Self.countedHeight)
            context.fill(Path(rect), with: .color(minute.counts ? Color.green.opacity(0.75) : Color.primary.opacity(0.15)))
        }

        // Removed minutes are struck out across every track.
        for index in model.timeline.removed.sorted() {
            let rect = CGRect(x: CGFloat(index) * cell, y: framesTop - 2, width: cell, height: size.height - framesTop + 2)
            context.fill(Path(rect), with: .color(Color(nsColor: .windowBackgroundColor).opacity(0.72)))
            var hatch = context
            hatch.clip(to: Path(rect))
            var lines = Path()
            var x = rect.minX - rect.height
            while x < rect.maxX {
                lines.move(to: CGPoint(x: x, y: rect.maxY)); lines.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
                x += 7
            }
            hatch.stroke(lines, with: .color(.red.opacity(0.75)), lineWidth: 1)
        }

        if let selection = model.selection {
            let rect = CGRect(x: CGFloat(selection.lowerBound) * cell, y: 1, width: CGFloat(selection.count) * cell, height: size.height - 2)
            // Light enough that a removed stretch still shows through.
            context.fill(Path(rect), with: .color(Color.accentColor.opacity(0.12)))
            context.stroke(Path(rect), with: .color(.accentColor), lineWidth: 1.5)
        }

        let x = CGFloat(model.playhead) * cell
        context.fill(Path(CGRect(x: x - 0.75, y: 0, width: 1.5, height: size.height)), with: .color(.primary))
        context.fill(Path { $0.move(to: CGPoint(x: x - 5, y: 0)); $0.addLine(to: CGPoint(x: x + 5, y: 0)); $0.addLine(to: CGPoint(x: x, y: 7)); $0.closeSubpath() },
                     with: .color(.primary))
    }
}

/// The icon of each app on the timeline, when it is installed here.
@MainActor
enum AppIcons {
    private static var icons: [String: NSImage?] = [:]

    static func icon(_ bundleID: String) -> NSImage? {
        if let cached = icons[bundleID] { return cached }
        let icon = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID).map { NSWorkspace.shared.icon(forFile: $0.path) }
        icons[bundleID] = icon
        return icon
    }
}
