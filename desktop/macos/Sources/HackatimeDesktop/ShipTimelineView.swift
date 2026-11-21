import AppKit
import HackatimeDesktopCore
import SwiftUI
import UniformTypeIdentifiers

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

    /// The frame on show at the playhead: the last one taken in its minute
    /// up to there, else that minute's first. A window that is not on the
    /// capture list, or a screen that had not changed, leaves a minute
    /// without one, and an older frame would misstate what it holds.
    var frameAtPlayhead: FrameMark? {
        let taken = frames.filter { Int($0.position) == playheadIndex }
        return taken.last { $0.position <= playhead } ?? taken.first
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

    /// Whether every minute a secrets file was in front in is still out of the ship.
    var secretsAreRemoved: Bool { timeline.secretMinutes.allSatisfy(timeline.removed.contains) }

    func color(_ bundleID: String) -> Color { colors[bundleID] ?? .gray }
}

struct ShipTimelineView: View {
    @ObservedObject var model: ShipTimelineModel
    @State private var dragStart: Double?
    @State private var resize: Resize?
    /// How far the tracks are scrolled, so a clip's name stays in view while the clip does.
    @State private var scrolled: CGFloat = 0

    /// The tracks, stacked without gaps like the lanes of an editor.
    private enum Lane {
        static let headerWidth: CGFloat = 92
        static let ruler: CGFloat = 26, frames: CGFloat = 66, apps: CGFloat = 54, counts: CGFloat = 24
        static let framesTop = ruler, appsTop = ruler + frames, countsTop = ruler + frames + apps
        static let height = ruler + frames + apps + counts
        /// Room for the scroll bar under the lanes.
        static let scroller: CGFloat = 14
        /// How far a clip sits inside its lane, and the height of its title strip.
        static let inset: CGFloat = 5, clipTitle: CGFloat = 18
    }

    private static let playheadID = "playhead"

    /// One end of a removed stretch, which a drag moves.
    private struct Handle {
        let run: ClosedRange<Int>
        let movesEnd: Bool
    }

