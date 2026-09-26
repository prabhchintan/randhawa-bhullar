import HealthKit
import SwiftUI
import UIKit

// Health, told to the house (chunk N, slice 2): what the phone's Health holds,
// folded on the phone and posted to `POST /v1/health` in batches of at most
// 2,000, then forgotten. Counted things go as Health's own totals by the hour,
// the heart rate as five minute mean, low and high (the house keeps the last
// row for a type and its start, so the last few hours are sent again as they
// fill in); everything else goes sample by sample from an anchor, so nothing
// travels twice. Asked for on the Settings sheet, never at launch. Health
// wakes the app when new samples land (hourly for most); a wake with the
// phone locked finds Health closed and waits for the next. A batch the house
// did not hear keeps its place for the next; a batch it refused (4xx) is let go.
@MainActor
final class Health: ObservableObject {
    static let shared = Health()

    @Published private(set) var telling: Bool
    @Published private(set) var heard: Date?
    // Health says it has types the house reads that it has not asked about.
    @Published private(set) var unasked = false

    private let store = HKHealthStore()
    private let defaults = UserDefaults.standard
    private var watching: [HKObserverQuery] = []
    private var draining = false
    private var again = false
    private var waiting: [() -> Void] = []
    private var lastDrained: Date?

    // The house's eyes in the simulator never tell the house anything.
    private let eyes = ProcessInfo.processInfo.arguments.contains("--house")

    private static let bpm = HKUnit.count().unitDivided(by: .minute())
    private static let pace = HKUnit.meter().unitDivided(by: .second())

    // Counted things, as Health's totals by the hour (a watch and a phone
    // counting the same steps are counted once).
    private static let totals: [(HKQuantityTypeIdentifier, HKUnit)] = [
        (.stepCount, .count()),
        (.distanceWalkingRunning, .meter()),
        (.distanceCycling, .meter()),
        (.flightsClimbed, .count()),
        (.activeEnergyBurned, .kilocalorie()),
        (.basalEnergyBurned, .kilocalorie()),
        (.appleExerciseTime, .minute()),
        (.appleStandTime, .minute()),
        (.timeInDaylight, .minute()),
    ]

    // Readings, one by one as Health has them.
    private static let readings: [(HKQuantityTypeIdentifier, HKUnit)] = [
        (.restingHeartRate, bpm),
        (.walkingHeartRateAverage, bpm),
        (.heartRateVariabilitySDNN, .secondUnit(with: .milli)),
        (.heartRateRecoveryOneMinute, bpm),
        (.vo2Max, HKUnit(from: "ml/kg*min")),
        (.respiratoryRate, bpm),
        (.oxygenSaturation, .percent()),
        (.appleSleepingWristTemperature, .degreeCelsius()),
        (.bodyMass, .gramUnit(with: .kilo)),
        (.bodyFatPercentage, .percent()),
        (.environmentalAudioExposure, .decibelAWeightedSoundPressureLevel()),
        (.headphoneAudioExposure, .decibelAWeightedSoundPressureLevel()),
        (.appleWalkingSteadiness, .percent()),
        (.walkingSpeed, pace),
        (.walkingStepLength, .meter()),
        (.walkingAsymmetryPercentage, .percent()),
        (.walkingDoubleSupportPercentage, .percent()),
        (.stairAscentSpeed, pace),
        (.stairDescentSpeed, pace),
        (.sixMinuteWalkTestDistance, .meter()),
        (.bloodGlucose, HKUnit(from: "mg/dL")),
        (.bloodPressureSystolic, .millimeterOfMercury()),
        (.bloodPressureDiastolic, .millimeterOfMercury()),
    ]

    // Spans: sleep with its stages, stillness, the watch's heart alerts.
    private static let spans: [HKCategoryTypeIdentifier] = [
        .sleepAnalysis, .mindfulSession, .highHeartRateEvent, .lowHeartRateEvent,
        .irregularHeartRhythmEvent, .lowCardioFitnessEvent,
    ]

    private static var kinds: [HKSampleType] {
        [HKQuantityType(.heartRate)]
            + (totals + readings).map { HKQuantityType($0.0) }
            + spans.map { HKCategoryType($0) }
            + [HKWorkoutType.workoutType()]
    }

    private static var everything: Set<HKObjectType> { Set(kinds) }

