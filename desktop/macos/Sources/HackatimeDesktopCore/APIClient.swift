import Foundation

/// Hackatime Desktop API (app/controllers/api/desktop/v1/desktop_controller.rb).
public final class APIClient {
    public struct Failure: Error, CustomStringConvertible {
        public let status: Int
        public let body: String
        public var description: String { "HTTP \(status): \(body)" }
        public init(status: Int, body: String) { self.status = status; self.body = body }
    }

    public struct BlocksResponse: Codable {
        public struct Rejection: Codable { public let code: String; public let message: String }
        public let accepted: Int
        public let headSeq: Int
        public let headHash: String
        public let error: Rejection?
        enum CodingKeys: String, CodingKey { case accepted, error; case headSeq = "head_seq", headHash = "head_hash" }
    }

    public let baseURL: URL
    public var token: String?
    let session: URLSession

    public init(baseURL: URL, token: String? = nil, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.token = token
        self.session = session
    }

    /// The companion site's page where the signed-in student agrees to the
    /// timelapse and approves this device (desktop/site/src/routes/pair).
    public func pairingURL(site: URL, challenge: String, deviceName: String) -> URL {
        var components = URLComponents(url: site.appendingPathComponent("pair"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "challenge", value: challenge), URLQueryItem(name: "name", value: deviceName)]
        return components.url!
    }

    public func pair(code: String, verifier: String, name: String, appVersion: String) async throws -> (token: String, device: [String: Any]) {
        let json = try await request("POST", "api/desktop/v1/pair", body: [
            "code": code, "code_verifier": verifier, "name": name, "platform": "macos", "app_version": appVersion,
        ])
        guard let token = json["token"] as? String else { throw Failure(status: 200, body: "missing token") }
        return (token, json["device"] as? [String: Any] ?? [:])
    }

    public func beacon() async throws -> Beacon {
        try JSONDecoder().decode(Beacon.self, from: try await raw("GET", "api/desktop/v1/beacon", body: nil))
    }

    public func enrolKey(_ key: DeviceKey, hardwareID: String?, appAttest: [String: String]? = nil) async throws -> [String: Any] {
        var body: [String: Any] = ["public_key": key.publicKeyDER.base64EncodedString(), "key_tier": key.tier.rawValue]
        if let hardwareID { body["hardware_id"] = hardwareID }
        if let appAttest { body["app_attest"] = appAttest }
        return try await request("POST", "api/desktop/v1/key", body: body)
    }

    /// 409 means the server rejected a block: the response still reports the
    /// head, so the caller can resync.
    public func send(blocks: [Block]) async throws -> BlocksResponse {
        let body = try JSONEncoder().encode(["blocks": blocks])
        let (data, status) = try await perform("POST", "api/desktop/v1/blocks", data: body)
        guard status == 201 || status == 409 else { throw Failure(status: status, body: String(decoding: data, as: UTF8.self)) }
        return try JSONDecoder().decode(BlocksResponse.self, from: data)
    }

    public func unpair() async throws { _ = try await raw("DELETE", "api/desktop/v1/me", body: nil) }

    public func request(_ method: String, _ path: String, body: [String: Any]?) async throws -> [String: Any] {
        let data = try await raw(method, path, body: body)
        if data.isEmpty { return [:] }
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    func raw(_ method: String, _ path: String, body: [String: Any]?) async throws -> Data {
        let (data, status) = try await perform(method, path, data: try body.map { try JSONSerialization.data(withJSONObject: $0) })
        guard (200 ..< 300).contains(status) else { throw Failure(status: status, body: String(decoding: data, as: UTF8.self)) }
        return data
    }

    func perform(_ method: String, _ path: String, data: Data?) async throws -> (Data, Int) {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("hackatime-desktop/\(Self.version)", forHTTPHeaderField: "User-Agent")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let data {
            request.httpBody = data
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (body, response) = try await session.data(for: request)
        return (body, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }

    /// The app's version from Info.plist; "dev" when run outside the app bundle.
    public static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
}
