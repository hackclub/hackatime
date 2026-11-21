import XCTest
@testable import HackatimeDesktopCore

final class ShipTimelineTests: XCTestCase {
    let editor = FocusSample(bundleID: "com.microsoft.VSCode", appName: "Code", title: "main.swift — sync-app")
    let safari = FocusSample(bundleID: "com.apple.Safari", appName: "Safari", title: "Swift docs", url: "https://www.swift.org/documentation/")
    let chat = FocusSample(bundleID: "com.tinyspeck.slackmacgap", appName: "Slack", title: "#family (DM with Mum)")

    /// Minute `m` of the test day starts here; a block sealed for it carries minute `m + 1`.
    func ms(_ minute: Int, _ second: Int = 0) -> Int64 { Int64(29_000_000 + minute) * 60_000 + Int64(second) * 1000 }

    func entry(_ seq: Int, coveringMinute minute: Int, project: String? = "sync-app", active: Bool = true) -> ShipLedger.Entry {
        .init(seq: seq, minute: 29_000_000 + minute + 1, project: project, active: active)
    }

    func testSamplesOfOneWindowJoinAndAPauseLeavesAGap() {
        var log = ActivityLog()
        for second in stride(from: 0, to: 30, by: 5) { log.record(editor, label: .project, atMs: ms(0, second)) }
        log.record(safari, label: .research, atMs: ms(0, 30))
        // Tracking was paused for two minutes, then the editor again.
        log.record(editor, label: .project, atMs: ms(2, 30))
        log.record(editor, label: .project, atMs: ms(2, 35))

        XCTAssertEqual(log.segments.map(\.app), ["Code", "Safari", "Code"])
        XCTAssertEqual(log.segments[0].startMs, ms(0, 0))
        XCTAssertEqual(log.segments[0].endMs, ms(0, 30))
        XCTAssertEqual(log.segments[1].endMs, ms(0, 35), "one sample stands for five seconds, not for the pause after it")
        XCTAssertEqual(log.segments[1].site, "swift.org")
        XCTAssertEqual(log.segments[2].startMs, ms(2, 30))
        XCTAssertEqual(log.segments[2].endMs, ms(2, 40))
    }

    func testNeverListedWindowsKeepTheirAppButNotTheirTitle() {
        var log = ActivityLog()
        log.record(chat, label: .unrelated, atMs: ms(0))
        let bank = FocusSample(bundleID: "com.apple.Safari", appName: "Safari", title: "Accounts", url: "https://www.bankofamerica.com/accounts")
        log.record(bank, label: .unrelated, atMs: ms(0, 5))
        XCTAssertEqual(log.segments.map(\.app), ["Slack", "Safari"])
        XCTAssertEqual(log.segments.map(\.title), ["", ""])
        XCTAssertEqual(log.segments.map(\.site), [nil, nil])
        XCTAssertFalse(String(decoding: try! JSONEncoder().encode(log), as: UTF8.self).contains("Mum"))
    }

    func testOldSegmentsAreDropped() {
        var log = ActivityLog()
        log.record(editor, label: .project, atMs: ms(0))
        log.record(safari, label: .research, atMs: ms(3 * 24 * 60 + 5))
        XCTAssertEqual(log.segments.map(\.app), ["Safari"])
    }

    /// Minutes 0 to 4: editor, editor then 10 s of Slack, Safari, (another
    /// project), editor.
    func makeTimeline() -> ShipTimeline {
        var log = ActivityLog()
        for second in stride(from: 0, to: 110, by: 5) { log.record(editor, label: .project, atMs: ms(0, second)) }
        log.record(chat, label: .unrelated, atMs: ms(1, 50))
        log.record(chat, label: .unrelated, atMs: ms(1, 55))
        for second in stride(from: 0, to: 60, by: 5) { log.record(safari, label: .research, atMs: ms(2, second)) }
        for second in stride(from: 0, to: 60, by: 5) { log.record(editor, label: .project, atMs: ms(4, second)) }
        let entries = [
            entry(7, coveringMinute: 0), entry(8, coveringMinute: 1), entry(9, coveringMinute: 2),
            entry(10, coveringMinute: 3, project: "blog"), entry(11, coveringMinute: 4), entry(12, coveringMinute: 5),
        ]
        return ShipTimeline(project: "Sync-App", entries: entries, range: 7 ... 11, activity: log)
    }