    /// A removed stretch being resized: the timeline as it was when the drag
    /// began, the handle taken hold of, and the end that stays where it is.
    private struct Resize {
        let from: ShipTimeline
        let handle: Handle
        var anchor: Int { handle.movesEnd ? handle.run.lowerBound : handle.run.upperBound }
    }
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
            secretsNote
            HStack(alignment: .top, spacing: 12) {
                viewer
                appList.frame(width: 290)
            }
            toolbar
            tracks
            footer
        }
        .padding(20)
        .frame(minWidth: 900, minHeight: 600)
    }

    // MARK: Secrets files

    /// Says which minutes the app took out by itself, and lets the user overrule it.
    @ViewBuilder private var secretsNote: some View {
        let minutes = model.timeline.secretMinutes
        if !minutes.isEmpty {
            let removed = model.secretsAreRemoved
            let count = "\(minutes.count) minute\(minutes.count == 1 ? "" : "s")"
            let files = model.timeline.secretFiles.prefix(3).joined(separator: ", ") + (model.timeline.secretFiles.count > 3 ? " and others" : "")
            HStack(spacing: 10) {
                Image(systemName: removed ? "lock.fill" : "lock.open.fill").foregroundStyle(removed ? Color.green : Color.orange)
                Text(removed
                    ? "Hackatime already removed \(count): a secrets file (\(files)) was in front, and a frame could show what is in it."
                    : "\(count.prefix(1).uppercased() + count.dropFirst()) with a secrets file (\(files)) in front \(minutes.count == 1 ? "is" : "are") back in the ship. Check the frames in the next step.")
                    .font(.callout).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Button(removed ? "Put back" : "Remove again") { model.timeline.setRemoved(!removed, positions: minutes) }
                    .controlSize(.small)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background((removed ? Color.green : Color.orange).opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder((removed ? Color.green : Color.orange).opacity(0.35)))
            .accessibilityIdentifier("timeline-secrets")
        }
    }

    // MARK: Viewer

    private var viewer: some View {
        let frame = model.frameAtPlayhead
        let removed = model.timeline.removed.contains(model.playheadIndex)
        return VStack(alignment: .leading, spacing: 6) {
            ZStack {
                Color(white: 0.08)
                if let frame, let image = model.image(for: frame) {
                    Image(decorative: image, scale: 1).resizable().aspectRatio(contentMode: .fit).opacity(removed ? 0.25 : 1)
                } else if !removed {
                    Text("No new frame was taken in this minute.").foregroundStyle(.white.opacity(0.7))
                }
                if removed {
                    Label("Removed: not in the ship", systemImage: "scissors")
                        .font(.headline).padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.red.opacity(0.85), in: Capsule()).foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.black.opacity(0.5)))
            .shadow(color: .black.opacity(0.22), radius: 5, y: 2)
            caption.font(.callout).lineLimit(1).truncationMode(.middle)
                .accessibilityIdentifier("timeline-caption")
        }
    }

    /// The time, the app in bold and the window in front at the playhead.
    private var caption: Text {
        guard model.timeline.minutes.indices.contains(model.playheadIndex) else { return Text(" ") }
        let time = Text(Self.time(model.timeline.minutes[model.playheadIndex].startMs)).monospacedDigit()
        let divider = Text("  ·  ").foregroundStyle(.tertiary)
        guard let window = model.windowAtPlayhead else { return time + divider + Text("nothing recorded in front").foregroundStyle(.secondary) }
        var text = time + divider + Text(window.app).fontWeight(.bold)
        text = text + divider + Text(Self.windowName(title: window.title, site: nil)).foregroundStyle(window.title.isEmpty ? .secondary : .primary)
        if let site = window.site { text = text + divider + Text(site).foregroundStyle(.secondary) }
        return text
    }

    /// What to call a window: its title, else its site, else that it was not recorded.
    static func windowName(title: String, site: String?) -> String {
        !title.isEmpty ? title : site ?? "window title not recorded"
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
                    VStack(spacing: 6) {
                        ForEach(apps) { app in appRow(app) }
                    }
                    .padding(.bottom, 4).padding(.horizontal, 1)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func appRow(_ app: ShipTimeline.AppUse) -> some View {
        let gone = app.minutes.allSatisfy(model.timeline.removed.contains)
        return HStack(alignment: .top, spacing: 9) {
            Image(nsImage: AppIcons.icon(app.bundleID)).resizable().frame(width: 30, height: 30)
                .shadow(color: .black.opacity(0.25), radius: 1.5, y: 1)
            VStack(alignment: .leading, spacing: 1) {
                Text(app.app).fontWeight(.bold).lineLimit(1).strikethrough(gone)
                Text("\(Self.duration(app.seconds)) in \(app.minutes.count) minute\(app.minutes.count == 1 ? "" : "s")")
                    .font(.caption).foregroundStyle(.secondary)
                // Its windows, the longest in front first.
                ForEach(Array(app.windows.prefix(3).enumerated()), id: \.offset) { _, window in
                    HStack(spacing: 4) {
                        Text(Self.windowName(title: window.title, site: window.site)).lineLimit(1).truncationMode(.middle)
                            .italic(window.title.isEmpty && window.site == nil)
                        Spacer(minLength: 2)
                        Text(Self.duration(window.seconds)).monospacedDigit().foregroundStyle(.tertiary)
                    }
                    .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.top, 1)
                if app.windows.count > 3 {
                    Text("and \(app.windows.count - 3) more window\(app.windows.count == 4 ? "" : "s")").font(.caption).foregroundStyle(.tertiary)
                }
            }
            Button(gone ? "Put back" : "Remove") { model.timeline.setRemoved(!gone, bundleID: app.bundleID) }
                .controlSize(.small)
                .help(gone ? "Put every minute with \(app.app) back in the ship" : "Remove every minute \(app.app) was in front in")
        }
        .padding(.vertical, 7).padding(.leading, 12).padding(.trailing, 8)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        // The app's colour on the Apps track, down the card's edge.
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 8).fill(model.color(app.bundleID)).frame(width: 5)
        }
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.1)))
        .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
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
            return "Drag to select time, click a window, or drag the ends of a removed stretch."
        }
        let minutes = model.timeline.minutes
        return "\(Self.time(minutes[selection.lowerBound].startMs)) to \(Self.time(minutes[selection.upperBound].startMs + 60_000))  ·  \(selection.count) min selected"
    }

    private var footer: some View {
        let timeline = model.timeline
        let counted = timeline.minutes.filter(\.counts).count
        return HStack {
            Text("\(timeline.minutes.count) minutes, \(counted) of them count towards \(timeline.project). \(timeline.removed.count) removed; \(timeline.keptCountedMinutes) counted minutes will be shipped.")
                .font(.callout).foregroundStyle(.secondary).accessibilityIdentifier("timeline-summary")
            Spacer()
            Button("Cancel") { model.finish(false) }.keyboardShortcut(.cancelAction)
            Button("Continue") { model.finish(true) }.keyboardShortcut(.defaultAction)
                .disabled(timeline.keptCountedMinutes == 0)
                .help(timeline.keptCountedMinutes == 0 ? "Nothing that counts is left in the ship" : "Ask the server which frames it needs")
        }
    }

    // MARK: Tracks

    /// The tracks sit in a dark well whatever the system appearance, as an
    /// editor's timeline does: raised lane headers on the left, and clips
    /// lying in recessed lanes under the ruler.
    private var tracks: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 0) {
                laneHeader("Time", symbol: "clock", height: Lane.ruler)
                laneHeader("Frames", symbol: "film", height: Lane.frames)
                laneHeader("Apps", symbol: "macwindow.on.rectangle", height: Lane.apps)
                laneHeader("Counts", symbol: "checkmark.seal.fill", height: Lane.counts)
                Color(white: 0.17).frame(height: Lane.scroller)
            }
            .frame(width: Lane.headerWidth)
            // The header column stands above the lanes and shades their left edge.
            .zIndex(1)
            .shadow(color: .black.opacity(0.55), radius: 4, x: 2)
            GeometryReader { geometry in
                let count = max(1, model.timeline.minutes.count)
                // Zooming stops where the canvas would get too wide to draw.
                let fit = geometry.size.width / CGFloat(count)
                let cell = max(fit, min(140, fit * model.zoom, 16_000 / CGFloat(count)))
                let width = max(geometry.size.width, cell * CGFloat(count))
                // Read here, not while drawing, so that scrolling redraws the canvas.
                let visibleFrom = scrolled
                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        Canvas { context, size in draw(&context, size: size, cell: cell, visibleFrom: visibleFrom) }
                            .frame(width: width, height: Lane.height)
                            .background(ScrollOffsetReader { scrolled = max(0, $0) })
                            .contentShape(Rectangle())
                            .gesture(DragGesture(minimumDistance: 0)
                                .onChanged { value in drag(value, cell: cell, ended: false) }
                                .onEnded { value in drag(value, cell: cell, ended: true) })
                            .onContinuousHover { phase in
                                if case let .active(point) = phase, handle(at: point, cell: cell) != nil {
                                    NSCursor.resizeLeftRight.set()
                                } else {
                                    NSCursor.arrow.set()
                                }
                            }
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
        }
        .frame(height: Lane.height + Lane.scroller)
        .background(Color(white: 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.black.opacity(0.6)))
        .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
        .environment(\.colorScheme, .dark)
    }

    /// A raised panel naming a lane: lit along its top edge, dark along its bottom.
    private func laneHeader(_ title: String, symbol: String, height: CGFloat) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.5)).frame(width: 15)
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.9))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .frame(height: height)
        .background(LinearGradient(colors: [Color(white: 0.29), Color(white: 0.2)], startPoint: .top, endPoint: .bottom))
        .overlay(alignment: .top) { Color.white.opacity(0.14).frame(height: 1) }
        .overlay(alignment: .bottom) { Color.black.opacity(0.65).frame(height: 1) }
    }

    private func position(_ x: CGFloat, cell: CGFloat) -> Double {
        min(max(0, Double(x / cell)), Double(model.timeline.minutes.count) - 0.0001)
    }

    /// The handle of a removed stretch under a point, if there is one.
    private func handle(at point: CGPoint, cell: CGFloat) -> Handle? {
        guard point.y >= Lane.ruler else { return nil }
        let handles = model.timeline.removedRuns.flatMap { run in
            [(Handle(run: run, movesEnd: false), CGFloat(run.lowerBound) * cell), (Handle(run: run, movesEnd: true), CGFloat(run.upperBound + 1) * cell)]
        }
        guard let nearest = handles.min(by: { abs($0.1 - point.x) < abs($1.1 - point.x) }), abs(nearest.1 - point.x) <= 6 else { return nil }
        return nearest.0
    }

    /// Moves the end of a removed stretch to the minute boundary nearest the
    /// pointer. The stretch keeps at least its last minute; Put back removes it.
    private func resize(_ resize: Resize, to x: CGFloat, cell: CGFloat) {
        let edge = min(max(0, Int((x / cell).rounded())), model.timeline.minutes.count)
        let range = resize.handle.movesEnd ? resize.anchor ... max(resize.anchor, edge - 1) : min(resize.anchor, edge) ... resize.anchor
        var timeline = resize.from
        timeline.setRemoved(false, positions: resize.handle.run)
        timeline.setRemoved(true, positions: range)
        model.timeline = timeline
        model.selection = nil
        model.playhead = Double(resize.handle.movesEnd ? range.upperBound : range.lowerBound)
    }

    private func drag(_ value: DragGesture.Value, cell: CGFloat, ended: Bool) {
        if dragStart == nil, resize == nil, let handle = handle(at: value.startLocation, cell: cell) {
            resize = Resize(from: model.timeline, handle: handle)
        }
        if let resize {
            if abs(value.translation.width) > 3 { self.resize(resize, to: value.location.x, cell: cell) }
            if ended { self.resize = nil }
            return
        }
        let start = dragStart ?? position(value.startLocation.x, cell: cell)
        let now = position(value.location.x, cell: cell)
        dragStart = ended ? nil : start
        model.playhead = now
        let moved = abs(value.translation.width) > 3
        if moved {
            model.selection = Int(min(start, now)) ... Int(max(start, now))
        } else if ended {
            // A click on the Apps track selects the window under it, as far as it stays in front.
            let onApps = value.location.y >= Lane.appsTop && value.location.y <= Lane.countsTop
            model.selection = onApps ? model.timeline.positions(ofWindowAt: now) : nil
        }
    }

    // MARK: Drawing

    private func draw(_ context: inout GraphicsContext, size: CGSize, cell: CGFloat, visibleFrom: CGFloat) {
        drawLanes(context, size: size)
        drawRuler(context, size: size, cell: cell)
        drawFrames(context, cell: cell)
        drawApps(context, cell: cell, visibleFrom: visibleFrom)
        drawCounts(context, size: size, cell: cell)
        drawRemoved(context, size: size, cell: cell, visibleFrom: visibleFrom)
        if let selection = model.selection {
            let rect = CGRect(x: CGFloat(selection.lowerBound) * cell, y: 1, width: CGFloat(selection.count) * cell, height: size.height - 2)
            // Light enough that a removed stretch still shows through.
            context.fill(Path(rect), with: .color(Color.accentColor.opacity(0.16)))
            context.stroke(Path(roundedRect: rect.insetBy(dx: 0.75, dy: 0), cornerRadius: 2), with: .color(Color.accentColor), lineWidth: 1.5)
        }
        drawPlayhead(context, size: size, cell: cell)
    }

    private static func vertical(_ colors: [Color], _ rect: CGRect) -> GraphicsContext.Shading {
        .linearGradient(Gradient(colors: colors), startPoint: CGPoint(x: rect.midX, y: rect.minY), endPoint: CGPoint(x: rect.midX, y: rect.maxY))
    }

    /// One line of text inside a rectangle, cut off where it ends.
    private func label(_ context: GraphicsContext, _ text: Text, in rect: CGRect) {
        guard rect.width >= 12 else { return }
        var inner = context
        inner.clip(to: Path(rect))
        let resolved = inner.resolve(text)
        let height = resolved.measure(in: CGSize(width: CGFloat.greatestFiniteMagnitude, height: rect.height)).height
        inner.draw(resolved, in: CGRect(x: rect.minX, y: rect.midY - height / 2, width: rect.width, height: height))
    }

    /// The lanes are sunk into the well: each is shaded under its upper edge
    /// and closed by a dark line with a faint light one beneath.
    private func drawLanes(_ context: GraphicsContext, size: CGSize) {
        for (top, height, shade) in [(Lane.framesTop, Lane.frames, 0.115), (Lane.appsTop, Lane.apps, 0.15), (Lane.countsTop, Lane.counts, 0.115)] {
            let lane = CGRect(x: 0, y: top, width: size.width, height: height)
            context.fill(Path(lane), with: .color(Color(white: shade)))
            let shadow = CGRect(x: 0, y: top, width: size.width, height: 7)
            context.fill(Path(shadow), with: Self.vertical([.black.opacity(0.45), .clear], shadow))
            context.fill(Path(CGRect(x: 0, y: lane.maxY - 1, width: size.width, height: 1)), with: .color(.black.opacity(0.7)))
        }
    }

    /// The ruler: a tick a minute where they fit, and a time wherever there
    /// is room and at every break in time.
    private func drawRuler(_ context: GraphicsContext, size: CGSize, cell: CGFloat) {
        let minutes = model.timeline.minutes
        let bar = CGRect(x: 0, y: 0, width: size.width, height: Lane.ruler)
        context.fill(Path(bar), with: Self.vertical([Color(white: 0.27), Color(white: 0.18)], bar))
        context.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: 1)), with: .color(.white.opacity(0.14)))
        context.fill(Path(CGRect(x: 0, y: Lane.ruler - 1, width: size.width, height: 1)), with: .color(.black.opacity(0.75)))

        let step = [1, 2, 5, 10, 15, 30, 60, 120, 240].first { CGFloat($0) * cell >= 56 } ?? 480
        var lastLabel: CGFloat = -.infinity
        for (index, minute) in minutes.enumerated() {
            let x = CGFloat(index) * cell
            let breaks = index > 0 && minute.startMs - minutes[index - 1].startMs > 60_000
            if breaks {
                // Time is missing here: a seam through every lane.
                context.fill(Path(CGRect(x: x - 1.5, y: Lane.ruler, width: 3, height: size.height - Lane.ruler)), with: .color(.black.opacity(0.75)))
                context.stroke(Path { $0.move(to: CGPoint(x: x, y: 0)); $0.addLine(to: CGPoint(x: x, y: size.height)) },
                               with: .color(.white.opacity(0.45)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
            if breaks || index % step == 0, x - lastLabel >= 44 {
                lastLabel = x
                context.fill(Path(CGRect(x: x, y: Lane.ruler - 10, width: 1, height: 9)), with: .color(.white.opacity(0.55)))
                context.fill(Path(CGRect(x: x, y: Lane.ruler, width: 1, height: size.height - Lane.ruler)), with: .color(.white.opacity(0.045)))
                context.draw(Text(Self.time(minute.startMs)).font(.caption2.weight(.medium).monospacedDigit()).foregroundColor(.white.opacity(0.78)),
                             at: CGPoint(x: x + 4, y: 9), anchor: .leading)
            } else if cell >= 5 {
                context.fill(Path(CGRect(x: x, y: Lane.ruler - 5, width: 1, height: 4)), with: .color(.white.opacity(0.22)))
            }
        }
    }

    /// Frames: a tick for each, and a thumbnail wherever one fits, lying on
    /// the lane like a slide with its own shadow.
    private func drawFrames(_ context: GraphicsContext, cell: CGFloat) {
        let height = Lane.frames - Lane.inset * 2 - 3
        var nextFree: CGFloat = 0
        for frame in model.frames {
            let x = CGFloat(frame.position) * cell
            context.fill(Path(CGRect(x: x, y: Lane.appsTop - 5, width: 1.5, height: 4)), with: .color(.white.opacity(0.7)))
            guard x >= nextFree else { continue }
            let image = model.thumbnails[frame.id]
            let width = image.map { CGFloat($0.width) / CGFloat($0.height) * height } ?? 76
            let rect = CGRect(x: x, y: Lane.framesTop + Lane.inset, width: width, height: height)
            let shape = Path(roundedRect: rect, cornerRadius: 3)
            context.fill(Path(roundedRect: rect.offsetBy(dx: 0, dy: 2), cornerRadius: 3), with: .color(.black.opacity(0.55)))
            if let image {
                var inner = context
                inner.clip(to: shape)
                inner.draw(Image(decorative: image, scale: 1), in: rect)
            } else {
                context.fill(shape, with: .color(.white.opacity(0.12)))
            }
            context.stroke(Path(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 3), with: .color(.white.opacity(0.3)), lineWidth: 1)
            nextFree = x + width + 3
        }
    }

    /// A stretch one app stayed in front, with the windows it showed.
    private struct AppClip {
        let bundleID: String, app: String
        let from: CGFloat
        var to: CGFloat
        var windows: [(segment: ActivitySegment, from: CGFloat, to: CGFloat)]
    }

    private func appClips(cell: CGFloat) -> [AppClip] {
        var clips: [AppClip] = []
        for (index, minute) in model.timeline.minutes.enumerated() {
            for segment in minute.activity {
                let from = (CGFloat(index) + CGFloat(segment.startMs - minute.startMs) / 60_000) * cell
                let to = (CGFloat(index) + CGFloat(segment.endMs - minute.startMs) / 60_000) * cell
                if let last = clips.indices.last, clips[last].bundleID == segment.bundleID, from - clips[last].to < 1.5 {
                    clips[last].to = to
                    let window = clips[last].windows.count - 1
                    if clips[last].windows[window].segment.sameWindow(as: segment) {
                        clips[last].windows[window].to = to
                    } else {
                        clips[last].windows.append((segment, from, to))
                    }
                } else {
                    clips.append(AppClip(bundleID: segment.bundleID, app: segment.app, from: from, to: to, windows: [(segment, from, to)]))
                }
            }
        }
        return clips
    }

    /// Apps: a clip for each stretch an app stayed in front. Its title strip
    /// carries the icon and the name; under it lie the windows it showed,
    /// each with its title.
    private func drawApps(_ context: GraphicsContext, cell: CGFloat, visibleFrom: CGFloat) {
        for clip in appClips(cell: cell) {
            let rect = CGRect(x: clip.from, y: Lane.appsTop + Lane.inset, width: max(1.5, clip.to - clip.from - (clip.to - clip.from > 6 ? 1 : 0)),
                              height: Lane.apps - Lane.inset * 2 - 2)
            let radius = min(5, rect.width / 2)
            let shape = Path(roundedRect: rect, cornerRadius: radius)
            // The clip's shadow on the lane, then its body, lit from above.
            context.fill(Path(roundedRect: rect.offsetBy(dx: 0, dy: 2), cornerRadius: radius), with: .color(.black.opacity(0.55)))
            context.fill(shape, with: .color(model.color(clip.bundleID)))
            context.fill(shape, with: Self.vertical([.white.opacity(0.2), .clear, .black.opacity(0.2)], rect))

            var inner = context
            inner.clip(to: shape)
            let strip = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: Lane.clipTitle)
            inner.fill(Path(strip), with: .color(.black.opacity(0.3)))
            inner.fill(Path(CGRect(x: rect.minX, y: strip.maxY, width: rect.width, height: 1)), with: .color(.black.opacity(0.3)))
            inner.fill(Path(CGRect(x: rect.minX, y: rect.minY + 1, width: rect.width, height: 1)), with: .color(.white.opacity(0.28)))

            if rect.width >= 22 {
                // The icon and name follow the clip's visible part when its start is scrolled away.
                let lead = min(max(rect.minX, visibleFrom), rect.maxX - 22)
                inner.draw(Image(nsImage: AppIcons.icon(clip.bundleID)), in: CGRect(x: lead + 4, y: strip.midY - 7, width: 14, height: 14))
                label(inner, Text(clip.app).font(.caption.weight(.bold)).foregroundColor(.white),
                      in: CGRect(x: lead + 22, y: strip.minY, width: rect.maxX - lead - 26, height: strip.height))
            }
            for (index, window) in clip.windows.enumerated() {
                let body = CGRect(x: window.from, y: strip.maxY + 1, width: min(window.to, rect.maxX) - window.from, height: rect.maxY - strip.maxY - 1)
                if index > 0 {
                    // Where the app changed windows.
                    inner.fill(Path(CGRect(x: body.minX - 0.5, y: body.minY, width: 1, height: body.height)), with: .color(.black.opacity(0.4)))
                    inner.fill(Path(CGRect(x: body.minX + 0.5, y: body.minY, width: 1, height: body.height)), with: .color(.white.opacity(0.15)))
                }
                let segment = window.segment
                let named = !segment.title.isEmpty || segment.site != nil
                var title = Text(Self.windowName(title: segment.title, site: segment.site)).foregroundColor(.white.opacity(named ? 0.95 : 0.6))
                if !named { title = title.italic() }
                if segment.secretFile != nil { title = Text(Image(systemName: "lock.fill")).foregroundColor(.white) + Text(" ") + title }
                let lead = min(max(body.minX, visibleFrom), body.maxX)
                label(inner, title.font(.caption2), in: CGRect(x: lead + 6, y: body.minY, width: body.maxX - lead - 12, height: body.height))
            }
            context.stroke(Path(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), cornerRadius: radius), with: .color(.black.opacity(0.5)), lineWidth: 1)
        }
    }

    /// Counts: a groove along the lane, with a raised bar over every stretch
    /// of minutes that earns time on this project.
    private func drawCounts(_ context: GraphicsContext, size: CGSize, cell: CGFloat) {
        let minutes = model.timeline.minutes
        let groove = CGRect(x: 0, y: Lane.countsTop + Lane.counts / 2 - 3.5, width: size.width, height: 6)
        context.fill(Path(groove), with: .color(.black.opacity(0.5)))
        context.fill(Path(CGRect(x: 0, y: groove.maxY, width: size.width, height: 1)), with: .color(.white.opacity(0.06)))
        var index = 0
        while index < minutes.count {
            guard minutes[index].counts else { index += 1; continue }
            var end = index
            while end + 1 < minutes.count, minutes[end + 1].counts, minutes[end + 1].startMs - minutes[end].startMs <= 60_000 { end += 1 }
            let rect = CGRect(x: CGFloat(index) * cell, y: Lane.countsTop + 6, width: max(1.5, CGFloat(end - index + 1) * cell - (cell > 4 ? 1 : 0)),
                              height: Lane.counts - 13)
            let radius = min(3.5, rect.width / 2)
            context.fill(Path(roundedRect: rect.offsetBy(dx: 0, dy: 1.5), cornerRadius: radius), with: .color(.black.opacity(0.55)))
            context.fill(Path(roundedRect: rect, cornerRadius: radius),
                         with: Self.vertical([Color(red: 0.45, green: 0.9, blue: 0.52), Color(red: 0.16, green: 0.6, blue: 0.27)], rect))
            context.stroke(Path(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), cornerRadius: radius), with: .color(.black.opacity(0.35)), lineWidth: 1)
            index = end + 1
        }
    }

    /// Removed minutes are struck out across every lane and marked on the
    /// ruler. Each stretch says how long it is and has a handle at either
    /// end to drag it longer or shorter.
    private func drawRemoved(_ context: GraphicsContext, size: CGSize, cell: CGFloat, visibleFrom: CGFloat) {
        let red = Color(red: 1, green: 0.27, blue: 0.27)
        for run in model.timeline.removedRuns {
            let rect = CGRect(x: CGFloat(run.lowerBound) * cell, y: Lane.ruler, width: CGFloat(run.count) * cell, height: size.height - Lane.ruler)
            context.fill(Path(rect), with: .color(.black.opacity(0.5)))
            var hatch = context
            hatch.clip(to: Path(rect))
            var lines = Path()
            var x = rect.minX - rect.height
            while x < rect.maxX {
                lines.move(to: CGPoint(x: x, y: rect.maxY)); lines.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
                x += 8
            }
            hatch.stroke(lines, with: .color(Color(red: 1, green: 0.3, blue: 0.3).opacity(0.7)), lineWidth: 1)
            context.fill(Path(CGRect(x: rect.minX, y: Lane.ruler - 4, width: rect.width, height: 3)), with: .color(red))

            // How long the stretch is, on a tag that stays in view while the stretch does.
            let duration = context.resolve(Text(Self.duration(run.count * 60)).font(.caption.weight(.bold)).foregroundColor(.white))
            let text = duration.measure(in: CGSize(width: CGFloat.greatestFiniteMagnitude, height: 20))
            let tag = CGSize(width: text.width + 14, height: text.height + 5)
            if rect.width >= tag.width + 18 {
                let from = max(rect.minX, visibleFrom) + 9
                let x = min(max(from, rect.midX - tag.width / 2), rect.maxX - 9 - tag.width)
                let shape = Path(roundedRect: CGRect(x: x, y: Lane.framesTop + (Lane.frames - tag.height) / 2, width: tag.width, height: tag.height),
                                 cornerRadius: tag.height / 2)
                var raised = context
                raised.addFilter(.shadow(color: .black.opacity(0.5), radius: 2, y: 1))
                raised.fill(shape, with: .color(Color(red: 0.86, green: 0.2, blue: 0.2)))
                context.draw(duration, at: CGPoint(x: x + tag.width / 2, y: Lane.framesTop + Lane.frames / 2), anchor: .center)
            }
            for x in [rect.minX, rect.maxX] {
                let grip = CGRect(x: x - 2.5, y: Lane.appsTop + Lane.apps / 2 - 13, width: 5, height: 26)
                var raised = context
                raised.addFilter(.shadow(color: .black.opacity(0.6), radius: 2, y: 1))
                raised.fill(Path(roundedRect: grip, cornerRadius: 2.5), with: Self.vertical([.white, Color(white: 0.8)], grip))
                context.stroke(Path(roundedRect: grip.insetBy(dx: 0.25, dy: 0.25), cornerRadius: 2.5), with: .color(.black.opacity(0.45)), lineWidth: 0.5)
            }
        }
    }

    private func drawPlayhead(_ context: GraphicsContext, size: CGSize, cell: CGFloat) {
        let x = CGFloat(model.playhead) * cell
        context.fill(Path(CGRect(x: x - 1.75, y: Lane.ruler - 2, width: 3.5, height: size.height - Lane.ruler + 2)), with: .color(.black.opacity(0.45)))
        context.fill(Path(CGRect(x: x - 0.75, y: 6, width: 1.5, height: size.height - 6)), with: .color(.white))
        let head = Path { path in
            path.move(to: CGPoint(x: x - 6, y: 1)); path.addLine(to: CGPoint(x: x + 6, y: 1)); path.addLine(to: CGPoint(x: x + 6, y: 8))
            path.addLine(to: CGPoint(x: x, y: 14)); path.addLine(to: CGPoint(x: x - 6, y: 8)); path.closeSubpath()
        }
        var raised = context
        raised.addFilter(.shadow(color: .black.opacity(0.6), radius: 2, y: 1))
        raised.fill(head, with: Self.vertical([.white, Color(white: 0.74)], CGRect(x: x - 6, y: 1, width: 12, height: 13)))
        context.stroke(head, with: .color(.black.opacity(0.5)), lineWidth: 0.5)
    }
}

