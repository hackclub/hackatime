import Foundation
import HackatimeDesktopCore

/// Ships a range of the chain. The server reveals its beacon secrets, which
/// pick required timelapse frames and code snapshots; this uploads exactly those
/// (plus frames the user chose to keep), discloses only files tracked in the
/// shipped repo and proves every other file by its leaf hash.
@MainActor
struct Shipper {
    let agent: Agent

    struct Plan {
        let shipID: Int
        let requiredFrames: [String]
        let spotCheckSeqs: [Int]
    }

    func open(project: String, fromSeq: Int, toSeq: Int) async throws -> Plan {
        let response = try await agent.api.request("POST", "api/desktop/v1/ships", body: ["project": project, "from_seq": fromSeq, "to_seq": toSeq])
        // Check every revealed secret against the commitment the server
        // published while we worked; a mismatch means the server cheated.
        for revealed in response["revealed"] as? [[String: Any]] ?? [] {
            guard let secret = revealed["secret"] as? String, let commitment = revealed["commitment"] as? String,
                  EvidenceProtocol.beaconCommitment(secret: secret) == commitment else {
                throw APIClient.Failure(status: 0, body: "Server revealed a secret that does not match its commitment")
            }
        }
        return Plan(shipID: response["id"] as? Int ?? 0, requiredFrames: response["required_frames"] as? [String] ?? [],
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

    func submit(plan: Plan, projectRoot: URL) async throws -> [String: Any] {
        let tracked = Set(try trackedFiles(projectRoot))
        let finalFiles: [[String: String]] = tracked.sorted().compactMap { path in
            guard let data = try? Data(contentsOf: projectRoot.appendingPathComponent(path)), data.count <= TreeSnapshot.maxFileBytes else { return nil }
            return ["path": path, "content": data.base64EncodedString()]
        }
        let snapshots: [[String: Any]] = plan.spotCheckSeqs.compactMap { seq in
            guard let snapshot = agent.snapshot(at: seq) else { return nil }
            let entries: [[String: String]] = snapshot.entries.map { entry in
                if tracked.contains(entry.path), let hash = entry.content, let content = agent.vault.get(hash: hash) {
                    return ["path": entry.path, "content": content.base64EncodedString()]
                }
                return ["leaf": entry.leaf]
            }
            return ["seq": seq, "salt": snapshot.salt, "entries": entries]
        }
        return try await agent.api.request("POST", "api/desktop/v1/ships/\(plan.shipID)/submit",
                                           body: ["final_files": finalFiles, "snapshots": snapshots])
    }

    /// Files git tracks at HEAD: the only ones ever disclosed.
    func trackedFiles(_ root: URL) throws -> [String] {
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
}
