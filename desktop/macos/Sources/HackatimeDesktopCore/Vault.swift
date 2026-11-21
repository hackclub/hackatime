import CryptoKit
import Foundation

/// Local evidence vault. Frames are grouped into 5-minute segments; each
/// segment has its own random 256-bit key, which is stored only wrapped
/// (ChaChaPoly) by a vault key kept in the Keychain. Only the SHA-256 of each
/// encrypted frame goes into the chain. Destroying a segment's wrapped key
/// crypto-shreds it; unshipped segments are shredded after 30 days.
public protocol BlobStore {
    func put(_ content: Data, hash: String)
    func get(hash: String) -> Data?
}

public final class Vault: BlobStore {
    public static let segmentSeconds: Int64 = 300
    public static let retentionDays = 30

    public struct StoredFrame: Codable, Equatable {
        public let hash: String
        public let segment: Int64
        public let capturedAtMs: Int64
        public var shipped: Bool
    }

    public struct AccessEntry: Codable, Equatable {
        public let at: Date
        public let action: String
        public let detail: String
    }

    let directory: URL
    private let store: SecretStore
    private var vaultKey: SymmetricKey
    private(set) public var frames: [StoredFrame] = []
    private(set) public var accessLog: [AccessEntry] = []
    private var wrappedKeys: [Int64: Data] = [:]
    private let lock = NSLock()

    public init(directory: URL, store: SecretStore) throws {
        self.directory = directory
        self.store = store
        try FileManager.default.createDirectory(at: directory.appendingPathComponent("frames"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: directory.appendingPathComponent("blobs"), withIntermediateDirectories: true)
        if let raw = store.read("vault-key"), raw.count == 32 {
            vaultKey = SymmetricKey(data: raw)
        } else {
            let fresh = SymmetricKey(size: .bits256)
            store.write("vault-key", fresh.withUnsafeBytes { Data($0) })
            vaultKey = fresh
        }
        load()
    }

    /// Encrypts a frame with its segment key and returns the hash to chain.
    public func store(frame plaintext: Data, capturedAtMs: Int64) throws -> StoredFrame {
        lock.lock(); defer { lock.unlock() }
        let segment = capturedAtMs / 1000 / Self.segmentSeconds
        let key = try segmentKey(segment, create: true)!
        let sealed = try EvidenceProtocol.seal(plaintext, key: key)
        let hash = EvidenceProtocol.sha256Hex(sealed)
        try sealed.write(to: framePath(hash), options: [.atomic, .completeFileProtection])
        let frame = StoredFrame(hash: hash, segment: segment, capturedAtMs: capturedAtMs, shipped: false)
        frames.append(frame)
        save()
        return frame
    }

    // MARK: Snapshot blobs (local only, encrypted with the vault key)

    public func put(_ content: Data, hash: String) {
        let url = blobPath(hash)
        guard !FileManager.default.fileExists(atPath: url.path),
              let sealed = try? ChaChaPoly.seal(content, using: vaultKey).combined else { return }
        try? sealed.write(to: url, options: [.atomic, .completeFileProtection])
    }

    public func get(hash: String) -> Data? {
        guard let sealed = try? Data(contentsOf: blobPath(hash)),
              let box = try? ChaChaPoly.SealedBox(combined: sealed) else { return nil }
        return try? ChaChaPoly.open(box, using: vaultKey)
    }

    private func blobPath(_ hash: String) -> URL { directory.appendingPathComponent("blobs/\(hash)") }

    public func ciphertext(_ hash: String) throws -> Data { try Data(contentsOf: framePath(hash)) }

    /// Decrypts locally for the user's own preview, and logs the access.
    public func preview(_ hash: String) throws -> Data {
        lock.lock(); defer { lock.unlock() }
        guard let frame = frames.first(where: { $0.hash == hash }), let key = try segmentKey(frame.segment, create: false) else {
            throw CocoaError(.fileNoSuchFile)
        }
        log("preview", hash)
        return try EvidenceProtocol.open(try Data(contentsOf: framePath(hash)), key: key)
    }

    /// The raw segment key for one frame, released only when the user ships.
    public func releaseKey(for hash: String) throws -> Data {
        lock.lock(); defer { lock.unlock() }
        guard let index = frames.firstIndex(where: { $0.hash == hash }), let key = try segmentKey(frames[index].segment, create: false) else {
            throw CocoaError(.fileNoSuchFile)
        }
        frames[index].shipped = true
        log("ship", hash)
        save()
        return key.withUnsafeBytes { Data($0) }
    }

    /// Re-encrypts a user-redacted copy under the same segment key. The
    /// server stores it against the committed hash and marks it redacted.
    public func sealRedacted(_ plaintext: Data, for hash: String) throws -> Data {
        lock.lock(); defer { lock.unlock() }
        guard let frame = frames.first(where: { $0.hash == hash }), let key = try segmentKey(frame.segment, create: false) else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try EvidenceProtocol.seal(plaintext, key: key)
    }

    /// Crypto-shreds unshipped segments older than the retention period.
    @discardableResult
    public func shredExpired(now: Date = Date()) -> Int {
        lock.lock(); defer { lock.unlock() }
        let cutoff = Int64(now.timeIntervalSince1970) / Self.segmentSeconds - Int64(Self.retentionDays * 86_400) / Self.segmentSeconds
        let shippedSegments = Set(frames.filter(\.shipped).map(\.segment))
        let expired = Set(frames.map(\.segment).filter { $0 < cutoff && !shippedSegments.contains($0) })
        shred(segments: expired)
        return expired.count
    }

    /// "Delete everything": replaces the Keychain vault key, so a copy or
    /// backup of the vault made before (wrapped segment keys, frames and
    /// snapshot blobs) can no longer be decrypted, then removes every file.
    public func deleteEverything() {
        lock.lock(); defer { lock.unlock() }
        let fresh = SymmetricKey(size: .bits256)
        store.write("vault-key", fresh.withUnsafeBytes { Data($0) })
        vaultKey = fresh
        wrappedKeys = [:]
        frames = []
        accessLog = []
        for folder in ["frames", "blobs"] {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(folder))
            try? FileManager.default.createDirectory(at: directory.appendingPathComponent(folder), withIntermediateDirectories: true)
        }
        log("delete_everything", "")
        save()
    }

