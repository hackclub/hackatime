import AppKit
import Foundation
@testable import HackatimeDesktop
@testable import HackatimeDesktopCore
import XCTest

/// Answers the agent's requests in place of the server.
final class StubServer: URLProtocol {
    nonisolated(unsafe) static var handler: (URLRequest) -> (Int, Any) = { _ in (404, [:]) }
    nonisolated(unsafe) static var requests: [String] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        Self.requests.append("\(request.httpMethod ?? "GET") \(request.url?.path ?? "")")
        let (status, body) = Self.handler(request)
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
