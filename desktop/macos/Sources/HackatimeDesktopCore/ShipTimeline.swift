import Foundation

/// A ship laid out for review before it is sent: the chain's minutes side by
/// side, like clips on an editor's timeline, with the windows that were in
/// front during each. The user removes minutes here; a removed minute earns
/// nothing and none of its frames are sent. Minutes are the unit because the
/// chain has one block a minute.
public struct ShipTimeline: Equatable {
    public struct Minute: Equatable {
        public let seq: Int
        /// The minute the block describes: a block is sealed just after the
        /// minute it covers has ended.
        public let startMs: Int64
        /// Whether the minute counts towards the ship's project.
        public let counts: Bool
        /// What was in front, cut to this minute.
        public let activity: [ActivitySegment]
    }

    public struct AppUse: Equatable, Identifiable {
        public let bundleID: String
        public let app: String
        public let seconds: Int
        /// The positions of the minutes it was in front in.
        public let minutes: [Int]
        /// Its windows, the longest in front first.
        public let windows: [WindowUse]
        public var id: String { bundleID }
    }

    public struct WindowUse: Equatable {
        /// Empty when the title was not recorded.
        public let title: String
        public let site: String?
        public let seconds: Int
    }

    public let project: String
    public let minutes: [Minute]
    /// The positions of the minutes a secrets file was in front in, however
    /// briefly. A timeline starts with these removed, so a ship never
    /// carries a frame of an open `.env` unless the user puts the minute back.
    public let secretMinutes: [Int]
    /// The names of those files, in the order they first came up.
    public let secretFiles: [String]
    /// Positions (indexes into `minutes`) that are out of the ship.
    public private(set) var removed: Set<Int>

    public init(project: String, entries: [ShipLedger.Entry], range: ClosedRange<Int>, activity: ActivityLog) {
        self.project = project
        minutes = entries.filter { range.contains($0.seq) }.sorted { $0.seq < $1.seq }.map { entry in
            let startMs = Int64(entry.minute - 1) * 60_000
            return Minute(seq: entry.seq, startMs: startMs, counts: entry.active && entry.project?.lowercased() == project.lowercased(),
                          activity: activity.segments(fromMs: startMs, toMs: startMs + 60_000))
        }
        // Read from the titles once: the review redraws many times a second.
        let files = minutes.map { $0.activity.compactMap(\.secretFile) }
        secretMinutes = files.indices.filter { !files[$0].isEmpty }
        secretFiles = files.joined().reduce(into: []) { names, name in if !names.contains(name) { names.append(name) } }
        removed = Set(secretMinutes)
    }

    /// Every app that was in front, the longest first.
    public var apps: [AppUse] {
        struct Window: Hashable { let title: String, site: String? }
        var seconds: [String: Int] = [:], names: [String: String] = [:], positions: [String: [Int]] = [:]
        var windows: [String: [Window: Int]] = [:]
        for (index, minute) in minutes.enumerated() {
            for segment in minute.activity {
                let length = Int((segment.endMs - segment.startMs) / 1000)
                seconds[segment.bundleID, default: 0] += length
                windows[segment.bundleID, default: [:]][Window(title: segment.title, site: segment.site), default: 0] += length
                names[segment.bundleID] = segment.app
                if positions[segment.bundleID]?.last != index { positions[segment.bundleID, default: []].append(index) }
            }
        }
        return seconds.map { bundleID, total in
            let used = (windows[bundleID] ?? [:]).map { WindowUse(title: $0.key.title, site: $0.key.site, seconds: $0.value) }
                .sorted { ($0.seconds, $1.title) > ($1.seconds, $0.title) }
            return AppUse(bundleID: bundleID, app: names[bundleID] ?? bundleID, seconds: total, minutes: positions[bundleID] ?? [], windows: used)
        }
        .sorted { ($0.seconds, $1.app) > ($1.seconds, $0.app) }
    }

    public mutating func setRemoved(_ isRemoved: Bool, positions: some Sequence<Int>) {
        let valid = positions.filter { minutes.indices.contains($0) }
        if isRemoved { removed.formUnion(valid) } else { removed.subtract(valid) }
    }

    /// Removes or restores every minute an app was in front in, however
    /// briefly: that minute's frame may show it.
    public mutating func setRemoved(_ isRemoved: Bool, bundleID: String) {
        setRemoved(isRemoved, positions: apps.first { $0.bundleID == bundleID }?.minutes ?? [])
    }

    /// The minutes of the window that was in front at a position on the
    /// timeline (minute index plus the fraction of the minute), as far as
    /// the same window stays in front.
    public func positions(ofWindowAt position: Double) -> ClosedRange<Int>? {
        let index = Int(position.rounded(.down))
        guard minutes.indices.contains(index) else { return nil }
        let ms = minutes[index].startMs + Int64((position - Double(index)) * 60_000)
        guard let window = minutes[index].activity.first(where: { $0.startMs <= ms && ms < $0.endMs }) else { return nil }
        let shows: (Int) -> Bool = { minutes[$0].activity.contains { $0.sameWindow(as: window) } }
        var first = index, last = index
        while first > 0, shows(first - 1) { first -= 1 }
        while last < minutes.count - 1, shows(last + 1) { last += 1 }
        return first ... last
    }

    /// Minutes that count towards the project and are still in the ship.
    public var keptCountedMinutes: Int {
        minutes.indices.filter { minutes[$0].counts && !removed.contains($0) }.count
    }

    /// The removed minutes as the server takes them: inclusive seq ranges.
    public var excludedRanges: [ClosedRange<Int>] {
        var ranges: [ClosedRange<Int>] = []
        for seq in removed.map({ minutes[$0].seq }).sorted() {
            if let last = ranges.last, last.upperBound + 1 == seq {
                ranges[ranges.count - 1] = last.lowerBound ... seq
            } else {
                ranges.append(seq ... seq)
            }
        }
        return ranges
    }
}