    private func shred(segments: Set<Int64>) {
        guard !segments.isEmpty else { return }
        for segment in segments { wrappedKeys[segment] = nil }
        for frame in frames where segments.contains(frame.segment) {
            try? FileManager.default.removeItem(at: framePath(frame.hash))
        }
        frames.removeAll { segments.contains($0.segment) }
        log("shred", "\(segments.count) segments")
        save()
    }

    private func segmentKey(_ segment: Int64, create: Bool) throws -> SymmetricKey? {
        if let wrapped = wrappedKeys[segment] {
            return SymmetricKey(data: try ChaChaPoly.open(ChaChaPoly.SealedBox(combined: wrapped), using: vaultKey))
        }
        guard create else { return nil }
        let key = SymmetricKey(size: .bits256)
        wrappedKeys[segment] = try ChaChaPoly.seal(key.withUnsafeBytes { Data($0) }, using: vaultKey).combined
        return key
    }

    private func log(_ action: String, _ detail: String) {
        accessLog.append(AccessEntry(at: Date(), action: action, detail: detail))
        if accessLog.count > 1_000 { accessLog.removeFirst(accessLog.count - 1_000) }
    }

    private func framePath(_ hash: String) -> URL { directory.appendingPathComponent("frames/\(hash).bin") }

    private struct Index: Codable {
        var frames: [StoredFrame]
        var wrappedKeys: [String: Data]
        var accessLog: [AccessEntry]
    }

    private func save() {
        let index = Index(frames: frames, wrappedKeys: Dictionary(uniqueKeysWithValues: wrappedKeys.map { (String($0.key), $0.value) }), accessLog: accessLog)
        try? JSONEncoder().encode(index).write(to: directory.appendingPathComponent("index.json"), options: [.atomic, .completeFileProtection])
    }

    private func load() {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent("index.json")),
              let index = try? JSONDecoder().decode(Index.self, from: data) else { return }
        frames = index.frames
        accessLog = index.accessLog
        wrappedKeys = Dictionary(uniqueKeysWithValues: index.wrappedKeys.compactMap { key, value in Int64(key).map { ($0, value) } })
    }
}