    private init() {
        telling = defaults.bool(forKey: "health.telling")
        heard = defaults.object(forKey: "health.heard") as? Date
        guard HKHealthStore.isHealthDataAvailable(), !eyes else { return }
        Task { await readAsked() }
        watch()
    }

    func tell() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        telling = true
        defaults.set(true, forKey: "health.telling")
        Keychain.keepAfterFirstUnlock()
        Task {
            try? await store.requestAuthorization(toShare: [], read: Self.everything)
            await readAsked()
            watch()
            await drain()
        }
    }

    func stop() {
        telling = false
        defaults.set(false, forKey: "health.telling")
        for query in watching { store.stop(query) }
        watching = []
        store.disableAllBackgroundDelivery { _, _ in }
    }

    // On opening the app: whatever Health has had since, if not lately.
    func freshen() {
        guard telling, !eyes else { return }
        if let lastDrained, Date().timeIntervalSince(lastDrained) < 15 * 60 { return }
        Task { await drain() }
    }

    // A wake the app earned for itself (Wakes), its word already said: a
    // drain within the time given, returning when it is over.
    func catchUp(within seconds: TimeInterval) async {
        guard telling, !eyes else { return }
        await withCheckedContinuation { (over: CheckedContinuation<Void, Never>) in
            waiting.append { over.resume() }
            if draining { again = true; return }
            Task { await drain(within: seconds, word: false) }
        }
    }

    private func readAsked() async {
        let status = try? await store.statusForAuthorizationRequest(toShare: [], read: Self.everything)
        unasked = status == .shouldRequest
    }

    // One watch per type, so Health wakes the app when that type has news.
    // Started at launch as well as on his yes, since a wake needs its watch.
    private func watch() {
        guard telling, !eyes, watching.isEmpty else { return }
        for type in Self.kinds {
            let query = HKObserverQuery(sampleType: type, predicate: nil) { _, done, error in
                guard error == nil else { done(); return }
                Task { @MainActor in Health.shared.woken(done) }
            }
            store.execute(query)
            watching.append(query)
            store.enableBackgroundDelivery(for: type, frequency: .hourly) { _, _ in }
        }
    }

    // Each watch fires once when it starts and again with each wake; many at
    // once make one drain, and each is told when it is over.
    private func woken(_ done: @escaping () -> Void) {
        waiting.append(done)
        if draining { again = true; return }
        Task { await drain() }
    }

    // Everything new, in turn: the totals, the heart, then the rest. Stops
    // at the first batch the house did not hear, or when the time is spent.
    private func drain(within seconds: TimeInterval = 22, word: Bool = true) async {
        if draining { again = true; return }
        guard telling, !eyes, let address = Keychain.loadHouseAddress(), !address.isEmpty else {
            finish()
            return
        }
        draining = true
        let task = UIApplication.shared.beginBackgroundTask(withName: "health")
        if word, UIApplication.shared.applicationState == .background {
            await PhoneWord.shared.say(.wake)?.value
        }
        let client = HouseClient(baseAddress: address)
        let until = Date().addingTimeInterval(seconds)
        repeat {
            again = false
            var going = true
            for (id, unit) in Self.totals where going {
                going = await fold(HKQuantityType(id), unit: unit, every: DateComponents(hour: 1),
                                   options: .cumulativeSum, client: client, until: until)
            }
            if going {
                going = await fold(HKQuantityType(.heartRate), unit: Self.bpm, every: DateComponents(minute: 5),
                                   options: [.discreteAverage, .discreteMin, .discreteMax], client: client, until: until)
            }
            var anchored: [(HKSampleType, HKUnit?)] = Self.readings.map { (HKQuantityType($0.0), $0.1) }
            anchored += Self.spans.map { (HKCategoryType($0), nil) }
            anchored.append((HKWorkoutType.workoutType(), nil))
            for (type, unit) in anchored where going {
                going = await follow(type, unit: unit, client: client, until: until)
            }
            if !going { break }
        } while again && Date() < until
        lastDrained = Date()
        draining = false
        finish()
        UIApplication.shared.endBackgroundTask(task)
    }

    private func finish() {
        let done = waiting
        waiting = []
        for call in done { call() }
    }

    // Health's own statistics by the interval, from where the house last
    // had them; the last six hours stay open, so they go again as they fill.
    // A year back the first time, a window at a time.
    private func fold(_ type: HKQuantityType, unit: HKUnit, every: DateComponents,
                      options: HKStatisticsOptions, client: HouseClient, until: Date) async -> Bool {
        let key = "health.through." + type.identifier
        let calendar = Calendar.current
        let now = Date()
        var start = defaults.object(forKey: key) as? Date
            ?? calendar.date(byAdding: .year, value: -1, to: calendar.startOfDay(for: now))!
        let span: TimeInterval = every.hour != nil ? 60 * 86400 : 5 * 86400
        while start < now {
            guard Date() < until else { return false }
            let end = min(start.addingTimeInterval(span), now)
            let descriptor = HKStatisticsCollectionQueryDescriptor(
                predicate: .quantitySample(type: type, predicate: HKQuery.predicateForSamples(withStart: start, end: end)),
                options: options, anchorDate: calendar.startOfDay(for: start), intervalComponents: every)
            guard let collection = try? await descriptor.result(for: store) else { return false }
            var rows: [Row] = []
            collection.enumerateStatistics(from: start, to: end) { stats, _ in
                if let sum = stats.sumQuantity() {
                    rows.append(Row(type.identifier, stats.startDate, stats.endDate, sum.doubleValue(for: unit), unit,
                                    source: "Health", meta: ["fold": .text("sum")]))
                } else if let mean = stats.averageQuantity() {
                    var meta: [String: Note] = ["fold": .text("mean")]
                    if let low = stats.minimumQuantity() { meta["min"] = .number(Self.trim(low.doubleValue(for: unit))) }
                    if let high = stats.maximumQuantity() { meta["max"] = .number(Self.trim(high.doubleValue(for: unit))) }
                    rows.append(Row(type.identifier, stats.startDate, stats.endDate, mean.doubleValue(for: unit), unit,
                                    source: "Health", meta: meta))
                }
            }
            guard await post(rows, client: client) else { return false }
            // Floored to the interval's edge, so the next first row is whole,
            // never a part total sent over the house's full one.
            let open = now.addingTimeInterval(-6 * 3600)
            let edge = every.hour != nil
                ? calendar.dateInterval(of: .hour, for: open)?.start ?? open
                : Date(timeIntervalSinceReferenceDate: (open.timeIntervalSinceReferenceDate / 300).rounded(.down) * 300)
            let through = min(end, edge)
            if through > start { defaults.set(through, forKey: key) }
            if end >= now { break }
            start = end
        }
        return true
    }

    // New samples since the anchor, 2,000 at a time; the anchor moves only
    // once the house has them.
    private func follow(_ type: HKSampleType, unit: HKUnit?, client: HouseClient, until: Date) async -> Bool {
        let key = "health.anchor." + type.identifier
        while Date() < until {
            let anchor = (defaults.data(forKey: key)).flatMap {
                try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: $0)
            }
            let descriptor = HKAnchoredObjectQueryDescriptor(predicates: [.sample(type: type)], anchor: anchor, limit: 2000)
            guard let result = try? await descriptor.result(for: store) else { return false }
            let rows = result.addedSamples.compactMap { Self.row($0, unit: unit) }
            guard await post(rows, client: client) else { return false }
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: result.newAnchor, requiringSecureCoding: true) {
                defaults.set(data, forKey: key)
            }
            if result.addedSamples.count < 2000 { return true }
        }
        return false
    }

    // True when the house heard the batch or refused it (let go); false when
    // it did not hear, so the place is kept.
    private func post(_ rows: [Row], client: HouseClient) async -> Bool {
        for start in stride(from: 0, to: rows.count, by: 2000) {
            let batch = Batch(samples: Array(rows[start..<min(start + 2000, rows.count)]))
            guard let body = try? JSONEncoder().encode(batch) else { continue }
            switch await client.health(body) {
            case .heard:
                heard = Date()
                defaults.set(heard, forKey: "health.heard")
            case .refused:
                continue
            case .unheard:
                return false
            }
        }
        return true
    }

    private static func row(_ sample: HKSample, unit: HKUnit?) -> Row? {
        let source = sample.sourceRevision.source.name
        let minutes = HKUnit.minute()
        let length = sample.endDate.timeIntervalSince(sample.startDate) / 60
        if let reading = sample as? HKQuantitySample, let unit {
            return Row(reading.quantityType.identifier, reading.startDate, reading.endDate,
                       reading.quantity.doubleValue(for: unit), unit, source: source)
        }
        if let span = sample as? HKCategorySample {
            var meta: [String: Note]?
            if span.categoryType.identifier == HKCategoryTypeIdentifier.sleepAnalysis.rawValue {
                meta = ["stage": .text(stage(span.value))]
            }
            return Row(span.categoryType.identifier, span.startDate, span.endDate, length, minutes, source: source, meta: meta)
        }
        if let workout = sample as? HKWorkout {
            var meta: [String: Note] = ["activity": .text(activity(workout.workoutActivityType))]
            if let energy = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity() {
                meta["energy"] = .number(trim(energy.doubleValue(for: .kilocalorie())))
            }
            let distances: [HKQuantityTypeIdentifier] = [.distanceWalkingRunning, .distanceCycling, .distanceSwimming]
            if let distance = distances.lazy.compactMap({ workout.statistics(for: HKQuantityType($0))?.sumQuantity() }).first {
                meta["distance"] = .number(trim(distance.doubleValue(for: .meter())))
            }
            return Row("HKWorkoutTypeIdentifier", workout.startDate, workout.endDate, length, minutes, source: source, meta: meta)
        }
        return nil
    }

    private static func trim(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }

    private static func stage(_ value: Int) -> String {
        switch HKCategoryValueSleepAnalysis(rawValue: value) {
        case .inBed: return "inBed"
        case .awake: return "awake"
        case .asleepCore: return "core"
        case .asleepDeep: return "deep"
        case .asleepREM: return "rem"
        default: return "asleep"
        }
    }

    private static func activity(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .walking: return "walking"
        case .running: return "running"
        case .cycling: return "cycling"
        case .hiking: return "hiking"
        case .swimming: return "swimming"
        case .yoga: return "yoga"
        case .traditionalStrengthTraining: return "strength"
        case .functionalStrengthTraining: return "functional strength"
        case .coreTraining: return "core"
        case .highIntensityIntervalTraining: return "intervals"
        case .elliptical: return "elliptical"
        case .rowing: return "rowing"
        case .stairClimbing, .stairs: return "stairs"
        case .pilates: return "pilates"
        case .cooldown: return "cooldown"
        case .mindAndBody: return "mind and body"
        default: return "other \(type.rawValue)"
        }
    }
}

