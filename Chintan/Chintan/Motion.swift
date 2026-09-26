import CoreMotion
import SwiftUI
import UIKit

// How he moves, told to the house (chunk N, slice 3): the phone's own motion
// history (still, walking, running, cycling, driving) folded on the phone into
// segments, each walk and run with its steps, distance and floors from the
// pedometer, posted to `POST /v1/motion` and forgotten. The phone keeps seven
// days of it, so no background is needed: on opening the app and on every wake
// the rest has earned (a move, Health, the app's own), what is new since the last segment the
// house had goes. The segment still going stays open and goes once it ends.
// Asked for on the Settings sheet, never at launch.
@MainActor
final class Motion: ObservableObject {
    static let shared = Motion()

    enum State { case unasked, allowed, refused }

    @Published private(set) var state: State = .unasked
    @Published private(set) var telling: Bool
    @Published private(set) var heard: Date?

    private let activity = CMMotionActivityManager()
    private let pedometer = CMPedometer()
    private let defaults = UserDefaults.standard
    private var draining = false
    private var lastDrained: Date?
    // The drain going, so a wake can wait for it rather than start a second.
    private var running: Task<Void, Never>?

    // The house's eyes in the simulator never tell the house anything.
    private let eyes = ProcessInfo.processInfo.arguments.contains("--house")

    private init() {
        telling = defaults.bool(forKey: "motion.telling")
        heard = defaults.object(forKey: "motion.heard") as? Date
        read()
    }

    // The first question the phone is asked shows its own permission sheet.
    func tell() {
        telling = true
        defaults.set(true, forKey: "motion.telling")
        Keychain.keepAfterFirstUnlock()
        lastDrained = nil
        Task { await drained() }
    }

    func stop() {
        telling = false
        defaults.set(false, forKey: "motion.telling")
    }

    // On opening the app and on each wake: what is new, if not lately.
    func freshen() {
        read()
        guard telling, !eyes else { return }
        if let lastDrained, Date().timeIntervalSince(lastDrained) < 15 * 60 { return }
        Task { await drained() }
    }

    // What is new, now; returns once the house has had its chance.
    func drained() async {
        if let running { return await running.value }
        let task = Task { await drain() }
        running = task
        await task.value
        running = nil
    }

    // What he is doing now, for the phone's word: the last thing the phone
    // saw in the last ten minutes, or nothing when motion is not told.
    func now() async -> String? {
        guard telling, !eyes, state == .allowed else { return nil }
        let end = Date()
        let seen = await activities(from: end.addingTimeInterval(-600), to: end)
        return seen?.last.map(Self.kind)
    }

    private func read() {
        switch CMMotionActivityManager.authorizationStatus() {
        case .authorized: state = .allowed
        case .denied, .restricted: state = .refused
        default: state = .unasked
        }
    }

    // From the start of the segment the house has not had whole, at most the
    // seven days the phone keeps, to now: the segments that have ended, 2,000
    // a post; the place moves only once the house has them.
    private func drain() async {
        guard !draining, telling, !eyes, CMMotionActivityManager.isActivityAvailable(),
              let address = Keychain.loadHouseAddress(), !address.isEmpty else { return }
        draining = true
        defer { draining = false }
        let task = UIApplication.shared.beginBackgroundTask(withName: "motion")
        defer { UIApplication.shared.endBackgroundTask(task) }
        let now = Date()
        let week = now.addingTimeInterval(-7 * 86400 + 60)
        let through = max(defaults.object(forKey: "motion.through") as? Date ?? week, week)
        let seen = await activities(from: through.addingTimeInterval(-1), to: now)
        read()
        guard var seen else { return }
        lastDrained = Date()
        seen.removeAll { $0.startDate < through }
        var segments = Self.fold(seen)
        guard let open = segments.popLast() else { return }
        for i in segments.indices where segments[i].activity == "walking" || segments[i].activity == "running" {
            await walked(&segments[i])
        }
        let client = HouseClient(baseAddress: address)
        for first in stride(from: 0, to: segments.count, by: 2000) {
            let batch = Array(segments[first..<min(first + 2000, segments.count)])
            guard let body = try? JSONEncoder().encode(Batch(segments: batch)) else { continue }
            switch await client.motion(body) {
            case .heard:
                heard = Date()
                defaults.set(heard, forKey: "motion.heard")
            case .refused:
                break
            case .unheard:
                return
            }
            // The next begins where the last sent ended; the open one after all.
            let next = batch.count == segments.count - first ? open.from : segments[first + batch.count].from
            defaults.set(next, forKey: "motion.through")
        }
        if segments.isEmpty { defaults.set(open.from, forKey: "motion.through") }
    }

