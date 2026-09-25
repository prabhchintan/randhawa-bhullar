import CoreLocation
import SwiftUI
import UIKit

// Where he is, told to the house a few times a day so the day's line can say
// at home, at work or out. Significant-change monitoring only: the phone wakes
// the app when it has moved some distance, near free on battery. Each fix goes
// to the house (`POST /v1/location`) and is forgotten; the phone keeps only
// the place the house named and when. With the always permission, each place
// he stays is told too, once on coming and once on leaving (CLVisit, near free
// as well). Asked for on the Settings sheet, never at launch. Made at launch
// all the same, so a wake in the background finds its delegate.
@MainActor
final class Whereabouts: NSObject, ObservableObject {
    static let shared = Whereabouts()

    enum State { case unasked, whileOpen, always, refused }

    @Published private(set) var state: State = .unasked
    // His choice on this phone; the permission alone does not start it.
    @Published private(set) var telling: Bool
    @Published private(set) var place: String?
    @Published private(set) var heard: Date?

    private let manager = CLLocationManager()
    private let defaults = UserDefaults.standard
    private var lastSent: Date?
    // Visits the house did not hear, held in memory only until the next send.
    private var unheard: [CLVisit] = []

    // The house's eyes in the simulator never tell the house anything.
    private let eyes = ProcessInfo.processInfo.arguments.contains("--house")

    private override init() {
        telling = defaults.bool(forKey: "where.telling")
        place = defaults.string(forKey: "where.place")
        heard = defaults.object(forKey: "where.heard") as? Date
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        read(manager.authorizationStatus)
        resume()
    }

    // First the while-open permission, then, once that is given, always.
    func tell() {
        telling = true
        defaults.set(true, forKey: "where.telling")
        Keychain.keepAfterFirstUnlock()
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse where !defaults.bool(forKey: "where.askedAlways"):
            defaults.set(true, forKey: "where.askedAlways")
            manager.requestAlwaysAuthorization()
        case .denied, .restricted, .authorizedWhenInUse:
            openSettings()
        default:
            break
        }
        resume()
    }

    func stop() {
        telling = false
        defaults.set(false, forKey: "where.telling")
        manager.stopMonitoringSignificantLocationChanges()
        manager.stopMonitoringVisits()
        unheard = []
    }

    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // On opening the app: a fresh fix, if the last one is not recent.
    func freshen() {
        guard telling, !eyes, state == .always || state == .whileOpen else { return }
        if let lastSent, Date().timeIntervalSince(lastSent) < 15 * 60 { return }
        manager.requestLocation()
    }

    private func resume() {
        guard telling, !eyes, state == .always || state == .whileOpen else { return }
        manager.startMonitoringSignificantLocationChanges()
        // Visits come only with always; the phone says when he stays.
        if state == .always { manager.startMonitoringVisits() } else { manager.stopMonitoringVisits() }
    }

    private func read(_ status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways: state = .always
        case .authorizedWhenInUse: state = .whileOpen
        case .denied, .restricted: state = .refused
        default: state = .unasked
        }
    }

    private func send(_ fix: CLLocation) async {
        await send { try await $0.location(fix) }
    }

    // A visit is told once it is known; one the house missed waits for the
    // next send, a fix's or another visit's, while the app lives.
    private func send(_ visit: CLVisit) async {
        guard telling else { return }
        unheard.append(visit)
        if unheard.count > 20 { unheard.removeFirst(unheard.count - 20) }
        await send { _ in nil }
    }

    private func send(_ told: (HouseClient) async throws -> HouseClient.Heard?) async {
        guard !eyes, let address = Keychain.loadHouseAddress(), !address.isEmpty else { return }
        let house = HouseClient(baseAddress: address)
        lastSent = Date()
        // A wake in the background has a few seconds; ask for them.
        let task = UIApplication.shared.beginBackgroundTask(withName: "where")
        defer { UIApplication.shared.endBackgroundTask(task) }
        // A move that woke the app is a wake in the phone's word too, and the
        // word (with the wifi's name) goes first, so the house reads the fix
        // beside the network it came from.
        if UIApplication.shared.applicationState == .background {
            await PhoneWord.shared.say(.wake)?.value
        }
        var last: HouseClient.Heard?
        // Taken out before the first await, so two sends never tell one twice.
        var pending = unheard
        unheard = []
        while let visit = pending.first {
            guard let reply = try? await house.location(visit) else { break }
            pending.removeFirst()
            last = reply
        }
        unheard = pending + unheard
        if let reply = try? await told(house) { last = reply }
        guard let reply = last else { return }
        heard = Date()
        defaults.set(heard, forKey: "where.heard")
        if let named = reply.place {
            place = named
            defaults.set(named, forKey: "where.place")
        }
    }
}

extension Whereabouts: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.read(status)
            self.resume()
            self.freshen()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let fix = locations.last else { return }
        Task { @MainActor in await self.send(fix) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        Task { @MainActor in await self.send(visit) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}

// The Settings sheet's section: what it does, in the house's words, and one
// thing to press for the state it is in.
struct WhereaboutsSection: View {
    @ObservedObject private var whereabouts = Whereabouts.shared

    var body: some View {
        SettingsRoom("Where you are", note: note) {
            // The place the house last named, its hour in gilt, as Home sets one.
            if whereabouts.telling, let heard = whereabouts.heard {
                HeardLine(words: Self.words(whereabouts.place), hour: Self.time(heard))
            }
            if let line {
                Text(line)
                    .font(.system(.body, design: .serif).italic())
                    .foregroundStyle(Theme.ink.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 28) {
                ForEach(actions, id: \.title) { action in
                    SettingsAction(action.title, quiet: action.stop, run: action.run)
                }
            }
        }
    }

    private var line: String? {
        guard whereabouts.telling else { return nil }
        switch whereabouts.state {
        case .refused:
            return "Location is off for chintan in the phone's Settings."
        case .whileOpen:
            return "The house hears only while the app is open."
        case .always:
            return "The house hears a few times a day, and each place you stay."
        case .unasked:
            return nil
        }
    }

    // The whole of it before he says yes; once on, only the promise.
    private var note: String {
        whereabouts.telling
            ? "Only the house hears it; the phone keeps nothing but the word."
            : "A few times a day the phone tells the house roughly where it is and the wifi it is on, so the day's line can say at home, at work or out; told always, each place you stay and for how long too. Only the house hears it; the phone keeps nothing but the word."
    }

    static func time(_ heard: Date) -> String {
        heard.formatted(Calendar.current.isDateInToday(heard) ? .dateTime.hour().minute() : .dateTime.weekday(.abbreviated).hour().minute())
    }

    // The house's word for the place, as the day's line would say it.
    static func words(_ place: String?) -> String {
        switch place {
        case "home": return "At home"
        case "work": return "At work"
        case "out": return "Out"
        case let other?: return other.prefix(1).uppercased() + other.dropFirst()
        case nil: return "Heard"
        }
    }

    private typealias Action = (title: String, stop: Bool, run: () -> Void)

    private var actions: [Action] {
        let begin: Action = ("Tell the house", false, whereabouts.tell)
        let stop: Action = ("Stop telling", true, whereabouts.stop)
        guard whereabouts.telling else { return [begin] }
        switch whereabouts.state {
        case .unasked: return [begin]
        case .whileOpen: return [("Tell it always", false, whereabouts.tell), stop]
        case .refused: return [("Open the phone's Settings", false, whereabouts.openSettings), stop]
        case .always: return [stop]
        }
    }
}