    func testMinutesShowWhatWasInFrontWhileTheyWereRecorded() {
        let timeline = makeTimeline()
        XCTAssertEqual(timeline.minutes.map(\.seq), [7, 8, 9, 10, 11])
        XCTAssertEqual(timeline.minutes[0].startMs, ms(0), "a block describes the minute before it was sealed")
        XCTAssertEqual(timeline.minutes.map { $0.activity.map(\.app) }, [["Code"], ["Code", "Slack"], ["Safari"], [], ["Code"]])
        XCTAssertEqual(timeline.minutes.map(\.counts), [true, true, true, false, true], "another project's minute does not count")
        XCTAssertEqual(timeline.keptCountedMinutes, 4)

        let apps = timeline.apps
        XCTAssertEqual(apps.map(\.app), ["Code", "Safari", "Slack"])
        XCTAssertEqual(apps.map(\.seconds), [170, 60, 10])
        XCTAssertEqual(apps.map(\.minutes), [[0, 1, 4], [2], [1]])
    }

    func testRemovingAnAppRemovesEveryMinuteItWasInFrontIn() {
        var timeline = makeTimeline()
        timeline.setRemoved(true, bundleID: "com.tinyspeck.slackmacgap")
        XCTAssertEqual(timeline.removed, [1], "ten seconds of Slack take the whole minute: its frame may show it")
        XCTAssertEqual(timeline.keptCountedMinutes, 3)
        XCTAssertEqual(timeline.excludedRanges, [8 ... 8])

        timeline.setRemoved(true, positions: 2 ... 3)
        timeline.setRemoved(true, positions: [9])
        XCTAssertEqual(timeline.excludedRanges, [8 ... 10], "neighbouring minutes merge into one range")
        timeline.setRemoved(false, positions: [2])
        XCTAssertEqual(timeline.excludedRanges, [8 ... 8, 10 ... 10])
        timeline.setRemoved(false, bundleID: "com.tinyspeck.slackmacgap")
        XCTAssertEqual(timeline.excludedRanges, [10 ... 10])
        XCTAssertEqual(timeline.keptCountedMinutes, 4, "the removed minute never counted")
    }

    func testAppsListTheirWindowsTheLongestFirst() {
        var log = ActivityLog()
        let other = FocusSample(bundleID: "com.microsoft.VSCode", appName: "Code", title: "Vault.swift — sync-app")
        for second in stride(from: 0, to: 20, by: 5) { log.record(other, label: .project, atMs: ms(0, second)) }
        for second in stride(from: 20, to: 60, by: 5) { log.record(editor, label: .project, atMs: ms(0, second)) }
        log.record(chat, label: .unrelated, atMs: ms(1))
        let timeline = ShipTimeline(project: "sync-app", entries: [entry(1, coveringMinute: 0), entry(2, coveringMinute: 1)], range: 1 ... 2, activity: log)
        XCTAssertEqual(timeline.apps.map(\.app), ["Code", "Slack"])
        XCTAssertEqual(timeline.apps[0].windows.map(\.title), ["main.swift — sync-app", "Vault.swift — sync-app"])
        XCTAssertEqual(timeline.apps[0].windows.map(\.seconds), [40, 20])
        XCTAssertEqual(timeline.apps[1].windows.map(\.title), [""], "a never-listed window has no title to show")
    }

