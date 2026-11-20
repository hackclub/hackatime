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
    private var offset: UInt64 = 0
    /// Open turns: session → time the last prompt was sent.
    private var waitingSince: [String: Double] = [:]

    public init(url: URL) {
        self.url = url
        FileManager.default.createFile(atPath: url.path, contents: nil)
    }

    /// Reads new events and folds them into a minute's AI summary.
    public func drain(now: Double) -> MinutePayload.AI? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        try? handle.seek(toOffset: offset)
        let data = handle.readDataToEndOfFile()
        offset += UInt64(data.count)
        var ai = MinutePayload.AI()
        var any = false
        for line in data.split(separator: UInt8(ascii: "\n")) {
            guard let event = try? JSONDecoder().decode(AIEvent.self, from: Data(line)) else { continue }
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

/// Metadata-only backfill from Claude Code's local transcripts: counts user
/// prompts and token usage per session file, never reading text into memory
/// beyond one line at a time and never storing it.
public enum TranscriptBackfill {
    public static func claudeCode(home: URL = FileManager.default.homeDirectoryForCurrentUser, since: Date) -> [AIEvent] {
        let root = home.appendingPathComponent(".claude/projects")
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.contentModificationDateKey]) else { return [] }
        var events: [AIEvent] = []
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        for case let file as URL in walker where file.pathExtension == "jsonl" {
            guard let modified = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate, modified >= since,
                  let text = try? String(contentsOf: file, encoding: .utf8) else { continue }
            for line in text.split(separator: "\n") {
                guard let object = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                      let stamp = (object["timestamp"] as? String).flatMap(iso.date(from:)), stamp >= since else { continue }
                let session = object["sessionId"] as? String
                let cwd = object["cwd"] as? String
                let message = object["message"] as? [String: Any]
                if object["type"] as? String == "user", message?["content"] is String {
                    events.append(AIEvent(tool: "claude-code", event: "prompt", session: session, cwd: cwd, at: stamp.timeIntervalSince1970))
                } else if object["type"] as? String == "assistant", let usage = message?["usage"] as? [String: Any] {
                    events.append(AIEvent(tool: "claude-code", event: "turn_end", session: session, cwd: cwd, at: stamp.timeIntervalSince1970,
                                          inTokens: usage["input_tokens"] as? Int, outTokens: usage["output_tokens"] as? Int))
                }
            }
        }
        return events.sorted { $0.at < $1.at }
    }
}
