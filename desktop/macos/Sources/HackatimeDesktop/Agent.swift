import AppKit
import CoreServices
import Foundation
import HackatimeDesktopCore

/// Settings persisted in Application Support (not secrets).
struct Settings: Codable {
    var baseURL = "https://hackatime.hackclub.com"
    var projects: [String] = []            // absolute project directories
    var siteURL: String?                   // companion site; defaults to Settings.defaultSite
    var paused = false
    var deviceUID: String?
    var keyEnrolled = false

    static let defaultSite = "https://desktop.hackatime.hackclub.com"
    var site: URL { URL(string: siteURL ?? Settings.defaultSite)! }
}

/// The once-a-minute loop: sample focus, count input and file activity,
/// drain AI events, snapshot trees, schedule the server-paced timelapse frame,
/// then append a signed block to the chain and flush the queue.
@MainActor
final class Agent: ObservableObject {
    @Published private(set) var status = "Not signed in"
    @Published private(set) var todayMinutes = 0
    @Published private(set) var lastFrameAt: Date?
    @Published var settings: Settings { didSet { saveSettings() } }

    let support: URL
    let store = KeychainStore()
    let api: APIClient
    let vault: Vault
    let chain: ChainState
    let aiInbox: AIInbox
    private let focus = FocusSensor()
    private let input = InputSensor()
    private var key: DeviceKey?
    private var lastBeacon: Beacon?
    private var focusSamples: [(FocusLabel, String?, pid_t)] = []
    private var fileEdits = 0, commits = 0, builds = 0
    private var fsStream: FSEventStreamRef?
    private var snapshots: [Int: TreeSnapshot] = [:]   // seq → snapshot, kept locally for shipping
    private var lastSnapshotMinute = 0
    private var framesThisMinute: [MinutePayload.Frame] = []
    private var lastFrame: MinutePayload.Frame?
    private var timers: [Timer] = []
    private var pendingVerifier: String?

    init() {
        support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Hackatime Desktop", isDirectory: true)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        let loaded = (try? Data(contentsOf: support.appendingPathComponent("settings.json")))
            .flatMap { try? JSONDecoder().decode(Settings.self, from: $0) } ?? Settings()
        settings = loaded
        api = APIClient(baseURL: URL(string: loaded.baseURL)!, token: store.read("device-token").map { String(decoding: $0, as: UTF8.self) })
        vault = try! Vault(directory: support.appendingPathComponent("vault"), store: store)
        chain = (try? Data(contentsOf: support.appendingPathComponent("chain.json")))
            .flatMap { try? JSONDecoder().decode(ChainState.self, from: $0) } ?? ChainState()
        aiInbox = AIInbox(url: support.appendingPathComponent("ai-events.jsonl"))
        snapshots = (try? Data(contentsOf: support.appendingPathComponent("snapshots.json")))
            .flatMap { try? JSONDecoder().decode([Int: TreeSnapshot].self, from: $0) } ?? [:]
    }

    var isPaired: Bool { api.token != nil }
    var classifier: FocusClassifier { FocusClassifier(projectNames: settings.projects.map { URL(fileURLWithPath: $0).lastPathComponent }) }

