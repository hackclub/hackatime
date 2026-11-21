import CryptoKit
import Foundation

/// Salted Merkle snapshot of a project's working tree: one leaf per file,
/// sorted by path bytes. Secrets, dependencies, build output, large files
/// and anything in .hackatimeignore are never read or hashed. Only the root
/// leaves the machine while working; at ship the leaf list is kept locally so
/// spot-checked snapshots can be disclosed (shipped files) or proven (leaf
/// hashes for everything else).
public struct TreeSnapshot: Codable, Equatable {
    public struct Entry: Codable, Equatable {
        public let path: String
        public let leaf: String
        /// SHA-256 of the content, the key of its copy in the local blob store.
        public let content: String?
    }

    public let salt: String
    public let entries: [Entry]
    public var root: String { EvidenceProtocol.merkleRoot(entries.map(\.leaf)) }

    /// The server's limits (ShipLimits), so a spot-checked snapshot can be
    /// disclosed in full.
    public static let maxFileBytes = ShipLimits.maxFileBytes
    public static let maxFiles = ShipLimits.maxFiles
    static let skippedDirectories: Set<String> = [
        ".git", "node_modules", "vendor", "dist", "build", "target", ".build", "out", ".next", ".nuxt",
        ".cache", "__pycache__", ".venv", "venv", ".gradle", "DerivedData", "Pods", "coverage", ".turbo", "tmp",
    ]
    static let secretPatterns = [
        ".env", ".env.*", "*.pem", "*.key", "*.p12", "*.pfx", "id_rsa*", "id_ed25519*", "*.keystore", "*.jks",
        "credentials*", "secrets.*", "*.sqlite", "*.db", ".npmrc", ".pypirc", ".netrc",
    ]

    /// `blobs` keeps an encrypted local copy of each file so a snapshot the
    /// server spot-checks at ship can still be disclosed exactly as it was.
    public static func capture(root: URL, salt: String = Data.random(32).hex, blobs: BlobStore? = nil) -> TreeSnapshot {
        // The enumerator yields symlink-resolved URLs (/var → /private/var),
        // so resolve the root too or relative paths come out wrong.
        let root = root.resolvingSymlinksInPath().standardizedFileURL
        let ignore = loadIgnore(root)
        var entries: [Entry] = []
        let fm = FileManager.default
        guard let walker = fm.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .isSymbolicLinkKey]) else {
            return TreeSnapshot(salt: salt, entries: [])
        }
        for case let url as URL in walker {
            let path = url.resolvingSymlinksInPath().standardizedFileURL.path
            guard path.hasPrefix(root.path + "/") else { continue }
            let relative = String(path.dropFirst(root.path.count + 1))
            let name = url.lastPathComponent
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .isSymbolicLinkKey])
            if values?.isDirectory == true {
                if skippedDirectories.contains(name) || matches(relative, ignore) { walker.skipDescendants() }
                continue
            }
            if values?.isSymbolicLink == true || isNeverHashed(name: name, relative: relative, ignore: ignore) { continue }
            if (values?.fileSize ?? 0) > maxFileBytes { continue }
            guard let content = try? Data(contentsOf: url, options: .mappedIfSafe) else { continue }
            let contentHash = EvidenceProtocol.sha256(content)
            blobs?.put(content, hash: contentHash.hex)
            entries.append(Entry(path: relative, leaf: EvidenceProtocol.merkleLeaf(salt: salt, path: relative, contentHash: contentHash),
                                 content: blobs == nil ? nil : contentHash.hex))
            if entries.count >= maxFiles { break }
        }
        entries.sort { Array($0.path.utf8).lexicographicallyPrecedes(Array($1.path.utf8)) }
        return TreeSnapshot(salt: salt, entries: entries)
    }

    public static func isNeverHashed(name: String, relative: String, ignore: [String] = []) -> Bool {
        secretPatterns.contains { fnmatch($0, name, 0) == 0 } || matches(relative, ignore)
    }

    static func loadIgnore(_ root: URL) -> [String] {
        guard let text = try? String(contentsOf: root.appendingPathComponent(".hackatimeignore"), encoding: .utf8) else { return [] }
        return text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
            .map { $0.hasSuffix("/") ? String($0.dropLast()) : $0 }
    }

    static func matches(_ relative: String, _ patterns: [String]) -> Bool {
        let components = relative.split(separator: "/").map(String.init)
        return patterns.contains { pattern in
            fnmatch(pattern, relative, 0) == 0 || components.contains { fnmatch(pattern, $0, 0) == 0 }
        }
    }
}
