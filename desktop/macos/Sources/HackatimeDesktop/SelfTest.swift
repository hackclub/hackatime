import AppKit
import DeviceCheck
import HackatimeDesktopCore

/// `--self-test`: checks the platform APIs the app needs on this Mac (device
/// key, App Attest, permissions, focus, one redacted capture) and prints what
/// works, for support and for checking a signed build. It runs locally and
/// sends nothing to Hackatime.
@MainActor
enum SelfTest {
    static func run() async -> Never {
        var report: [String: String] = [:]
        if let key = try? DeviceKey.loadOrCreate(store: MemoryStore()) {
            report["device_key"] = key.tier.rawValue
            let hash = EvidenceProtocol.sha256Hex(Data("self-test".utf8))
            report["signature"] = (try? key.signature(forHashHex: hash)) != nil ? "ok" : "failed"
        }
        if Attestation.appAttestAvailable {
            do {
                let keyID = try await DCAppAttestService.shared.generateKey()
                _ = try await DCAppAttestService.shared.attestKey(keyID, clientDataHash: Data(repeating: 1, count: 32))
                report["app_attest"] = "attested"
            } catch {
                report["app_attest"] = "supported, attestation refused (\((error as NSError).domain) \((error as NSError).code)); falls back to Secure Enclave tier"
            }
        } else {
            report["app_attest"] = "unavailable (needs macOS 27+, signed .app, entitlement)"
        }
        report["accessibility"] = FocusSensor.hasAccessibility ? "granted" : "not granted"
        report["input_monitoring"] = InputSensor.hasInputMonitoring ? "granted" : "not granted"
        report["screen_recording"] = WindowCapture.hasPermission ? "granted" : "not granted"
        report["hardware_id"] = Attestation.hardwareID == nil ? "missing" : "present"
        let sample = FocusSensor().sample()
        if let sample {
            let classifier = FocusClassifier(projectNames: ["sync-app"])
            report["focus"] = "\(sample.bundleID) → \(classifier.classify(sample).label.rawValue), capture \(classifier.isCaptureAllowed(sample) ? "allowed" : "blocked")"
        }
        if WindowCapture.hasPermission, let front = NSWorkspace.shared.frontmostApplication {
            do {
                if let image = try await WindowCapture.captureFocusedWindow(pid: front.processIdentifier) {
                    guard let (redacted, boxes) = WindowCapture.redact(image) else { report["capture"] = "dropped: no readable text regions"; throw CancellationError() }
                    report["capture"] = "\(redacted.width)x\(redacted.height), \(boxes) redactions, phash \(WindowCapture.perceptualHash(redacted))"
                    if let out = ProcessInfo.processInfo.environment["SELFTEST_FRAME"], let png = WindowCapture.encode(redacted) {
                        try png.write(to: URL(fileURLWithPath: out))
                        report["frame_bytes"] = "\(png.count)"
                        let vault = try Vault(directory: URL(fileURLWithPath: out + ".vault"), store: MemoryStore())
                        let stored = try vault.store(frame: png, capturedAtMs: Int64(Date().timeIntervalSince1970 * 1000))
                        report["vault"] = (try vault.preview(stored.hash)) == png ? "round-trip ok" : "mismatch"
                    }
                } else {
                    report["capture"] = "no window for \(front.bundleIdentifier ?? "?")"
                }
            } catch {
                report["capture"] = "error \(error.localizedDescription)"
            }
        }
        print("SELFTEST " + report.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: "; "))
        exit(0)
    }
}
