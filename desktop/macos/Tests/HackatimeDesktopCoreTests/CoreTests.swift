import CryptoKit
import Foundation
import XCTest
@testable import HackatimeDesktopCore

final class CoreTests: XCTestCase {
    let beacon = Beacon(minute: 29_000_000, value: String(repeating: "ab", count: 32), commitment: String(repeating: "cd", count: 32),
                        nextExpectedAt: nil, headSeq: 0, headHash: nil)

    func testChainLinksBlocksAndSignsTheExactHash() throws {
        let key = try DeviceKey.loadOrCreate(store: MemoryStore())
        let chain = ChainState()
        var payload = MinutePayload()
        payload.focus = .project
        payload.activeS = 40
        let t0 = Date(timeIntervalSince1970: 1_740_000_005)
        let first = try XCTUnwrap(chain.append(payload: payload, beacon: beacon, now: t0, monoMs: 1, key: key))
        let second = try XCTUnwrap(chain.append(payload: payload, beacon: beacon, now: t0 + 60, monoMs: 60_001, key: key))
        XCTAssertNil(try chain.append(payload: payload, beacon: beacon, now: t0 + 61, monoMs: 61_000, key: key), "one block per minute")

        XCTAssertEqual(first.prevHash, EvidenceProtocol.zeroHash)
        XCTAssertEqual(second.prevHash, first.hash)
        XCTAssertEqual(second.hash, EvidenceProtocol.chainHash(prev: first.hash, beaconValue: beacon.value, payload: Data(second.payload.utf8)))

        let publicKey = try P256.Signing.PublicKey(derRepresentation: key.publicKeyDER)
        let signature = try P256.Signing.ECDSASignature(derRepresentation: Data(base64Encoded: second.signature!)!)
        XCTAssertTrue(publicKey.isValidSignature(signature, for: Data(hex: second.hash)))

        chain.acknowledge(headSeq: 1)
        XCTAssertEqual(chain.pending.map(\.seq), [2])
    }

    func testDeviceKeyPersistsAcrossLaunches() throws {
        let store = MemoryStore()
        let a = try DeviceKey.loadOrCreate(store: store)
        let b = try DeviceKey.loadOrCreate(store: store)
        XCTAssertEqual(a.publicKeyDER, b.publicKeyDER)
        XCTAssertEqual(a.tier, b.tier)
    }

    func testSnapshotNeverHashesSecretsDependenciesOrIgnoredFiles() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let files = [
            "app.rb": "puts 1", ".env": "SECRET=1", ".env.local": "X=1", "keys/server.pem": "pem",
            "node_modules/x/index.js": "dep", "build/out.o": "bin", "notes/private.md": "diary", "lib/util.rb": "def x; end",
        ]
        for (path, content) in files {
            let url = root.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try content.write(to: url, atomically: true, encoding: .utf8)
        }
        try "notes/\n".write(to: root.appendingPathComponent(".hackatimeignore"), atomically: true, encoding: .utf8)
        let snapshot = TreeSnapshot.capture(root: root, salt: String(repeating: "11", count: 32))
        XCTAssertEqual(snapshot.entries.map(\.path), [".hackatimeignore", "app.rb", "lib/util.rb"])
        XCTAssertEqual(snapshot.entries[1].leaf, EvidenceProtocol.merkleLeaf(salt: snapshot.salt, path: "app.rb", content: Data("puts 1".utf8)))
    }

    func testNeverListWinsOverProjectMatch() {
        let classifier = FocusClassifier(projectNames: ["sync-app"])
        let bank = FocusSample(bundleID: "com.google.Chrome", appName: "Chrome", title: "sync-app invoice", url: "https://www.monzo.com/x")
        XCTAssertFalse(classifier.isCaptureAllowed(bank))
        XCTAssertEqual(classifier.classify(bank).label, .unrelated)
        let vault = FocusSample(bundleID: "com.1password.1password", appName: "1Password", title: "sync-app deploy key")
        XCTAssertFalse(classifier.isCaptureAllowed(vault))
        let editor = FocusSample(bundleID: "com.microsoft.VSCode", appName: "Code", title: "main.swift — sync-app")
        XCTAssertEqual(classifier.classify(editor).label, .project)
        XCTAssertTrue(classifier.isCaptureAllowed(editor))
        let docs = FocusSample(bundleID: "com.apple.Safari", appName: "Safari", title: "Array", url: "https://developer.mozilla.org/en-US/")
        XCTAssertEqual(classifier.classify(docs).label, .research)
        let reels = FocusSample(bundleID: "com.apple.Safari", appName: "Safari", title: "Reels", url: "https://www.instagram.com/reels")
        XCTAssertEqual(classifier.classify(reels).label, .unrelated)
        let local = FocusSample(bundleID: "com.google.Chrome", appName: "Chrome", title: "My app", url: "http://localhost:5173/")
        XCTAssertEqual(classifier.classify(local).label, .project)
    }

    func testJigglerScoresHighAndHumanTypingScoresLow() {
        var jiggle = InputMinute()
        for i in 0 ..< 60 { jiggle.recordMove(x: i.isMultiple(of: 2) ? 100 : 101, y: 200, at: Double(i), injected: false) }
        XCTAssertGreaterThanOrEqual(jiggle.jiggler, 0.8)

        var human = InputMinute()
        var t = 0.0
        let gaps = [0.08, 0.31, 0.12, 0.9, 0.05, 0.22, 1.4, 0.11, 0.17, 0.6, 0.09, 0.35, 0.07, 2.1, 0.14]
        for gap in gaps + gaps { t += gap; human.recordKey(at: t, injected: false) }
        for i in 0 ..< 30 { human.recordMove(x: Double(i * i), y: Double(i * 7 % 13) * 9, at: Double(i) * 0.37, injected: false) }
        XCTAssertEqual(human.jiggler, 0)
        XCTAssertGreaterThan(human.rhythm ?? 0, 0.6)

        var script = InputMinute()
        for i in 0 ..< 40 { script.recordKey(at: Double(i) * 0.1, injected: true) }
        XCTAssertLessThan(script.rhythm ?? 1, 0.1)
        XCTAssertEqual(script.injected, 40)
    }
}
