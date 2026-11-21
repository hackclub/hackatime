import CryptoKit
import Foundation
import XCTest
@testable import HackatimeDesktopCore

final class VaultTests: XCTestCase {
    func tempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("vault-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func testDeleteEverythingLeavesNoReadableCopyBehind() throws {
        let store = MemoryStore()
        let directory = try tempDir()
        let vault = try Vault(directory: directory, store: store)
        let frame = try vault.store(frame: Data("frame".utf8), capturedAtMs: Int64(Date().timeIntervalSince1970 * 1000))
        vault.put(Data("source file".utf8), hash: "abc")
        // A backup (Time Machine, a copied folder) taken before deleting.
        let backup = try tempDir().appendingPathComponent("vault")
        try FileManager.default.copyItem(at: directory, to: backup)
        XCTAssertNotNil(try? Vault(directory: backup, store: store).preview(frame.hash))

        vault.deleteEverything()

        let restored = try Vault(directory: backup, store: store)
        XCTAssertNil(try? restored.preview(frame.hash), "a backed-up frame must not decrypt after deleting everything")
        XCTAssertNil(restored.get(hash: "abc"), "a backed-up snapshot blob must not decrypt either")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.appendingPathComponent("frames").path), [])
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.appendingPathComponent("blobs").path), [])
        XCTAssertTrue(try Vault(directory: directory, store: store).frames.isEmpty)
        // The vault still works afterwards.
        let next = try vault.store(frame: Data("next".utf8), capturedAtMs: Int64(Date().timeIntervalSince1970 * 1000))
        XCTAssertEqual(try vault.preview(next.hash), Data("next".utf8))
    }

    func testExpiredSegmentsAndUnusedBlobsAreShreddedEvenAfterShipping() throws {
        let directory = try tempDir()
        let vault = try Vault(directory: directory, store: MemoryStore())
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let old = try vault.store(frame: Data("old".utf8), capturedAtMs: nowMs - 60 * 86_400 * 1000)
        let shipped = try vault.store(frame: Data("shipped".utf8), capturedAtMs: nowMs - 45 * 86_400 * 1000)
        let recent = try vault.store(frame: Data("recent".utf8), capturedAtMs: nowMs - 86_400 * 1000)
        _ = try vault.releaseKey(for: old.hash)   // a ship that failed before the upload
        _ = try vault.releaseKey(for: shipped.hash)
        vault.markShipped(shipped.hash)

        let monthAgo = Date().addingTimeInterval(-31 * 86_400)
        vault.put(Data("deleted file".utf8), hash: "unused")
        vault.put(Data("unchanged file".utf8), hash: "still-used")
        for hash in ["unused", "still-used"] {
            try FileManager.default.setAttributes([.modificationDate: monthAgo], ofItemAtPath: directory.appendingPathComponent("blobs/\(hash)").path)
        }
        vault.put(Data("unchanged file".utf8), hash: "still-used")   // seen again by today's snapshot

        XCTAssertEqual(vault.shredExpired(), 2)
        XCTAssertEqual(vault.frames.map(\.hash), [recent.hash])
        for frame in [old, shipped] {
            XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("frames/\(frame.hash).bin").path))
        }
        XCTAssertNil(vault.get(hash: "unused"))
        XCTAssertEqual(vault.get(hash: "still-used"), Data("unchanged file".utf8))
    }
}
