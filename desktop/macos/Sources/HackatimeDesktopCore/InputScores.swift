import Foundation

/// Per-minute input summary. No key codes are kept: only counts, timings
/// and where events came from. Only the summary scores leave the machine.
public struct InputMinute {
    public var keys = 0
    public var clicks = 0
    public var moves = 0
    /// Events posted by another process (CGEvent source PID ≠ 0) or with a
    /// synthetic source state: AutoHotkey-style tools, remote control,
    /// jigglers implemented in software.
    public var injected = 0
    var keyTimes: [Double] = []
    var movePoints: [(x: Double, y: Double, t: Double)] = []

    public init() {}

    public mutating func recordKey(at time: Double, injected isInjected: Bool) {
        keys += 1
        if isInjected { injected += 1 }
        if keyTimes.count < 2_000 { keyTimes.append(time) }
    }

    public mutating func recordClick(injected isInjected: Bool) {
        clicks += 1
        if isInjected { injected += 1 }
    }

    public mutating func recordMove(x: Double, y: Double, at time: Double, injected isInjected: Bool) {
        moves += 1
        if isInjected { injected += 1 }
        if movePoints.count < 4_000 { movePoints.append((x, y, time)) }
    }

    /// 0…1, higher is more human: humans type in bursts with irregular gaps
    /// (high coefficient of variation); scripts are metronomic.
    public var rhythm: Double? {
        guard keyTimes.count >= 8 else { return nil }
        let gaps = zip(keyTimes.dropFirst(), keyTimes).map { $0 - $1 }.filter { $0 > 0 && $0 < 5 }
        guard gaps.count >= 6 else { return nil }
        let mean = gaps.reduce(0, +) / Double(gaps.count)
        let variance = gaps.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(gaps.count)
        let cv = variance.squareRoot() / max(mean, 1e-6)
        return min(cv / 0.8, 1)
    }

    /// 0…1, higher looks more like a mouse jiggler: movement with no keys or
    /// clicks, tiny back-and-forth displacement, very regular timing or
    /// perfectly straight segments.
    public var jiggler: Double {
        guard movePoints.count >= 10 else { return 0 }
        if keys + clicks > 3 { return 0 }
        let xs = movePoints.map(\.x), ys = movePoints.map(\.y)
        let span = max((xs.max()! - xs.min()!), (ys.max()! - ys.min()!))
        let intervals = zip(movePoints.dropFirst(), movePoints).map { $0.t - $1.t }
        let mean = intervals.reduce(0, +) / Double(intervals.count)
        let sd = (intervals.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(intervals.count)).squareRoot()
        let regular = mean > 0 ? max(0, 1 - (sd / mean) / 0.5) : 0
        var turns = 0
        for i in 2 ..< movePoints.count {
            let a = (movePoints[i - 1].x - movePoints[i - 2].x, movePoints[i - 1].y - movePoints[i - 2].y)
            let b = (movePoints[i].x - movePoints[i - 1].x, movePoints[i].y - movePoints[i - 1].y)
            let cross = a.0 * b.1 - a.1 * b.0
            if abs(cross) < 1e-6, a.0 * b.0 + a.1 * b.1 < 0 { turns += 1 }
        }
        let reversals = Double(turns) / Double(movePoints.count - 2)
        let small = span < 40 ? 1.0 : 0.0
        return min(1, 0.4 * small + 0.3 * regular + 0.6 * min(reversals * 4, 1) + (keys + clicks == 0 ? 0.1 : 0))
    }
}
