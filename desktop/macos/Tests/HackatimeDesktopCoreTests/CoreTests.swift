import CryptoKit
import Foundation
import XCTest
@testable import HackatimeDesktopCore

final class CoreTests: XCTestCase {
    let beacon = Beacon(minute: 29_000_000, value: String(repeating: "ab", count: 32), commitment: String(repeating: "cd", count: 32),
                        nextExpectedAt: nil, headSeq: 0, headHash: nil)

    func testTimelapseFramesAreDueEveryIntervalUntilTheMinuteEnds() {
        func at(_ seconds: Double) -> Date { Date(timeIntervalSince1970: 29_000_000 * 60 + seconds) }
        var beacon = Beacon(minute: 29_000_000, value: self.beacon.value, commitment: self.beacon.commitment,
                            nextExpectedAt: ISO8601DateFormatter().string(from: at(7)), headSeq: 0, headHash: nil, timelapseIntervalSeconds: 20)
        XCTAssertEqual(beacon.framesDue(now: at(1)), [at(7), at(27), at(47)])
        XCTAssertEqual(beacon.framesDue(now: at(30)), [at(30), at(47)], "the two already past come down to one frame, taken now")
        XCTAssertEqual(beacon.framesDue(now: at(59)), [at(59)])
        XCTAssertEqual(beacon.framesDue(now: at(121)), [at(127), at(147), at(167)], "offline, the last beacon keeps its seconds for the next minutes")
        beacon.timelapseIntervalSeconds = nil
        XCTAssertEqual(beacon.framesDue(now: at(1)), [at(7)], "a server that names no interval gets one frame a minute")
        XCTAssertEqual(self.beacon.framesDue(now: at(1)), [], "and one that names no time gets none")
    }

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

    func testMonoKeepsRisingAfterARebootAndAcrossLaunches() throws {
        let chain = ChainState()
        let t0 = Date(timeIntervalSince1970: 1_740_000_005)
        let before = try XCTUnwrap(chain.append(payload: MinutePayload(), beacon: beacon, now: t0, monoMs: 3_600_000, key: nil))
        // The Mac restarts: uptime begins again near zero and the app reloads its chain.
        let relaunched = try JSONDecoder().decode(ChainState.self, from: JSONEncoder().encode(chain))
        let rebooted = try XCTUnwrap(relaunched.append(payload: MinutePayload(), beacon: beacon, now: t0 + 600, monoMs: 30_000, key: nil))
        let next = try XCTUnwrap(relaunched.append(payload: MinutePayload(), beacon: beacon, now: t0 + 660, monoMs: 90_000, key: nil))
        XCTAssertGreaterThan(rebooted.monoMs, before.monoMs)
        XCTAssertEqual(next.monoMs - rebooted.monoMs, 60_000, "time elapsed since the reboot is kept")
    }