    func start() {
        key = try? DeviceKey.loadOrCreate(store: store)
        input.start()
        watchProjects()
        timers.append(Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in Task { @MainActor in self?.sampleFocus() } })
        // Fire just after each minute boundary.
        let delay = 60 - Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 60) + 1
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            Task { await self.tick() }
            self.timers.append(Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in Task { await self?.tick() } })
        }
        vault.shredExpired()
        status = isPaired ? "Tracking" : "Not signed in"
    }

    // MARK: Pairing

    func beginPairing() {
        let pkce = EvidenceProtocol.pkcePair()
        pendingVerifier = pkce.verifier
        NSWorkspace.shared.open(api.pairingURL(site: settings.site, challenge: pkce.challenge, deviceName: Host.current().localizedName ?? "Mac"))
    }

    func completePairing(code: String) async {
        guard let verifier = pendingVerifier else { status = "Start pairing from the menu first"; return }
        do {
            let (token, device) = try await api.pair(code: code, verifier: verifier, name: Host.current().localizedName ?? "Mac", appVersion: APIClient.version)
            store.write("device-token", Data(token.utf8))
            api.token = token
            settings.deviceUID = device["uid"] as? String
            chain.resync(seq: 0, head: EvidenceProtocol.zeroHash)
            pendingVerifier = nil
            await enrolKey()
            status = "Tracking"
        } catch {
            status = "Pairing failed: \(error)"
        }
    }

    private func enrolKey() async {
        guard let key, !settings.keyEnrolled, let uid = settings.deviceUID else { return }
        do {
            let beacon = try await api.beacon()
            let attest = await Attestation.attest(deviceUID: uid, beacon: beacon, publicKeyDER: key.publicKeyDER)
            _ = try await api.enrolKey(key, hardwareID: Attestation.hardwareID, appAttest: attest)
            settings.keyEnrolled = true
        } catch {
            NSLog("Key enrolment skipped: \(error)")
        }
    }

    func unpair() async {
        try? await api.unpair()
        store.delete("device-token")
        api.token = nil
        settings.keyEnrolled = false
        status = "Not signed in"
    }

    // MARK: Sampling

    private func sampleFocus() {
        guard !settings.paused, let sample = focus.sample() else { return }
        let (label, project) = classifier.classify(sample)
        let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0
        focusSamples.append((label, project, pid))
    }

    /// The timelapse: one frame a minute, at the second the server's beacon
    /// picked, of the focused window if it is on the allowlist.
    private func scheduleTimelapse(_ beacon: Beacon) {
        guard let due = beacon.nextExpectedAt.flatMap({ ISO8601DateFormatter().date(from: $0) }) else { return }
        let delay = max(0, due.timeIntervalSinceNow)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            Task { @MainActor in await self?.captureTimelapseFrame() }
        }
    }

    private func captureTimelapseFrame() async {
        guard !settings.paused, WindowCapture.hasPermission, let sample = focus.sample(),
              classifier.classify(sample).label != .unrelated, classifier.isCaptureAllowed(sample),
              let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              let image = try? await WindowCapture.captureFocusedWindow(pid: pid),
              let (redacted, _) = WindowCapture.redact(image) else { return }
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let phash = WindowCapture.perceptualHash(redacted)
        // An unchanged screen reuses the last frame instead of storing a copy.
        if let last = lastFrame, last.phash == phash {
            framesThisMinute.append(.init(hash: last.hash, atMs: now, phash: phash))
            return
        }
        guard let data = WindowCapture.encode(redacted),
              let stored = try? vault.store(frame: data, capturedAtMs: now) else { return }
        let frame = MinutePayload.Frame(hash: stored.hash, atMs: now, phash: phash)
        framesThisMinute.append(frame)
        lastFrame = frame
        lastFrameAt = Date()
    }

    // MARK: Minute tick

    func tick() async {
        guard isPaired, !settings.paused else {
            _ = input.takeMinute(); focusSamples.removeAll(); return
        }
        let beacon: Beacon? = (try? await api.beacon()) ?? lastBeacon
        guard let beacon else { status = "Offline, waiting for the server"; return }
        if beacon != lastBeacon { lastBeacon = beacon }

        scheduleTimelapse(beacon)

        let inputs = input.takeMinute()
        var payload = MinutePayload()
        let labels = focusSamples.map(\.0)
        let winner = [FocusLabel.project, .research, .unrelated, .unknown].max { a, b in
            labels.filter { $0 == a }.count < labels.filter { $0 == b }.count
        } ?? .unknown
        payload.focus = labels.isEmpty ? .unknown : winner
        payload.project = focusSamples.compactMap(\.1).last
        payload.activeS = InputSensor.idleSeconds < 60 ? min(60, labels.filter { $0 == .project || $0 == .research }.count * 5) : 0
        payload.keys = inputs.keys
        payload.clicks = inputs.clicks
        payload.moves = inputs.moves
        payload.injected = inputs.injected
        payload.rhythm = inputs.rhythm.map { ($0 * 1000).rounded() / 1000 }
        payload.jiggler = (inputs.jiggler * 1000).rounded() / 1000
        payload.edits = fileEdits
        payload.commits = commits
        payload.builds = builds
        payload.ai = aiInbox.drain(now: Date().timeIntervalSince1970)
        if let ai = payload.ai, ai.prompts > 0 || ai.accepted > 0 { payload.category = "ai coding" }
        if !framesThisMinute.isEmpty { payload.frames = framesThisMinute }

        let minute = Int(Date().timeIntervalSince1970 / 60)
        var snapshot: TreeSnapshot?
        if minute - lastSnapshotMinute >= 5, payload.focus == .project, let root = projectRoot(named: payload.project) {
            snapshot = TreeSnapshot.capture(root: root, blobs: vault)
            payload.tree = .init(root: snapshot!.root)
            lastSnapshotMinute = minute
        }
        fileEdits = 0; commits = 0; builds = 0
        focusSamples.removeAll(); framesThisMinute.removeAll()

        do {
            if let block = try chain.append(payload: payload, beacon: beacon, now: Date(),
                                            monoMs: Int64(ProcessInfo.processInfo.systemUptime * 1000), key: key) {
                if let snapshot { snapshots[block.seq] = snapshot; persistSnapshots() }
                if payload.focus == .project || payload.focus == .research, payload.activeS > 0 { todayMinutes += 1 }
            }
            try await flush()
            status = "Tracking"
        } catch {
            status = "Queued \(chain.pending.count) minutes (offline)"
        }
        persistChain()
    }

    private func flush() async throws {
        while !chain.pending.isEmpty {
            let batch = Array(chain.pending.prefix(120))
            let response = try await api.send(blocks: batch)
            chain.acknowledge(headSeq: response.headSeq)
            if let error = response.error {
                NSLog("Chain rejected: \(error.code) \(error.message)")
                chain.resync(seq: response.headSeq, head: response.headHash)
                break
            }
        }
    }

    func projectRoot(named name: String?) -> URL? {
        guard let name else { return nil }
        return settings.projects.map { URL(fileURLWithPath: $0) }.first { $0.lastPathComponent.lowercased() == name.lowercased() }
    }

    // MARK: File activity (FSEvents; counts only)

    func watchProjects() {
        if let fsStream { FSEventStreamStop(fsStream); FSEventStreamInvalidate(fsStream); FSEventStreamRelease(fsStream) }
        guard !settings.projects.isEmpty else { return }
        var context = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil)
        let callback: FSEventStreamCallback = { _, info, count, paths, _, _ in
            guard let info else { return }
            let agent = Unmanaged<Agent>.fromOpaque(info).takeUnretainedValue()
            let list = Unmanaged<CFArray>.fromOpaque(paths).takeUnretainedValue() as? [String] ?? []
            Task { @MainActor in agent.recordFileEvents(Array(list.prefix(count))) }
        }
        fsStream = FSEventStreamCreate(nil, callback, &context, settings.projects as CFArray, FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 2,
                                       UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes))
        if let fsStream {
            FSEventStreamSetDispatchQueue(fsStream, .main)
            FSEventStreamStart(fsStream)
        }
    }

    func recordFileEvents(_ paths: [String]) {
        for path in paths {
            if path.hasSuffix(".git/logs/HEAD") { commits += 1; continue }
            let components = path.split(separator: "/")
            if components.contains(where: { ["build", "dist", ".build", "target", "out", ".next"].contains(String($0)) }) {
                builds = 1
                continue
            }
            if components.contains(where: { $0 == ".git" || $0 == "node_modules" }) { continue }
            if TreeSnapshot.isNeverHashed(name: String(components.last ?? ""), relative: path) { continue }
            fileEdits += 1
        }
    }

    // MARK: Persistence

    func addProject(_ url: URL) {
        guard !settings.projects.contains(url.path) else { return }
        settings.projects.append(url.path)
        watchProjects()
    }

    private func saveSettings() {
        try? JSONEncoder().encode(settings).write(to: support.appendingPathComponent("settings.json"), options: .atomic)
    }

    private func persistChain() {
        try? JSONEncoder().encode(chain).write(to: support.appendingPathComponent("chain.json"), options: .atomic)
    }

    private func persistSnapshots() {
        // Keep 3 days of snapshots; older ones can no longer be shipped usefully.
        let cutoff = chain.seq - 3 * 24 * 60
        snapshots = snapshots.filter { $0.key > cutoff }
        try? JSONEncoder().encode(snapshots).write(to: support.appendingPathComponent("snapshots.json"), options: .atomic)
    }

    func snapshot(at seq: Int) -> TreeSnapshot? { snapshots[seq] }
}