/// Reports how far the scroll view around it is scrolled sideways. SwiftUI
/// on macOS 14 does not say, and a view's frame there does not move with
/// the scrolling, so this watches the AppKit scroll view underneath.
private struct ScrollOffsetReader: NSViewRepresentable {
    let onChange: (CGFloat) -> Void

    func makeNSView(context: Context) -> Probe { Probe() }
    func updateNSView(_ view: Probe, context: Context) { view.onChange = onChange }

    final class Probe: NSView {
        var onChange: (CGFloat) -> Void = { _ in }
        private var observer: NSObjectProtocol?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let observer { NotificationCenter.default.removeObserver(observer) }
            observer = nil
            // Nil once the window has closed, which is when the watching ends.
            guard window != nil, let clip = enclosingScrollView?.contentView else { return }
            clip.postsBoundsChangedNotifications = true
            observer = NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: clip, queue: nil) { [weak self, weak clip] _ in
                // SwiftUI scrolls in the middle of its own update, where a state change would be dropped.
                DispatchQueue.main.async { self?.onChange(clip?.bounds.minX ?? 0) }
            }
        }
    }
}

/// The icon of each app on the timeline: its own when it is installed here,
/// else the one macOS gives any app.
@MainActor
enum AppIcons {
    private static var icons: [String: NSImage] = [:]

    static func icon(_ bundleID: String) -> NSImage {
        if let cached = icons[bundleID] { return cached }
        let icon = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID).map { NSWorkspace.shared.icon(forFile: $0.path) }
            ?? NSWorkspace.shared.icon(for: .applicationBundle)
        icons[bundleID] = icon
        return icon
    }
}