    func testUnknownInputIsLeftOutOfTheBlockNotSentAsZero() throws {
        let chain = ChainState()
        var payload = MinutePayload()
        payload.focus = .project
        payload.activeS = 60
        let unknown = try XCTUnwrap(chain.append(payload: payload, beacon: beacon, now: Date(timeIntervalSince1970: 1_740_000_005), monoMs: 1, key: nil))
        let fields = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(unknown.payload.utf8)) as? [String: Any])
        for field in ["keys", "clicks", "moves", "injected", "rhythm", "jiggler"] { XCTAssertNil(fields[field], field) }

        payload.keys = 0
        payload.clicks = 0
        let idle = try XCTUnwrap(chain.append(payload: payload, beacon: beacon, now: Date(timeIntervalSince1970: 1_740_000_065), monoMs: 2, key: nil))
        XCTAssertTrue(idle.payload.contains(#""keys":0"#), idle.payload)
    }

    func testADeviceKeyThatCannotBeSavedIsAnError() {
        final class ReadOnlyStore: SecretStore {
            func read(_ name: String) -> Data? { nil }
            func write(_ name: String, _ data: Data) -> Bool { false }
            func delete(_ name: String) {}
        }
        XCTAssertThrowsError(try DeviceKey.loadOrCreate(store: ReadOnlyStore()), "a new key every launch would break signatures")
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

    func testDomainsAndProjectNamesMatchWholeNamesOnly() {
        let classifier = FocusClassifier(projectNames: ["sync-app"])
        func label(_ url: String) -> FocusLabel {
            classifier.classify(FocusSample(bundleID: "com.google.Chrome", appName: "Chrome", title: "Page", url: url)).label
        }
        XCTAssertEqual(label("https://docs.dropbox.com/api/files"), .research, "docs., not x.com")
        XCTAssertNotEqual(label("https://developer.box.com/reference"), .unrelated)
        XCTAssertEqual(label("https://x.com/home"), .unrelated)
        XCTAssertEqual(label("https://mobile.twitter.com/home"), .unrelated)
        XCTAssertEqual(label("https://reddit.com/r/all"), .unrelated)
        XCTAssertNotEqual(label("https://reddit.com/r/swift"), .unrelated)

        let repo = FocusSample(bundleID: "com.google.Chrome", appName: "Chrome", title: "Repo", url: "https://github.com/me/bank-statement-parser")
        XCTAssertFalse(FocusClassifier.isNever(repo), "bank in a path is not a bank")
        XCTAssertTrue(FocusClassifier.isNever(FocusSample(bundleID: "com.google.Chrome", appName: "Chrome", title: "", url: "https://www.bankofamerica.com/")))
        XCTAssertTrue(FocusClassifier.isNever(FocusSample(bundleID: "com.google.Chrome", appName: "Chrome", title: "", url: "https://stripe.com/dashboard/payments")))

        let site = FocusClassifier(projectNames: ["site"])
        let other = site.classify(FocusSample(bundleID: "com.microsoft.VSCode", appName: "Code", title: "index.html — client-website-redesign"))
        XCTAssertNil(other.project)
        XCTAssertEqual(site.classify(FocusSample(bundleID: "com.microsoft.VSCode", appName: "Code", title: "index.html — site")).project, "site")
        XCTAssertEqual(site.classify(FocusSample(bundleID: "com.apple.Terminal", appName: "Terminal", title: "me@mac: ~/code/site/app")).project, "site")
    }

    func testEditorWithoutAccessibilityUsesTheActiveProject() {
        let classifier = FocusClassifier(projectNames: ["sync-app", "Blog"])
        let untitled = FocusSample(bundleID: "com.microsoft.VSCode", appName: "Code", title: "")
        XCTAssertEqual(classifier.classify(untitled).label, .unknown)
        XCTAssertTrue(classifier.classify(untitled, activeProject: "Blog") == (.project, "blog"))
        XCTAssertTrue(classifier.isCaptureAllowed(untitled, activeProject: "Blog"))
        let terminal = FocusSample(bundleID: "com.apple.Terminal", appName: "Terminal", title: "")
        XCTAssertEqual(classifier.classify(terminal, activeProject: "sync-app").label, .project)
        // A readable title that names no project is not overridden.
        let other = FocusSample(bundleID: "com.microsoft.VSCode", appName: "Code", title: "notes.txt — scratch")
        XCTAssertEqual(classifier.classify(other, activeProject: "sync-app").label, .unknown)
    }

    func testAIInboxKeepsEventsAcrossRelaunchesAndCountsEachOnce() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("ai-events.jsonl")
        let now = 1_740_000_000.0
        func append(_ text: String) throws {
            if !FileManager.default.fileExists(atPath: url.path) { FileManager.default.createFile(atPath: url.path, contents: nil) }
            let handle = try FileHandle(forWritingTo: url)
            handle.seekToEndOfFile()
            handle.write(Data(text.utf8))
            try handle.close()
        }
        let prompt = #"{"tool":"claude-code","event":"prompt","at":\#(now - 30),"ai_lines":5}"# + "\n"

        try append(prompt + prompt)                      // written before the app started
        XCTAssertEqual(AIInbox(url: url).drain(now: now)?.prompts, 2)
        try append(prompt)
        let relaunched = AIInbox(url: url)
        XCTAssertEqual(relaunched.drain(now: now)?.prompts, 1, "only the event written since the last drain")
        XCTAssertNil(AIInbox(url: url).drain(now: now), "nothing is counted twice after another relaunch")

        // A line still being written waits for its newline.
        try append(String(prompt.dropLast(10)))
        XCTAssertEqual(relaunched.drain(now: now)?.prompts ?? 0, 0)
        try append(String(prompt.suffix(10)))
        XCTAssertEqual(relaunched.drain(now: now)?.aiLines, 5)

        // Events from long before the minute being built are not credited to it.
        try append(#"{"tool":"codex","event":"prompt","at":\#(now - 7_200)}"# + "\n")
        XCTAssertEqual(relaunched.drain(now: now)?.prompts ?? 0, 0)
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
