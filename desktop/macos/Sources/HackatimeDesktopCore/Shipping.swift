import Foundation

/// The server's limits on what one ship discloses
/// (Evidence::SnapshotCheck in app/services/evidence/snapshot_check.rb):
/// files with content per list, bytes per file and bytes per list.
public enum ShipLimits {
    public static let maxFiles = 2_000
    public static let maxFileBytes = 512 * 1024
    public static let maxTotalBytes = 20 * 1024 * 1024
    /// A ship covers fewer than 24 hours of chain (EvidenceShip).
    public static let maxSeqSpan = 24 * 60
}

/// The minutes the server accepted, kept locally so a ship can pick the
/// range that really belongs to a project: blocks are not one per minute of
/// any one project, and queued blocks the server has not accepted cannot be
/// shipped. Holds only what the chain already sent (seq, minute, project).
public struct ShipLedger: Codable, Equatable {
    public struct Entry: Codable, Equatable {
        public let seq: Int
        public let minute: Int
        public let project: String?
        public let active: Bool

        public init(seq: Int, minute: Int, project: String?, active: Bool) {
            self.seq = seq; self.minute = minute; self.project = project; self.active = active
        }
    }

    public private(set) var entries: [Entry] = []
    /// The last seq of the last submitted ship; ships cannot overlap.
    public private(set) var shippedThrough = 0
    static let keepMinutes = 3 * 24 * 60

    public init(entries: [Entry] = [], shippedThrough: Int = 0) {
        self.entries = entries
        self.shippedThrough = shippedThrough
    }

    /// Records blocks the server accepted.
    public mutating func record(_ blocks: [Block]) {
        for block in blocks {
            // A chain that restarts (re-paired, resynced to an earlier head)
            // reuses seqs: what came after it no longer exists.
            if let last = entries.last, block.seq <= last.seq {
                entries.removeAll { $0.seq >= block.seq }
                shippedThrough = min(shippedThrough, block.seq - 1)
            }
            let payload = try? JSONDecoder().decode(MinutePayload.self, from: Data(block.payload.utf8))
            let active = (payload?.focus == .project || payload?.focus == .research) && (payload?.activeS ?? 0) > 0
            entries.append(Entry(seq: block.seq, minute: block.minute, project: payload?.project, active: active))
        }
        if let newest = entries.last?.minute { entries.removeAll { $0.minute < newest - Self.keepMinutes } }
    }

    public mutating func markShipped(through seq: Int) { shippedThrough = max(shippedThrough, seq) }

    /// The seqs covering the latest `hours` of active minutes on `project`
    /// since the last ship, ending at its last active minute. Minutes on
    /// other projects in between stay in the range (a range is contiguous)
    /// but are not counted. Nil when there is nothing to ship.
    public func range(project: String, hours: Double) -> ClosedRange<Int>? {
        let wanted = max(1, Int((hours * 60).rounded()))
        let mine = entries.filter { $0.seq > shippedThrough && $0.active && $0.project?.lowercased() == project.lowercased() }
        guard let last = mine.last else { return nil }
        var from = last.seq
        for entry in mine.reversed().prefix(wanted) {
            guard last.seq - entry.seq < ShipLimits.maxSeqSpan else { break }
            from = entry.seq
        }
        return from ... last.seq
    }

    /// Active minutes on `project` inside `range`.
    public func activeMinutes(project: String, in range: ClosedRange<Int>) -> Int {
        entries.filter { range.contains($0.seq) && $0.active && $0.project?.lowercased() == project.lowercased() }.count
    }
}

/// What a ship discloses, within the server's limits.
public enum ShipDisclosure {
    public struct TooLarge: Error, CustomStringConvertible {
        public let files: Int
        public let bytes: Int
        public var description: String {
            "This project has \(files) tracked files (\(bytes / 1_048_576) MB). A ship can include at most \(ShipLimits.maxFiles) files and \(ShipLimits.maxTotalBytes / 1_048_576) MB."
        }
    }

    /// The final shipped files: every tracked file up to the size limit, with
    /// content. Throws rather than silently dropping files the server would
    /// otherwise judge the work by.
    public static func finalFiles(root: URL, tracked: [String]) throws -> [[String: String]] {
        var files: [[String: String]] = []
        var total = 0
        for path in tracked.sorted() {
            guard let data = try? Data(contentsOf: root.appendingPathComponent(path)), data.count <= ShipLimits.maxFileBytes else { continue }
            total += data.count
            files.append(["path": path, "content": data.base64EncodedString()])
        }
        guard files.count <= ShipLimits.maxFiles, total <= ShipLimits.maxTotalBytes else { throw TooLarge(files: files.count, bytes: total) }
        return files
    }

    /// One spot-checked snapshot as its ordered leaf list: tracked files with
    /// content while within the limits, every other file by its leaf hash
    /// (which still proves the committed root).
    public static func snapshotEntries(_ snapshot: TreeSnapshot, tracked: Set<String>, blobs: BlobStore) -> [[String: String]] {
        var disclosed = 0
        var total = 0
        return snapshot.entries.map { entry in
            if disclosed < ShipLimits.maxFiles, tracked.contains(entry.path), let hash = entry.content, let content = blobs.get(hash: hash),
               total + content.count <= ShipLimits.maxTotalBytes {
                disclosed += 1
                total += content.count
                return ["path": entry.path, "content": content.base64EncodedString()]
            }
            return ["leaf": entry.leaf]
        }
    }
}
