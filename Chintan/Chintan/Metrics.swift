import MetricKit
import UIKit

// How the app itself runs on his phone, told to the house (chunk G): once a
// day iOS hands the app a day of its own numbers (launch times, hangs, scroll
// hitches, memory, battery, from the phone, not the simulator), and each goes
// to `POST /v1/metrics` as {"kind": "metrics", "version", "build", "payload"},
// the payload in MetricKit's own words. The house files them and the sprints
// read the trend. Crash and hang reports are left out: this is the app's
// pulse, not crash reporting. A day the house has not heard waits on the
// phone, at most fourteen, and goes on the next opening; a refused one is dropped.
@MainActor
final class Metrics: NSObject, MXMetricManagerSubscriber {
    static let shared = Metrics()

    // The house's eyes in the simulator never tell the house anything.
    private let eyes = ProcessInfo.processInfo.arguments.contains("--house")
    private var sending = false

    private static var waiting: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("metrics-waiting.json")
    }

    private override init() {
        super.init()
        guard !eyes else { return }
        MXMetricManager.shared.add(self)
    }

    nonisolated func didReceive(_ payloads: [MXMetricPayload]) {
        let days = payloads.map { $0.jsonRepresentation() }
        Task { @MainActor in
            keep(days)
            await send()
        }
    }

    // On opening the app: any day still waiting.
    func freshen() {
        guard !eyes else { return }
        Task { await send() }
    }

    private func keep(_ days: [Data]) {
        let all = (Self.read() + days.compactMap(Self.wrapped)).suffix(14)
        Self.write(Array(all))
    }

    // Oldest first; each day leaves the phone once the house has it or refuses it.
    private func send() async {
        guard !sending, let address = Keychain.loadHouseAddress(), !address.isEmpty else { return }
        var days = Self.read()
        guard !days.isEmpty else { return }
        sending = true
        defer { sending = false }
        let task = UIApplication.shared.beginBackgroundTask(withName: "metrics")
        defer { UIApplication.shared.endBackgroundTask(task) }
        let client = HouseClient(baseAddress: address)
        while let day = days.first {
            if await client.metrics(day) == .unheard { break }
            days.removeFirst()
            Self.write(days)
        }
    }

    // MetricKit's own JSON, inside the house's envelope.
    private static func wrapped(_ payload: Data) -> Data? {
        guard let inner = try? JSONSerialization.jsonObject(with: payload) else { return nil }
        let info = Bundle.main.infoDictionary
        let body: [String: Any] = [
            "kind": "metrics",
            "version": info?["CFBundleShortVersionString"] as? String ?? "",
            "build": info?["CFBundleVersion"] as? String ?? "",
            "payload": inner,
        ]
        return try? JSONSerialization.data(withJSONObject: body)
    }

    private static func read() -> [Data] {
        guard let data = try? Data(contentsOf: waiting),
              let list = try? JSONDecoder().decode([Data].self, from: data) else { return [] }
        return list
    }

    private static func write(_ days: [Data]) {
        if days.isEmpty {
            try? FileManager.default.removeItem(at: waiting)
            return
        }
        try? FileManager.default.createDirectory(at: waiting.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(days).write(to: waiting, options: .atomic)
    }
}