    func testOnlyEditorAndTerminalTitlesThatNameASecretsFileCount() {
        func file(_ bundleID: String, _ title: String) -> String? {
            ActivitySegment(startMs: 0, endMs: 1, bundleID: bundleID, app: "", title: title).secretFile
        }
        let code = "com.microsoft.VSCode", terminal = "com.apple.Terminal"
        XCTAssertEqual(file(code, ".env — sync-app"), ".env")
        XCTAssertEqual(file(code, "● .env.production — sync-app"), ".env.production")
        XCTAssertEqual(file("com.apple.dt.Xcode", "sync-app — Secrets.xcconfig"), "Secrets.xcconfig", "whatever the case")
        XCTAssertEqual(file(terminal, "nano ~/.ssh/id_ed25519"), "id_ed25519")
        XCTAssertEqual(file(terminal, "vim \"config/server.pem\""), "server.pem")
        XCTAssertEqual(file(code, "(.npmrc) — sync-app"), ".npmrc")

        XCTAssertNil(file(code, ".env.example — sync-app"), "a template holds no values")
        XCTAssertNil(file(code, "environment.rb — sync-app"))
        XCTAssertNil(file(code, "dotenv.swift — sync-app"))
        XCTAssertNil(file(code, "main.swift — my.env"), "the name has to be .env, not end in it")
        XCTAssertNil(file("com.apple.Safari", ".env — sync-app"), "only apps whose title names the open file")
        XCTAssertNil(file(code, ""))
    }

    /// Minutes 0 to 3: editor, `.env` for ten seconds of the next, `.env`
    /// alone, editor.
    func makeTimelineWithSecrets() -> ShipTimeline {
        let env = FocusSample(bundleID: "com.microsoft.VSCode", appName: "Code", title: ".env — sync-app")
        var log = ActivityLog()
        for second in stride(from: 0, to: 110, by: 5) { log.record(editor, label: .project, atMs: ms(0, second)) }
        for second in stride(from: 50, to: 120, by: 5) { log.record(env, label: .project, atMs: ms(1, second)) }
        for second in stride(from: 0, to: 60, by: 5) { log.record(editor, label: .project, atMs: ms(3, second)) }
        return ShipTimeline(project: "sync-app", entries: (0 ... 3).map { entry(20 + $0, coveringMinute: $0) }, range: 20 ... 23, activity: log)
    }

    func testMinutesWithASecretsFileInFrontStartOutRemoved() {
        var timeline = makeTimelineWithSecrets()
        XCTAssertEqual(timeline.secretMinutes, [1, 2], "ten seconds of .env take the whole minute: its frame may show it")
        XCTAssertEqual(timeline.secretFiles, [".env"])
        XCTAssertEqual(timeline.removed, [1, 2])
        XCTAssertEqual(timeline.excludedRanges, [21 ... 22])
        XCTAssertEqual(timeline.keptCountedMinutes, 2)

        timeline.setRemoved(false, positions: timeline.secretMinutes)
        XCTAssertEqual(timeline.excludedRanges, [], "the user can put them back")
        XCTAssertEqual(timeline.keptCountedMinutes, 4)
        XCTAssertEqual(makeTimeline().removed, [], "nothing is removed from a ship without one")
    }

    func testClickingAWindowSelectsItAsFarAsItStaysInFront() {
        let timeline = makeTimeline()
        XCTAssertEqual(timeline.positions(ofWindowAt: 0.5), 0 ... 1, "the editor through both minutes, not the one after Safari")
        XCTAssertEqual(timeline.positions(ofWindowAt: 1.9), 1 ... 1, "Slack at 1:54")
        XCTAssertEqual(timeline.positions(ofWindowAt: 2.2), 2 ... 2)
        XCTAssertNil(timeline.positions(ofWindowAt: 3.5), "nothing was recorded in front")
        XCTAssertEqual(timeline.positions(ofWindowAt: 4.0), 4 ... 4)
    }
}
