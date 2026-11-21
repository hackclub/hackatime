import Foundation

/// AI tool events. Hooks (desktop/hooks: Claude Code hooks, Codex notify, the
/// Amp plugin, Cursor) append one JSON object per line to the inbox file;
/// the agent drains it every minute. Only counts, tokens and line totals are
/// kept, never prompt text. Local transcripts (~/.claude/projects,
/// ~/.codex/sessions) are read for the same metadata as a backfill.
public struct AIEvent: Codable, Equatable {
    public var tool: String
    public var event: String          // prompt | turn_end | tool_use | accept
    public var session: String?
    public var cwd: String?
    public var at: Double             // unix seconds
    public var inTokens: Int?
    public var outTokens: Int?
    public var aiLines: Int?
    public var humanLines: Int?

    enum CodingKeys: String, CodingKey {
        case tool, event, session, cwd, at
        case inTokens = "in_tokens", outTokens = "out_tokens", aiLines = "ai_lines", humanLines = "human_lines"
    }
}

public final class AIInbox {
    public let url: URL
    /// How far the inbox has been read, kept next to it so a relaunch
    /// neither loses nor recounts events.
    private let offsetURL: URL
    private var offset: UInt64
    /// Events older than this were written while the app was not running and
    /// cannot be placed in a minute any more.
    static let maxAge: Double = 600
    /// Open turns: session → time the last prompt was sent.
    private var waitingSince: [String: Double] = [:]

    public init(url: URL) {
        self.url = url
        offsetURL = url.appendingPathExtension("offset")
        offset = (try? String(contentsOf: offsetURL, encoding: .utf8)).flatMap { UInt64($0) } ?? 0
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
    }

    /// Reads new events and folds them into a minute's AI summary.
    public func drain(now: Double) -> MinutePayload.AI? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        // A shorter file was replaced or emptied: read it from the start.
        if let size = try? handle.seekToEnd(), size < offset { offset = 0 }
        try? handle.seek(toOffset: offset)
        var data = handle.readDataToEndOfFile()
        // Leave a line a hook is still writing for the next drain.
        data = data.lastIndex(of: UInt8(ascii: "\n")).map { data[...$0] } ?? Data()
        offset += UInt64(data.count)
        try? String(offset).write(to: offsetURL, atomically: true, encoding: .utf8)
        var ai = MinutePayload.AI()
        var any = false
        for line in data.split(separator: UInt8(ascii: "\n")) {
            guard let event = try? JSONDecoder().decode(AIEvent.self, from: Data(line)), now - event.at < Self.maxAge else { continue }
            any = true
            let session = event.session ?? event.tool
            switch event.event {
            case "prompt":
                ai.prompts += 1
                waitingSince[session] = event.at
            case "turn_end":
                waitingSince[session] = nil
            case "accept":
                ai.accepted += 1
            default: break
            }
            ai.inTokens += event.inTokens ?? 0
            ai.outTokens += event.outTokens ?? 0
            ai.aiLines += event.aiLines ?? 0
            ai.humanLines += event.humanLines ?? 0
        }
        // A turn left open for more than 30 minutes is abandoned, not waiting.
        waitingSince = waitingSince.filter { now - $0.value < 1_800 }
        ai.waiting = !waitingSince.isEmpty
        return any || ai.waiting ? ai : nil
    }
}
