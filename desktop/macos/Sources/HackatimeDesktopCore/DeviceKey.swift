import CryptoKit
import Foundation
import Security

/// The device's signing key. On a Mac with a Secure Enclave the private key
/// never leaves it; otherwise a software P-256 key in the Keychain is used.
/// Hardware is only a small confidence bonus on the server, never required.
public final class DeviceKey {
    public enum Tier: String { case software, secureEnclave = "secure_enclave" }

    public let tier: Tier
    private let sign: (Data) throws -> Data
    public let publicKeyDER: Data

    private init(tier: Tier, publicKeyDER: Data, sign: @escaping (Data) throws -> Data) {
        self.tier = tier
        self.publicKeyDER = publicKeyDER
        self.sign = sign
    }

    /// Signs the 32 raw bytes of a block hash. CryptoKit hashes them with
    /// SHA-256 first, which is what the server's `verify("SHA256", …)` expects.
    public func signature(forHashHex hex: String) throws -> String {
        try sign(Data(hex: hex)).base64EncodedString()
    }

    /// Loads the stored key or creates one. `store` persists the opaque key
    /// blob (a Secure Enclave key reference, or software key bytes).
    public static func loadOrCreate(store: SecretStore) throws -> DeviceKey {
        if let blob = store.read("device-key"), let key = try? restore(blob) { return key }
        // A key that cannot be stored would be replaced on the next launch,
        // and the server would reject its signatures.
        if SecureEnclave.isAvailable, let key = try? SecureEnclave.P256.Signing.PrivateKey() {
            guard store.write("device-key", Data("se:".utf8) + key.dataRepresentation) else { throw StoreError.writeFailed("device-key") }
            return wrap(key)
        }
        let key = P256.Signing.PrivateKey()
        guard store.write("device-key", Data("sw:".utf8) + key.rawRepresentation) else { throw StoreError.writeFailed("device-key") }
        return wrap(key)
    }

    static func restore(_ blob: Data) throws -> DeviceKey {
        let prefix = String(decoding: blob.prefix(3), as: UTF8.self)
        let body = blob.dropFirst(3)
        switch prefix {
        case "se:": return wrap(try SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: body))
        case "sw:": return wrap(try P256.Signing.PrivateKey(rawRepresentation: body))
        default: throw CocoaError(.coderReadCorrupt)
        }
    }

    static func wrap(_ key: SecureEnclave.P256.Signing.PrivateKey) -> DeviceKey {
        DeviceKey(tier: .secureEnclave, publicKeyDER: key.publicKey.derRepresentation) {
            try key.signature(for: $0).derRepresentation
        }
    }

    static func wrap(_ key: P256.Signing.PrivateKey) -> DeviceKey {
        DeviceKey(tier: .software, publicKeyDER: key.publicKey.derRepresentation) {
            try key.signature(for: $0).derRepresentation
        }
    }
}

/// Small Keychain wrapper (generic passwords, this device only).
public protocol SecretStore {
    func read(_ name: String) -> Data?
    /// Returns whether the value was saved.
    @discardableResult func write(_ name: String, _ data: Data) -> Bool
    func delete(_ name: String)
}

public enum StoreError: LocalizedError, CustomStringConvertible {
    case writeFailed(String)
    public var description: String {
        switch self { case .writeFailed(let name): "Could not save \(name) to the Keychain" }
    }
    public var errorDescription: String? { description }
}

public final class KeychainStore: SecretStore {
    let service: String
    public init(service: String = "com.hackclub.hackatime.desktop") { self.service = service }

    private func query(_ name: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: name]
    }

    public func read(_ name: String) -> Data? {
        var query = query(name)
        query[kSecReturnData as String] = true
        var result: AnyObject?
        return SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess ? result as? Data : nil
    }

    /// Updates the item in place, so a failed write keeps the old value
    /// rather than deleting it first.
    @discardableResult
    public func write(_ name: String, _ data: Data) -> Bool {
        let attributes: [String: Any] = [kSecValueData as String: data,
                                         kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        var status = SecItemUpdate(query(name) as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query(name).merging(attributes) { $1 } as CFDictionary, nil)
        }
        if status != errSecSuccess { NSLog("Keychain write of \(name) failed: \(status)") }
        return status == errSecSuccess
    }

    public func delete(_ name: String) { SecItemDelete(query(name) as CFDictionary) }
}

/// In-memory store for tests.
public final class MemoryStore: SecretStore {
    var values: [String: Data] = [:]
    public init() {}
    public func read(_ name: String) -> Data? { values[name] }
    @discardableResult public func write(_ name: String, _ data: Data) -> Bool { values[name] = data; return true }
    public func delete(_ name: String) { values[name] = nil }
}
