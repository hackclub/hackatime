import Foundation
import XCTest
@testable import HackatimeDesktopCore

final class ShippingTests: XCTestCase {
    func block(_ seq: Int, minute: Int, project: String?, focus: FocusLabel = .project, active: Int = 50) -> Block {
        var payload = MinutePayload()
        payload.focus = focus
        payload.project = project
        payload.activeS = active
        let json = String(decoding: try! JSONEncoder().encode(payload), as: UTF8.self)
        return Block(seq: seq, minute: minute, beaconMinute: minute, prevHash: "", capturedAtMs: Int64(minute) * 60_000, monoMs: 0,
                     payload: json, hash: "", signature: nil)
    }

    func testRangeCoversOnlyTheProjectsAcceptedActiveMinutes() {
        var ledger = ShipLedger()
        // seq 1-3 on "site", 4-6 on another project, 7 idle on "site", 8-9 on "site",
        // then a two-hour gap with the app closed (no blocks), then seq 10 on "site".
        ledger.record([
            block(1, minute: 100, project: "site"), block(2, minute: 101, project: "site"), block(3, minute: 102, project: "site"),
            block(4, minute: 103, project: "other"), block(5, minute: 104, project: "other"), block(6, minute: 105, project: "other"),
            block(7, minute: 106, project: "site", active: 0), block(8, minute: 107, project: "Site"), block(9, minute: 108, project: "site"),
            block(10, minute: 230, project: "site"),
        ])
        // Four active minutes on "site": 10, 9, 8 and 3; the other project and the idle minute do not count.
        XCTAssertEqual(ledger.range(project: "site", hours: 4.0 / 60), 3 ... 10)
        XCTAssertEqual(ledger.activeMinutes(project: "site", in: 3 ... 10), 4)
        XCTAssertEqual(ledger.range(project: "SITE", hours: 100), 1 ... 10)
        // Ends at the project's last active minute, not the chain's head.
        XCTAssertEqual(ledger.range(project: "other", hours: 1), 4 ... 6)
        XCTAssertNil(ledger.range(project: "missing", hours: 1))

        ledger.markShipped(through: 8)
        XCTAssertEqual(ledger.range(project: "site", hours: 100), 9 ... 10, "a new ship starts after the last one")
    }

    func testRangeStaysWithinTheServersSpanAndForgetsARestartedChain() {
        var ledger = ShipLedger()
        ledger.record((1 ... 1_500).map { block($0, minute: 1_000 + $0, project: $0 == 1 ? "site" : $0 >= 1_490 ? "site" : "other") })
        let range = ledger.range(project: "site", hours: 24)
        XCTAssertEqual(range, 1_490 ... 1_500, "seq 1 is more than 24 hours of chain before the end")

        // Re-paired: the chain starts again at seq 1.
        ledger.record([block(1, minute: 9_000, project: "site")])
        XCTAssertEqual(ledger.entries.map(\.seq), [1])
        XCTAssertEqual(ledger.range(project: "site", hours: 1), 1 ... 1)
    }

    func testDisclosureStaysWithinTheServersLimits() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ship-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let paths = (0 ..< ShipLimits.maxFiles + 5).map { String(format: "f%05d.txt", $0) }
        for path in paths { try Data(path.utf8).write(to: root.appendingPathComponent(path)) }

        XCTAssertThrowsError(try ShipDisclosure.finalFiles(root: root, tracked: paths)) { XCTAssertTrue($0 is ShipDisclosure.TooLarge) }
        XCTAssertEqual(try ShipDisclosure.finalFiles(root: root, tracked: Array(paths.prefix(10))).count, 10)

        final class Blobs: BlobStore {
            var stored: [String: Data] = [:]
            func put(_ content: Data, hash: String) { stored[hash] = content }
            func get(hash: String) -> Data? { stored[hash] }
        }
        let blobs = Blobs()
        let snapshot = TreeSnapshot.capture(root: root, salt: String(repeating: "22", count: 32), blobs: blobs)
        XCTAssertEqual(snapshot.entries.count, ShipLimits.maxFiles, "snapshots stop at the server's file limit")
        let entries = ShipDisclosure.snapshotEntries(snapshot, tracked: Set(paths), blobs: blobs)
        XCTAssertEqual(entries.filter { $0["content"] != nil }.count, ShipLimits.maxFiles)
        // Every entry still proves the committed root.
        let leaves = entries.enumerated().map { index, entry in
            entry["leaf"] ?? EvidenceProtocol.merkleLeaf(salt: snapshot.salt, path: entry["path"]!, content: Data(base64Encoded: entry["content"]!)!)
        }
        XCTAssertEqual(EvidenceProtocol.merkleRoot(leaves), snapshot.root)
    }
}
