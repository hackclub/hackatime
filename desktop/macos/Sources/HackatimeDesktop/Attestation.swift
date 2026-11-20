import CryptoKit
import DeviceCheck
import Foundation
import HackatimeDesktopCore
import IOKit

/// Optional hardware trust. App Attest is only attempted on macOS 27 or
/// later, from the main bundle of a full signed app carrying the App Attest
/// entitlement; everywhere else the device enrols a plain Secure Enclave (or
/// software) key. Neither is ever required.
enum Attestation {
    static var appAttestAvailable: Bool {
        guard ProcessInfo.processInfo.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 27, minorVersion: 0, patchVersion: 0)),
              Bundle.main.bundleURL.pathExtension == "app" else { return false }
        return DCAppAttestService.shared.isSupported
    }

    /// Returns the `app_attest` body for POST /key, or nil when unsupported
    /// or Apple's service refuses (the server then records the plain tier).
    static func attest(deviceUID: String, beacon: Beacon, publicKeyDER: Data) async -> [String: String]? {
        guard appAttestAvailable else { return nil }
        do {
            let service = DCAppAttestService.shared
            let keyID = try await service.generateKey()
            let clientData = "hkt-attest-v1|\(deviceUID)|\(beacon.value)|\(publicKeyDER.base64EncodedString())"
            let attestation = try await service.attestKey(keyID, clientDataHash: Data(SHA256.hash(data: Data(clientData.utf8))))
            return ["attestation": attestation.base64EncodedString(), "key_id": keyID, "beacon_minute": String(beacon.minute)]
        } catch {
            NSLog("App Attest unavailable: \(error.localizedDescription)")
            return nil
        }
    }

    /// The platform UUID, sent only so the server can keep one account per
    /// machine; it stores a keyed hash, never the value.
    static var hardwareID: String? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        defer { IOObjectRelease(service) }
        return IORegistryEntryCreateCFProperty(service, "IOPlatformUUID" as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? String
    }
}
