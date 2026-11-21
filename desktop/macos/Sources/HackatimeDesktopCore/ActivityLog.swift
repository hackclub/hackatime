import Foundation

/// A stretch of time one window was in front.
public struct ActivitySegment: Codable, Equatable {
    public var startMs: Int64
    public var endMs: Int64
    public let bundleID: String
    public let app: String
    /// The window title; empty for never-listed apps and private windows.
    public let title: String
    /// The host of a browser tab, such as `github.com`.
    public let site: String?
    public let label: FocusLabel

    public init(startMs: Int64, endMs: Int64, bundleID: String, app: String, title: String = "", site: String? = nil, label: FocusLabel = .unknown) {
        self.startMs = startMs; self.endMs = endMs; self.bundleID = bundleID; self.app = app
        self.title = title; self.site = site; self.label = label
    }

    func sameWindow(as other: ActivitySegment) -> Bool {
        bundleID == other.bundleID && title == other.title && site == other.site && label == other.label
    }
}

/// Which window was in front and when, kept on this Mac only, so a ship can
/// be reviewed on a timeline before anything is sent. Built from the focus
/// samples the agent already takes: samples of the same window join into
/// one segment, and a pause, sleep or idle spell leaves a gap. Titles and
/// sites never go to the server; the agent stores the log encrypted.
public struct ActivityLog: Codable, Equatable {
    public private(set) var segments: [ActivitySegment] = []

    /// As long as the ship ledger keeps the minutes a ship can cover.
    static let keepMs = Int64(ShipLedger.keepMinutes) * 60_000
    /// Samples further apart than this are not the same sitting.
    static let joinMs: Int64 = 15_000

    public init(segments: [ActivitySegment] = []) { self.segments = segments }

    /// Records one focus sample, which stands for the `everyMs` after it.
    /// A never-listed window keeps its app but not its title or site.
    public mutating func record(_ sample: FocusSample, label: FocusLabel, atMs: Int64, everyMs: Int64 = 5_000) {
        let sensitive = FocusClassifier.isNever(sample)
        let segment = ActivitySegment(startMs: atMs, endMs: atMs + everyMs, bundleID: sample.bundleID, app: sample.appName,
                                      title: sensitive ? "" : String(sample.title.prefix(200)), site: sensitive ? nil : sample.domain,
                                      label: label)
        if let last = segments.last, last.sameWindow(as: segment), atMs - last.endMs <= Self.joinMs, atMs >= last.startMs {
            segments[segments.count - 1].endMs = max(last.endMs, segment.endMs)
        } else {
            // A sample that arrives early cuts the previous segment short.
            if let last = segments.last, last.endMs > atMs {
                if atMs > last.startMs { segments[segments.count - 1].endMs = atMs } else { segments.removeLast() }
            }
            segments.append(segment)
        }
        segments.removeAll { $0.endMs < atMs - Self.keepMs }
    }

    /// The segments inside a time span, cut to it.
    public func segments(fromMs: Int64, toMs: Int64) -> [ActivitySegment] {
        segments.compactMap { segment in
            guard segment.endMs > fromMs, segment.startMs < toMs else { return nil }
            var cut = segment
            cut.startMs = max(segment.startMs, fromMs)
            cut.endMs = min(segment.endMs, toMs)
            return cut
        }
    }
}
