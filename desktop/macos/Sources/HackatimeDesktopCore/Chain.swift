import Foundation

/// Server beacon for one minute (GET /api/desktop/v1/beacon).
public struct Beacon: Codable, Equatable {
    public let minute: Int
    public let value: String
    public let commitment: String
    public let nextExpectedAt: String?
    public let headSeq: Int?
    public let headHash: String?

    enum CodingKeys: String, CodingKey {
        case minute, value, commitment
        case nextExpectedAt = "next_expected_at"
        case headSeq = "head_seq", headHash = "head_hash"
    }
}

/// One minute's summary claims. Never titles, URLs, keystrokes or source.
public struct MinutePayload: Codable, Equatable {
    public struct AI: Codable, Equatable {
        public var prompts = 0
        public var inTokens = 0
        public var outTokens = 0
        public var aiLines = 0
        public var humanLines = 0
        public var waiting = false
        public var accepted = 0
        public init() {}
        enum CodingKeys: String, CodingKey {
            case prompts, waiting, accepted
            case inTokens = "in_tokens", outTokens = "out_tokens", aiLines = "ai_lines", humanLines = "human_lines"
        }
    }

    /// One timelapse frame: the hash of its encrypted bytes, when it was
    /// taken, and a perceptual hash for spotting frozen screens.
    public struct Frame: Codable, Equatable {
        public var hash: String
        public var kind = "timelapse"
        public var atMs: Int64
        public var phash: String?
        public init(hash: String, atMs: Int64, phash: String? = nil) {
            self.hash = hash; self.atMs = atMs; self.phash = phash
        }
        enum CodingKeys: String, CodingKey { case hash, kind, phash; case atMs = "at_ms" }
    }

    public struct Tree: Codable, Equatable {
        public var root: String
        public init(root: String) { self.root = root }
    }

    public var focus: FocusLabel = .unknown
    public var project: String?
    public var category: String?
    public var activeS = 0
    /// Input counts and scores are nil, and left out of the JSON, when the
    /// Mac has no Input Monitoring permission: unknown, not zero.
    public var keys: Int?
    public var clicks: Int?
    public var moves: Int?
    public var injected: Int?
    public var rhythm: Double?
    public var jiggler: Double?
    public var edits = 0
    public var commits = 0
    public var builds = 0
    public var ai: AI?
    public var tree: Tree?
    public var frames: [Frame]?

    public init() {}

    enum CodingKeys: String, CodingKey {
        case focus, project, category, keys, clicks, moves, injected, rhythm, jiggler, edits, commits, builds, ai, tree, frames
        case activeS = "active_s"
    }
}

/// A block exactly as POSTed to /api/desktop/v1/blocks.
public struct Block: Codable, Equatable {
    public let seq: Int
    public let minute: Int
    public let beaconMinute: Int
    public let prevHash: String
    public let capturedAtMs: Int64
    public let monoMs: Int64
    public let payload: String
    public let hash: String
    public let signature: String?

    enum CodingKeys: String, CodingKey {
        case seq, minute, payload, hash, signature
        case beaconMinute = "beacon_minute", prevHash = "prev_hash", capturedAtMs = "captured_at_ms", monoMs = "mono_ms"
    }
}

/// The device's local view of its hash chain. Blocks are appended once a
/// minute, linked to the previous block and the latest beacon, signed, and
/// queued until the server accepts them (offline blocks keep their old
/// beacon and are accepted at lower confidence).
public final class ChainState: Codable {
    public private(set) var seq: Int
    public private(set) var head: String
    public private(set) var lastMinute: Int?
    public private(set) var pending: [Block] = []
    /// The last `mono_ms` sent, and what is added to the system clock so that
    /// it keeps rising after a reboot restarts uptime at zero.
    public private(set) var lastMonoMs: Int64?
    private var monoOffset: Int64?

    public init(seq: Int = 0, head: String = EvidenceProtocol.zeroHash) {
        self.seq = seq
        self.head = head
    }

    /// Builds, signs and queues the next block. Returns nil when this minute
    /// already has a block (minutes must strictly increase). `monoMs` is the
    /// system uptime; the block carries it shifted past the last block's.
    @discardableResult
    public func append(payload: MinutePayload, beacon: Beacon, now: Date, monoMs: Int64, key: DeviceKey?) throws -> Block? {
        let capturedAtMs = Int64(now.timeIntervalSince1970 * 1000)
        let minute = Int(capturedAtMs / 60_000)
        if let lastMinute, minute <= lastMinute { return nil }
        var monoMs = monoMs + (monoOffset ?? 0)
        if let lastMonoMs, monoMs <= lastMonoMs {
            // Uptime went back, so the Mac restarted: carry on from the last block.
            monoOffset = (monoOffset ?? 0) + lastMonoMs + 1 - monoMs
            monoMs = lastMonoMs + 1
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let json = String(decoding: try encoder.encode(payload), as: UTF8.self)
        let hash = EvidenceProtocol.chainHash(prev: head, beaconValue: beacon.value, payload: Data(json.utf8))
        let block = Block(
            seq: seq + 1, minute: minute, beaconMinute: beacon.minute, prevHash: head, capturedAtMs: capturedAtMs,
            monoMs: monoMs, payload: json, hash: hash, signature: try key?.signature(forHashHex: hash)
        )
        seq = block.seq
        head = hash
        lastMinute = minute
        lastMonoMs = monoMs
        pending.append(block)
        return block
    }

    /// Drops blocks the server has accepted (by its reported head).
    public func acknowledge(headSeq: Int) {
        pending.removeAll { $0.seq <= headSeq }
    }

    /// The server's head is authoritative after a reset or fork: start a new
    /// chain segment from it and drop unaccepted blocks.
    public func resync(seq: Int, head: String) {
        self.seq = seq
        self.head = head
        pending.removeAll()
    }
}
