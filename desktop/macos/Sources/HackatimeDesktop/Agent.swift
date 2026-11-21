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
    /// Minutes tracked on each local day, kept across launches.
    @Published private(set) var trackedByDay: [String: Int] = [:]
    @Published private(set) var lastFrameAt: Date?
    @Published var settings: Settings { didSet { saveSettings() } }

    let support: URL
    let store: SecretStore
    let api: APIClient
    let vault: Vault
    let chain: ChainState
    let aiInbox: AIInbox
    private let focus = FocusSensor()
    private let input = InputSensor()
    private var inputRunning = false
    private var key: DeviceKey?
    private var lastBeacon: Beacon?
    private var focusSamples: [(FocusLabel, String?, pid_t)] = []
    private var fileEdits = 0, commits = 0, builds = 0
    private var lastActivity: [String: Date] = [:]   // project folder → last file change seen
    private var fsStream: FSEventStreamRef?
    private var snapshots: [Int: TreeSnapshot] = [:]   // seq → snapshot, kept locally for shipping
    private var lastSnapshotMinute = 0
    private var framesThisMinute: [MinutePayload.Frame] = []
    private var lastFrame: MinutePayload.Frame?
    private var lastThumbnail: [UInt8] = []
    private var timers: [Timer] = []
    private var pendingVerifier: String?
    private var ticking = false

    nonisolated static let defaultSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Hackatime Desktop", isDirectory: true)

    init(support: URL = Agent.defaultSupport, store: SecretStore = KeychainStore(), session: URLSession = .shared) {
        self.support = support
        self.store = store
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        let loaded = (try? Data(contentsOf: support.appendingPathComponent("settings.json")))
            .flatMap { try? JSONDecoder().decode(Settings.self, from: $0) } ?? Settings()
        settings = loaded
        api = APIClient(baseURL: URL(string: loaded.baseURL)!, token: store.read("device-token").map { String(decoding: $0, as: UTF8.self) },
                        session: session)
        vault = try! Vault(directory: support.appendingPathComponent("vault"), store: store)
        chain = (try? Data(contentsOf: support.appendingPathComponent("chain.json")))
            .flatMap { try? JSONDecoder().decode(ChainState.self, from: $0) } ?? ChainState()
        aiInbox = AIInbox(url: support.appendingPathComponent("ai-events.jsonl"))
        snapshots = (try? Data(contentsOf: support.appendingPathComponent("snapshots.json")))
            .flatMap { try? JSONDecoder().decode([Int: TreeSnapshot].self, from: $0) } ?? [:]
        trackedByDay = (try? Data(contentsOf: support.appendingPathComponent("tracked.json")))
            .flatMap { try? JSONDecoder().decode([String: Int].self, from: $0) } ?? [:]
    }

    static func dayKey(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    var todayMinutes: Int { trackedByDay[Self.dayKey(Date())] ?? 0 }

    func countTrackedMinute(at date: Date) {
        let day = Self.dayKey(date)
        // Keep a week; the menu only shows today.
        trackedByDay = trackedByDay.filter { $0.key >= Self.dayKey(date.addingTimeInterval(-7 * 86_400)) }
        trackedByDay[day, default: 0] += 1
        try? JSONEncoder().encode(trackedByDay).write(to: support.appendingPathComponent("tracked.json"), options: .atomic)
    }

    var isPaired: Bool { api.token != nil }
    var classifier: FocusClassifier { FocusClassifier(projectNames: settings.projects.map { URL(fileURLWithPath: $0).lastPathComponent }) }

    /// The project whose files changed most recently, in the last 10 minutes,
    /// or the only project. Names the project when window titles are unknown.
    var activeProject: String? {
        let recent = lastActivity.filter { Date().timeIntervalSince($0.value) < 600 }.max { $0.value < $1.value }?.key
        return (recent ?? (settings.projects.count == 1 ? settings.projects[0] : nil)).map { URL(fileURLWithPath: $0).lastPathComponent }
    }

    func loadKey() { key = try? DeviceKey.loadOrCreate(store: store) }

    func start() {
        loadKey()
        inputRunning = input.start()
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

    /// The site's pairing page for a fresh PKCE challenge. The app's window
    /// loads it, so the code comes straight back to this process.
    func beginPairing() -> URL {
        let pkce = EvidenceProtocol.pkcePair()
        pendingVerifier = pkce.verifier
        return api.pairingURL(site: settings.site, challenge: pkce.challenge, deviceName: Host.current().localizedName ?? "Mac")
    }

    /// Returns why pairing failed, or nil once this Mac is paired.
    @discardableResult
    func completePairing(code: String) async -> String? {
        guard let verifier = pendingVerifier else {
            status = "Start pairing from the app first"
            return "This code was issued for another pairing. Start again from the app."
        }
        do {
            let (token, device) = try await api.pair(code: code, verifier: verifier, name: Host.current().localizedName ?? "Mac", appVersion: APIClient.version)
            store.write("device-token", Data(token.utf8))
            api.token = token
            settings.deviceUID = device["uid"] as? String
            settings.keyEnrolled = false
            startNewChain()
            pendingVerifier = nil
            await enrolKey()
            status = "Tracking"
            return nil
        } catch {
            status = "Pairing failed: \(error)"
            if let failure = error as? APIClient.Failure,
               let body = try? JSONSerialization.jsonObject(with: Data(failure.body.utf8)) as? [String: Any],
               let message = body["error"] as? String { return message }
            return error.localizedDescription
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

    /// A new pairing starts the server's chain again at seq 0, so snapshots
    /// kept by the old chain's seq would be matched to the wrong minutes.
    func startNewChain() {
        chain.resync(seq: 0, head: EvidenceProtocol.zeroHash)
        persistChain()
        snapshots = [:]
        lastSnapshotMinute = 0
        persistSnapshots()
    }

    /// Returns why unpairing failed, or nil once this Mac is unpaired. The
    /// token is kept when the server could not be told, so the device is
    /// not left active on the site with no way to remove it from here.
    func unpair() async -> String? {
        do {
            try await api.unpair()
        } catch let failure as APIClient.Failure where failure.status == 401 || failure.status == 404 {
            // Already gone on the server.
        } catch {
            return "\(error)"
        }
        forgetPairing()
        status = "Not signed in"
        return nil
    }

    /// Called when the pairing ends without the app asking, such as when the
    /// device is removed on the site; the app uses it to refresh its window.
    var onUnpaired: () -> Void = {}

    private func forgetPairing() {
        store.delete("device-token")
        api.token = nil
        settings.keyEnrolled = false
    }

    /// The server no longer knows this token: the device was unpaired on the
    /// site. Stop recording and say so, rather than queueing for ever.
    private func pairingRevoked() {
        forgetPairing()
        focusSamples.removeAll(); framesThisMinute.removeAll()
        status = "Unpaired on the site"
        NativeToastCenter.shared.show("This Mac was unpaired", detail: "Tracking has stopped. Pair again to carry on.",
                                      style: .error, id: "unpaired")
        onUnpaired()
    }

    // MARK: Sampling

    private func sampleFocus() {
        guard !settings.paused, let sample = focus.sample() else { return }
        let (label, project) = classifier.classify(sample, activeProject: activeProject)
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
        guard isPaired, !settings.paused, WindowCapture.hasPermission, let sample = focus.sample(),
              classifier.classify(sample).label != .unrelated, classifier.isCaptureAllowed(sample, activeProject: activeProject),
              let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              let image = try? await WindowCapture.captureFocusedWindow(pid: pid),
              let (redacted, _) = WindowCapture.redact(image) else { return }
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let thumbnail = WindowCapture.thumbnail(redacted)
        // An unchanged screen reuses the last frame instead of storing a copy.
        if let last = lastFrame, !WindowCapture.screenChanged(from: lastThumbnail, to: thumbnail) {
            framesThisMinute.append(.init(hash: last.hash, atMs: now, phash: last.phash))
            return
        }
        guard let data = WindowCapture.encode(redacted),
              let stored = try? vault.store(frame: data, capturedAtMs: now) else { return }
        let frame = MinutePayload.Frame(hash: stored.hash, atMs: now, phash: WindowCapture.perceptualHash(thumbnail))
        framesThisMinute.append(frame)
        lastFrame = frame
        lastThumbnail = thumbnail
        lastFrameAt = Date()
    }

    // MARK: Minute tick

    func tick() async {
        // A slow server can hold a tick past the next minute; let it finish
        // rather than build a second block from the same samples.
        guard !ticking else { return }
        ticking = true
        defer { ticking = false }
        guard isPaired, !settings.paused else {
            _ = input.takeMinute(); focusSamples.removeAll(); return
        }
        let fresh: Beacon?
        do {
            fresh = try await api.beacon()
        } catch let failure as APIClient.Failure where failure.status == 401 {
            pairingRevoked(); return
        } catch {
            fresh = nil
        }
        guard let beacon = fresh ?? lastBeacon else { status = "Offline, waiting for the server"; return }
        if beacon != lastBeacon { lastBeacon = beacon }
        if !settings.keyEnrolled { await enrolKey() }

        scheduleTimelapse(beacon)

        // Counts are known only if the tap ran all minute with the permission
        // still granted; otherwise they are left out, never sent as zero.
        let inputKnown = inputRunning && InputSensor.hasInputMonitoring
        let inputs = input.takeMinute()
        inputRunning = input.start()
        var payload = MinutePayload()
        let labels = focusSamples.map(\.0)
        let winner = [FocusLabel.project, .research, .unrelated, .unknown].max { a, b in
            labels.filter { $0 == a }.count < labels.filter { $0 == b }.count
        } ?? .unknown
        payload.focus = labels.isEmpty ? .unknown : winner
        payload.project = focusSamples.compactMap(\.1).last
        payload.activeS = InputSensor.idleSeconds < 60 ? min(60, labels.filter { $0 == .project || $0 == .research }.count * 5) : 0
        if inputKnown {
            payload.keys = inputs.keys
            payload.clicks = inputs.clicks
            payload.moves = inputs.moves
            payload.injected = inputs.injected
            payload.rhythm = inputs.rhythm.map { ($0 * 1000).rounded() / 1000 }
            payload.jiggler = (inputs.jiggler * 1000).rounded() / 1000
        }
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
            let now = Date()
            if let block = try chain.append(payload: payload, beacon: beacon, now: now,
                                            monoMs: Int64(ProcessInfo.processInfo.systemUptime * 1000), key: key) {
                if let snapshot { snapshots[block.seq] = snapshot; persistSnapshots() }
                if payload.focus == .project || payload.focus == .research, payload.activeS > 0 { countTrackedMinute(at: now) }
            }
            try await flush()
            status = "Tracking"
        } catch let rejection as ChainRejection {
            status = "Server refused \(rejection.dropped) minute\(rejection.dropped == 1 ? "" : "s"): \(rejection.message)"
            NativeToastCenter.shared.show("The server refused \(rejection.dropped) minute\(rejection.dropped == 1 ? "" : "s")",
                                          detail: rejection.message, style: .error, id: "chain")
        } catch let failure as APIClient.Failure where failure.status == 401 {
            pairingRevoked()
        } catch {
            status = "Queued \(chain.pending.count) minutes (offline)"
        }
        persistChain()
    }

    /// The server refused a block, so the queue from it on was dropped and
    /// the chain restarted from the server's head.
    struct ChainRejection: Error {
        let code: String
        let message: String
        let dropped: Int
    }

    private func flush() async throws {
        while !chain.pending.isEmpty {
            let batch = Array(chain.pending.prefix(120))
            let response = try await api.send(blocks: batch)
            recordAccepted(batch, headSeq: response.headSeq)
            chain.acknowledge(headSeq: response.headSeq)
            if let error = response.error {
                NSLog("Chain rejected: \(error.code) \(error.message)")
                let dropped = chain.pending.count
                chain.resync(seq: response.headSeq, head: response.headHash)
                throw ChainRejection(code: error.code, message: error.message, dropped: dropped)
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
            if let project = settings.projects.first(where: { path.hasPrefix($0 + "/") }) { lastActivity[project] = Date() }
            if path.hasSuffix(".git/logs/HEAD") { commits += 1; continue }
            let components = path.split(separator: "/")
            if components.contains(where: { TreeSnapshot.buildDirectories.contains(String($0)) }) {
                builds = 1
                continue
            }
            if components.contains(where: { TreeSnapshot.skippedDirectories.contains(String($0)) }) { continue }
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

    // MARK: Ship ledger

    /// Accepted minutes by seq, so a ship picks a project's real range.
    private(set) lazy var ledger: ShipLedger = (try? Data(contentsOf: support.appendingPathComponent("ledger.json")))
        .flatMap { try? JSONDecoder().decode(ShipLedger.self, from: $0) } ?? ShipLedger()

    func recordAccepted(_ blocks: [Block], headSeq: Int) {
        ledger.record(blocks.filter { $0.seq <= headSeq })
        persistLedger()
    }

    func markShipped(through seq: Int) {
        ledger.markShipped(through: seq)
        persistLedger()
    }

    private func persistLedger() {
        try? JSONEncoder().encode(ledger).write(to: support.appendingPathComponent("ledger.json"), options: .atomic)
    }

    /// "Delete all local evidence": everything the vault does not hold.
    /// Snapshot leaf lists name every file, and the AI inbox keeps working
    /// directories, so both go too.
    func forgetLocalEvidence() {
        snapshots = [:]
        try? FileManager.default.removeItem(at: support.appendingPathComponent("snapshots.json"))
        framesThisMinute = []
        lastFrame = nil
        try? FileHandle(forWritingTo: aiInbox.url).truncate(atOffset: 0)
    }
}