    // Each change the phone saw starts a segment unless it says the same, or
    // says it with low confidence, or says nothing it knows; then it only
    // carries the one before on. The last segment is still going.
    private static func fold(_ seen: [CMMotionActivity]) -> [Segment] {
        var segments: [Segment] = []
        for (i, one) in seen.enumerated() {
            let end = i + 1 < seen.count ? seen[i + 1].startDate : Date()
            let what = kind(one)
            if var last = segments.last,
               what == last.activity || one.confidence == .low || what == "unknown" {
                last.to = end
                if what == last.activity { last.sure = max(last.sure, one.confidence.rawValue) }
                segments[segments.count - 1] = last
            } else {
                segments.append(Segment(from: one.startDate, to: end, activity: what, sure: one.confidence.rawValue))
            }
        }
        return segments
    }

    private static func kind(_ one: CMMotionActivity) -> String {
        if one.automotive { return "automotive" }
        if one.cycling { return "cycling" }
        if one.running { return "running" }
        if one.walking { return "walking" }
        if one.stationary { return "stationary" }
        return "unknown"
    }

    private func activities(from: Date, to: Date) async -> [CMMotionActivity]? {
        await withCheckedContinuation { done in
            activity.queryActivityStarting(from: from, to: to, to: .main) { seen, error in
                done.resume(returning: error == nil ? seen ?? [] : nil)
            }
        }
    }

    // A walk's or a run's steps, distance and floors, as the pedometer counted them.
    private func walked(_ segment: inout Segment) async {
        guard CMPedometer.isStepCountingAvailable() else { return }
        let (from, to) = (segment.from, segment.to)
        let data: CMPedometerData? = await withCheckedContinuation { done in
            pedometer.queryPedometerData(from: from, to: to) { data, _ in done.resume(returning: data) }
        }
        guard let data else { return }
        segment.steps = data.numberOfSteps.intValue
        segment.distance = data.distance.map { ($0.doubleValue * 10).rounded() / 10 }
        segment.floors = data.floorsAscended?.intValue
    }
}

// One segment of the house's contract: {"start", "end", "activity",
// "confidence", "steps", "distance", "floors"}, the last three for a walk or a run.
private struct Segment: Encodable {
    var from: Date
    var to: Date
    let activity: String
    var sure: Int
    var steps: Int?
    var distance: Double?
    var floors: Int?

    private static let iso = ISO8601DateFormatter()

    enum Keys: String, CodingKey { case start, end, activity, confidence, steps, distance, floors }

    func encode(to encoder: Encoder) throws {
        var row = encoder.container(keyedBy: Keys.self)
        try row.encode(Self.iso.string(from: from), forKey: .start)
        try row.encode(Self.iso.string(from: to), forKey: .end)
        try row.encode(activity, forKey: .activity)
        try row.encode(sure >= 2 ? "high" : sure == 1 ? "medium" : "low", forKey: .confidence)
        try row.encodeIfPresent(steps, forKey: .steps)
        try row.encodeIfPresent(distance, forKey: .distance)
        try row.encodeIfPresent(floors, forKey: .floors)
    }
}

private struct Batch: Encodable { let segments: [Segment] }

// The Settings sheet's section: when the house last heard how he moves, what
// the phone tells, and one thing to press for the state it is in.
struct MotionSection: View {
    @ObservedObject private var motion = Motion.shared

    var body: some View {
        SettingsRoom("How you move", note: note) {
            if motion.telling, motion.state != .refused, let heard = motion.heard {
                HeardLine(words: "Heard", hour: WhereaboutsSection.time(heard))
            } else if motion.telling {
                Text(motion.state == .refused
                     ? "Motion is off for chintan in the phone's Settings."
                     : "The house has not heard how you move yet.")
                    .font(.system(.body, design: .serif).italic())
                    .foregroundStyle(Theme.ink.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
            SettingsActions {
                if !motion.telling {
                    SettingsAction("Tell the house", run: motion.tell)
                } else {
                    if motion.state == .refused {
                        SettingsAction("Open the phone's Settings", run: Whereabouts.shared.openSettings)
                    }
                    SettingsAction("Stop telling", quiet: true, run: motion.stop)
                }
            }
        }
    }

    private var note: String {
        motion.telling
            ? "Only the house hears it; the phone keeps only where it left off."
            : "Each time chintan opens, and now and then while it rests, the phone tells the house when you were still, walking, running, cycling or driving since it last did, and the steps of each walk, from the seven days the phone keeps. Only the house hears it; the phone keeps only where it left off."
    }
}
