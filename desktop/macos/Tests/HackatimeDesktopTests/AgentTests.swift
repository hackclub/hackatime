import AppKit
import Foundation
@testable import HackatimeDesktop
@testable import HackatimeDesktopCore
import XCTest

/// Answers the agent's requests in place of the server.
final class StubServer: URLProtocol {
    nonisolated(unsafe) static var handler: (URLRequest) -> (Int, Any) = { _ in (404, [:]) }
    nonisolated(unsafe) static var requests: [String] = []
    nonisolated(unsafe) static var delay: TimeInterval = 0

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        Self.requests.append("\(request.httpMethod ?? "GET") \(request.url?.path ?? "")")
        let (status, body) = Self.handler(request)
        if Self.delay > 0 { Thread.sleep(forTimeInterval: Self.delay) }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: (try? JSONSerialization.data(withJSONObject: body)) ?? Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    static var session: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubServer.self]
        return URLSession(configuration: configuration)
    }

    static func beacon(headSeq: Int = 0) -> [String: Any] {
        ["minute": Int(Date().timeIntervalSince1970 / 60), "value": String(repeating: "ab", count: 32),
         "commitment": String(repeating: "cd", count: 32), "head_seq": headSeq]
    }
}

@MainActor
final class AgentTests: XCTestCase {
    var support: URL!
    var store: MemoryStore!

    override func setUp() async throws {
        _ = NSApplication.shared
        support = FileManager.default.temporaryDirectory.appendingPathComponent("hkt-agent-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try JSONEncoder().encode(Settings(baseURL: "https://hackatime.test")).write(to: support.appendingPathComponent("settings.json"))
        store = MemoryStore()
        store.write("device-token", Data("token".utf8))
        StubServer.requests = []
        StubServer.delay = 0
    }

    func makeAgent() -> Agent { Agent(support: support, store: store, session: StubServer.session) }

    func testRefusedBlocksAreReportedNotShownAsTracking() async {
        StubServer.handler = { request in
            if request.url!.path.hasSuffix("/beacon") { return (200, StubServer.beacon()) }
            return (409, ["accepted": 0, "head_seq": 0, "head_hash": EvidenceProtocol.zeroHash,
                          "error": ["code": "not_monotonic", "message": "mono_ms must increase"]])
        }
        let agent = makeAgent()
        await agent.tick()
        XCTAssertTrue(agent.status.contains("mono_ms must increase"), agent.status)
        XCTAssertTrue(agent.chain.pending.isEmpty)
    }

    func testDeviceUnpairedOnTheSiteStopsRecording() async {
        StubServer.handler = { _ in (401, ["error": "Unauthorized"]) }
        let agent = makeAgent()
        await agent.tick()
        XCTAssertFalse(agent.isPaired)
        XCTAssertNil(store.read("device-token"))
        XCTAssertTrue(agent.chain.pending.isEmpty, "nothing is queued for a revoked device")

        StubServer.requests = []
        await agent.tick()
        XCTAssertEqual(StubServer.requests, [], "an unpaired Mac stops calling the server")
        XCTAssertFalse(Agent(support: support, store: store, session: StubServer.session).isPaired, "stays unpaired after a relaunch")
    }

    func testActiveProjectIsWhereFilesLastChanged() {
        let agent = makeAgent()
        XCTAssertNil(agent.activeProject)
        agent.settings.projects = ["/Users/me/code/sync-app"]
        XCTAssertEqual(agent.activeProject, "sync-app", "the only project")
        agent.settings.projects.append("/Users/me/code/blog")
        XCTAssertNil(agent.activeProject, "no edits yet, two projects")
        agent.recordFileEvents(["/Users/me/code/blog/posts/hello.md"])
        XCTAssertEqual(agent.activeProject, "blog")
    }

    func testKeyEnrolmentIsRetriedUntilItSucceeds() async {
        var settings = Settings(baseURL: "https://hackatime.test")
        settings.deviceUID = "dev_1"
        try? JSONEncoder().encode(settings).write(to: support.appendingPathComponent("settings.json"))
        var keyStatus = 503
        StubServer.handler = { request in
            switch request.url!.path {
            case let path where path.hasSuffix("/beacon"): return (200, StubServer.beacon())
            case let path where path.hasSuffix("/key"): return (keyStatus, [:])
            default: return (201, ["accepted": 1, "head_seq": 1, "head_hash": EvidenceProtocol.zeroHash])
            }
        }
        let agent = makeAgent()
        agent.loadKey()
        await agent.tick()
        XCTAssertFalse(agent.settings.keyEnrolled)
        keyStatus = 200
        await agent.tick()
        XCTAssertTrue(agent.settings.keyEnrolled, "the next minute retries the enrolment")
    }

    func testFailedUnpairKeepsTheToken() async {
        StubServer.handler = { _ in (503, [:]) }
        let agent = makeAgent()
        let failure = await agent.unpair()
        XCTAssertNotNil(failure)
        XCTAssertTrue(agent.isPaired, "the device is still active on the server")
        StubServer.handler = { _ in (204, [:]) }
        let none = await agent.unpair()
        XCTAssertNil(none)
        XCTAssertFalse(agent.isPaired)
    }

    func testRepairingClearsSnapshotsFromTheOldChain() throws {
        let old = TreeSnapshot(salt: String(repeating: "2", count: 64), entries: [])
        try JSONEncoder().encode([5: old]).write(to: support.appendingPathComponent("snapshots.json"))
        let agent = makeAgent()
        XCTAssertNotNil(agent.snapshot(at: 5))
        agent.startNewChain()
        XCTAssertNil(agent.snapshot(at: 5))
        XCTAssertNil(makeAgent().snapshot(at: 5), "also on disk")
    }

    func testTodayCountsTodaysMinutesAcrossRelaunches() {
        let agent = makeAgent()
        agent.countTrackedMinute(at: Date().addingTimeInterval(-86_400))
        agent.countTrackedMinute(at: Date())
        agent.countTrackedMinute(at: Date())
        XCTAssertEqual(agent.todayMinutes, 2, "yesterday's minute is not today's")
        XCTAssertEqual(makeAgent().todayMinutes, 2, "kept across a relaunch")
    }

    func testATickWaitsForTheOneBeforeIt() async {
        StubServer.handler = { request in
            request.url!.path.hasSuffix("/beacon") ? (200, StubServer.beacon())
                : (201, ["accepted": 1, "head_seq": 1, "head_hash": EvidenceProtocol.zeroHash])
        }
        StubServer.delay = 0.3
        let agent = makeAgent()
        async let first: Void = agent.tick()
        async let second: Void = agent.tick()
        _ = await (first, second)
        XCTAssertEqual(StubServer.requests.filter { $0.hasSuffix("/beacon") }.count, 1, "\(StubServer.requests)")
    }

    func testRevokedTokenWhileSendingBlocksAlsoUnpairs() async {
        StubServer.handler = { request in
            request.url!.path.hasSuffix("/beacon") ? (200, StubServer.beacon()) : (401, ["error": "Unauthorized"])
        }
        let agent = makeAgent()
        await agent.tick()
        XCTAssertFalse(agent.isPaired)
        XCTAssertFalse(agent.status.contains("Queued"), agent.status)
    }
}