// One row of the house's contract: {"type", "start", "end", "value", "unit",
// "source", "meta"}.
private struct Row: Encodable {
    let type: String
    let start: String
    let end: String
    let value: Double
    let unit: String
    let source: String
    let meta: [String: Note]?

    private static let iso = ISO8601DateFormatter()

    init(_ type: String, _ start: Date, _ end: Date, _ value: Double, _ unit: HKUnit,
         source: String, meta: [String: Note]? = nil) {
        self.type = type
        self.start = Row.iso.string(from: start)
        self.end = Row.iso.string(from: end)
        self.value = (value * 1000).rounded() / 1000
        self.unit = unit.unitString
        self.source = source
        self.meta = meta
    }
}

private struct Batch: Encodable { let samples: [Row] }

private enum Note: Encodable {
    case text(String)
    case number(Double)

    func encode(to encoder: Encoder) throws {
        var one = encoder.singleValueContainer()
        switch self {
        case .text(let words): try one.encode(words)
        case .number(let value): try one.encode(value)
        }
    }
}

// The Settings sheet's section: when the house last heard from Health, what
// the phone tells, and one thing to press.
struct HealthSection: View {
    @ObservedObject private var health = Health.shared

    var body: some View {
        SettingsRoom("How you are", note: note) {
            if health.telling, let heard = health.heard {
                HeardLine(words: "Heard", hour: WhereaboutsSection.time(heard))
            } else if health.telling {
                Text("The house has not heard from Health yet.")
                    .font(.system(.body, design: .serif).italic())
                    .foregroundStyle(Theme.ink.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 28) {
                if !health.telling {
                    SettingsAction("Tell the house", run: health.tell)
                } else {
                    if health.unasked {
                        SettingsAction("Ask Health", run: health.tell)
                    }
                    SettingsAction("Stop telling", quiet: true, run: health.stop)
                }
            }
        }
    }

    private var note: String {
        health.telling
            ? "Only the house hears it; the phone keeps only where it left off. What Health lets it read is yours to change in the Health app, under Sharing."
            : "Now and then, even with the app closed, the phone tells the house what Health holds: steps, heart, sleep, workouts and the rest, folded on the phone first. Only the house hears it; the phone keeps only where it left off."
    }
}
