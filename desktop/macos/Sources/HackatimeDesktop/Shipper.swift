import Foundation
import HackatimeDesktopCore

/// Ships a range of the chain. The server reveals its beacon secrets, which
/// pick required timelapse frames and code snapshots; this uploads exactly those
/// (plus frames the user chose to keep), discloses only files tracked in the
/// shipped repo and proves every other file by its leaf hash. Reading the
/// repo runs off the main thread.
@MainActor
struct Shipper {
    let agent: Agent

    struct Plan {
        let shipID: Int
        let fromSeq: Int
        let toSeq: Int
        let requiredFrames: [String]
        let spotCheckSeqs: [Int]
    }

    /// Opens the ship. `excluded` are the minutes the user removed on the
    /// timeline: they are named before the server reveals which frames it
    /// wants, earn nothing, and none of their frames are asked for.
    func open(project: String, fromSeq: Int, toSeq: Int, excluded: [ClosedRange<Int>] = []) async throws -> Plan {
        let response = try await agent.api.request("POST", "api/desktop/v1/ships", body: [
            "project": project, "from_seq": fromSeq, "to_seq": toSeq,
            "excluded": excluded.map { ["from_seq": $0.lowerBound, "to_seq": $0.upperBound] },
        ])
        // Check every revealed secret against the commitment the server
        // published while we worked; a mismatch means the server cheated.
        for revealed in response["revealed"] as? [[String: Any]] ?? [] {
            guard let secret = revealed["secret"] as? String, let commitment = revealed["commitment"] as? String,
                  EvidenceProtocol.beaconCommitment(secret: secret) == commitment else {
                throw APIClient.Failure(status: 0, body: "Server revealed a secret that does not match its commitment")
            }
        }
        return Plan(shipID: response["id"] as? Int ?? 0, fromSeq: fromSeq, toSeq: toSeq,
                    requiredFrames: response["required_frames"] as? [String] ?? [],
                    spotCheckSeqs: response["spot_check_seqs"] as? [Int] ?? [])
    }

    /// Uploads a frame. `redacted` is the user's edited copy, if any; the
    /// server keeps it against the committed hash and shows reviewers that it
    /// was redacted. Required frames can be redacted but not removed.
    func upload(frameHash: String, shipID: Int, redacted: Data? = nil, regions: [[String: Int]] = []) async throws {
        let key = try agent.vault.releaseKey(for: frameHash)
        let ciphertext = try redacted.map { try agent.vault.sealRedacted($0, for: frameHash) } ?? agent.vault.ciphertext(frameHash)
        var body: [String: Any] = ["hash": frameHash, "ciphertext": ciphertext.base64EncodedString(), "segment_key": key.base64EncodedString()]
        if redacted != nil { body["redacted"] = true; body["redactions"] = regions }
        _ = try await agent.api.request("POST", "api/desktop/v1/ships/\(shipID)/frames", body: body)
        agent.vault.markShipped(frameHash)
    }

    /// The tracked files the ship will disclose, read off the main thread.
    /// Throws `ShipDisclosure.TooLarge` before anything is sent when the
    /// project is over the server's limits.
    nonisolated static func finalFiles(projectRoot: URL) async throws -> [[String: String]] {
        try await Task.detached(priority: .userInitiated) {
            try ShipDisclosure.finalFiles(root: projectRoot, tracked: try trackedFiles(projectRoot))
        }.value
    }

    func submit(plan: Plan, finalFiles: [[String: String]]) async throws -> [String: Any] {
        let spotChecks = plan.spotCheckSeqs.compactMap { seq in agent.snapshot(at: seq).map { (seq, $0) } }
        let vault = agent.vault
        let tracked = Set(finalFiles.compactMap { $0["path"] })
        let snapshots: [[String: Any]] = await Task.detached(priority: .userInitiated) {
            spotChecks.map { seq, snapshot in
                ["seq": seq, "salt": snapshot.salt, "entries": ShipDisclosure.snapshotEntries(snapshot, tracked: tracked, blobs: vault)]
            }
        }.value
        let result = try await agent.api.request("POST", "api/desktop/v1/ships/\(plan.shipID)/submit",
                                                 body: ["final_files": finalFiles, "snapshots": snapshots])
        agent.markShipped(through: plan.toSeq)
        return result
    }

    /// Files git tracks at HEAD: the only ones ever disclosed.
    nonisolated static func trackedFiles(_ root: URL) throws -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", root.path, "ls-files", "-z"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return data.split(separator: 0).map { String(decoding: $0, as: UTF8.self) }
            .filter { !TreeSnapshot.isNeverHashed(name: URL(fileURLWithPath: $0).lastPathComponent, relative: $0) }
    }

    /// The server's own words for a failed request, when it sent any.
    static func message(for error: Error) -> String {
        if let failure = error as? APIClient.Failure,
           let body = try? JSONSerialization.jsonObject(with: Data(failure.body.utf8)) as? [String: Any],
           let message = body["error"] as? String { return message }
        return "\(error)"
    }
}
