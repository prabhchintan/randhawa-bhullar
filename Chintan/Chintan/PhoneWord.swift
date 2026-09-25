import AVFoundation
import Network
import NetworkExtension
import SwiftUI
import UIKit

// The phone's own word (chunk N, slices 1 and 1b): each time the app comes to
// the front or is put away, each time a move wakes it, and each lock or unlock
// it is awake for, the phone tells the house its state (`POST /v1/phone`):
// unlocked, battery and charging, low power, how warm it runs, wifi or
// cellular and the wifi's name, headphones or speaker. So the house can tell
// when he is on the phone and when he is home. On unless he stops it on the
// Settings sheet; it needs no permission, but the wifi's name comes only once
// Where you are has the location permission (Apple's rule). A word the house
// did not hear waits, a day at most, and goes with the next; a word the house
// refused (4xx) is let go.
@MainActor
final class PhoneWord: ObservableObject {
    static let shared = PhoneWord()

    enum Event: String { case foreground, background, wake, unlocked, locked }

    @Published private(set) var telling: Bool
    @Published private(set) var heard: Date?

    private let defaults = UserDefaults.standard
    private let path = NWPathMonitor()
    // Unknown until the path first answers, a moment after launch; left out till then.
    private var network: String?
    private var last: Event?
    private var pending: [Data]
    private var sending = false
    // The last word still being put together, so the next waits its turn.
    private var queued: Task<Void, Never>?

    // The house's eyes in the simulator never tell the house anything.
    private let eyes = ProcessInfo.processInfo.arguments.contains("--house")

    private init() {
        telling = defaults.object(forKey: "phone.telling") as? Bool ?? true
        heard = defaults.object(forKey: "phone.heard") as? Date
        pending = defaults.array(forKey: "phone.pending") as? [Data] ?? []
        UIDevice.current.isBatteryMonitoringEnabled = true
        path.pathUpdateHandler = { update in
            let kind = update.status != .satisfied ? "none"
                : update.usesInterfaceType(.wifi) ? "wifi"
                : update.usesInterfaceType(.cellular) ? "cellular" : "wifi"
            Task { @MainActor in PhoneWord.shared.network = kind }
        }
        path.start(queue: DispatchQueue(label: "phone.path"))
        let center = NotificationCenter.default
        center.addObserver(forName: UIApplication.protectedDataDidBecomeAvailableNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in PhoneWord.shared.say(.unlocked) }
        }
        center.addObserver(forName: UIApplication.protectedDataWillBecomeUnavailableNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in PhoneWord.shared.say(.locked) }
        }
        if telling { Keychain.keepAfterFirstUnlock() }
    }

    func tell() {
        telling = true
        defaults.set(true, forKey: "phone.telling")
        Keychain.keepAfterFirstUnlock()
        say(.foreground)
    }

    func stop() {
        telling = false
        defaults.set(false, forKey: "phone.telling")
        pending = []
        defaults.removeObject(forKey: "phone.pending")
    }

    // From the app's phase: the front, or put away. A glance at the
    // notification centre passes through inactive and back, which is not a
    // new word, so the same event twice running is said once.
    func scene(_ phase: ScenePhase) {
        switch phase {
        case .active: say(.foreground)
        case .background: say(.background)
        default: break
        }
    }

    // Said now, in order: the state is read at once, the wifi's name is asked
    // of the phone after the word before it, then the word joins the waiting
    // and goes. The task returned ends when the house has had its chance to
    // hear it, so a fix can follow its word.
    @discardableResult
    func say(_ event: Event) -> Task<Void, Never>? {
        guard telling, !eyes else { return nil }
        if event == last, event == .foreground || event == .background { return nil }
        last = event
        let device = UIDevice.current
        var word = Word(
            event: event.rawValue,
            at: ISO8601DateFormatter().string(from: Date()),
            unlocked: UIApplication.shared.isProtectedDataAvailable,
            battery: device.batteryLevel < 0 ? nil : (Double(device.batteryLevel) * 100).rounded() / 100,
            charging: device.batteryState == .unknown ? nil : device.batteryState != .unplugged,
            lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled,
            thermal: Self.thermal(ProcessInfo.processInfo.thermalState),
            network: network,
            audio: Self.audio())
        // Put away, the phone has a few seconds; ask for them before asking the wifi.
        let task = UIApplication.shared.beginBackgroundTask(withName: "phone.word")
        let previous = queued
        let joined = Task {
            await previous?.value
            word.ssid = await Self.wifi()
            if let body = try? JSONEncoder().encode(word) {
                pending = Array((pending + [body]).suffix(200))
                keep()
            }
            UIApplication.shared.endBackgroundTask(task)
        }
        queued = joined
        return Task {
            await joined.value
            await flush()
        }
    }

    // Every word waiting, oldest first; stops at the first the house did not
    // hear, so the rest go with the next.
    private func flush() async {
        guard !sending, let address = Keychain.loadHouseAddress(), !address.isEmpty else { return }
        sending = true
        defer { sending = false }
        // Put away or woken, the phone has a few seconds; ask for them.
        let task = UIApplication.shared.beginBackgroundTask(withName: "phone")
        defer { UIApplication.shared.endBackgroundTask(task) }
        let client = HouseClient(baseAddress: address)
        let old = Date().addingTimeInterval(-24 * 3600)
        while let body = pending.first, telling {
            if Self.stale(body, before: old) {
                pending.removeFirst()
                continue
            }
            switch await client.phone(body) {
            case .heard:
                heard = Date()
                defaults.set(heard, forKey: "phone.heard")
                pending.removeFirst()
            case .refused:
                pending.removeFirst()
            case .unheard:
                keep()
                return
            }
            keep()
        }
    }

    private func keep() {
        defaults.set(pending, forKey: "phone.pending")
    }

    private static func stale(_ body: Data, before old: Date) -> Bool {
        struct At: Decodable { let at: String }
        guard let at = try? JSONDecoder().decode(At.self, from: body).at,
              let date = ISO8601DateFormatter().date(from: at) else { return true }
        return date < old
    }

    // The wifi's name, when the phone is on one and location is allowed
    // (Apple gives the name only then); nil otherwise, and in the simulator.
    private static func wifi() async -> String? {
        await NEHotspotNetwork.fetchCurrent()?.ssid
    }

    private static func thermal(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "nominal"
        }
    }

    // What the sound goes to: headphones (wired or on the air), the phone's
    // own speaker or anything else that plays aloud, or nothing.
    private static func audio() -> String {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        guard !outputs.isEmpty else { return "none" }
        let ears: Set<AVAudioSession.Port> = [.headphones, .bluetoothA2DP, .bluetoothHFP, .bluetoothLE]
        return outputs.contains { ears.contains($0.portType) } ? "headphones" : "speaker"
    }
}

private struct Word: Encodable {
    let event: String
    let at: String
    let unlocked: Bool
    let battery: Double?
    let charging: Bool?
    let lowPower: Bool
    let thermal: String
    let network: String?
    let audio: String
    var ssid: String?
    var source = "app"
}

// The Settings sheet's section: when the house last heard the phone, set as
// Where you are sets its place, what the phone tells, and one thing to press.
// On from the first launch, so the note always says what is told.
struct PhoneWordSection: View {
    @ObservedObject private var word = PhoneWord.shared

    var body: some View {
        SettingsRoom("When you are on the phone", note: note) {
            if word.telling, let heard = word.heard {
                HeardLine(words: "Heard", hour: WhereaboutsSection.time(heard))
            } else if word.telling {
                Text("The house has not heard from the phone yet.")
                    .font(.system(.body, design: .serif).italic())
                    .foregroundStyle(Theme.ink.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
            SettingsAction(word.telling ? "Stop telling" : "Tell the house",
                           quiet: word.telling,
                           run: word.telling ? word.stop : word.tell)
        }
    }

    private var note: String {
        let told = "Each time chintan opens or is put away, the phone tells the house whether it is unlocked, its battery, wifi or cellular, and headphones or speaker; with Where you are on, the wifi's name too."
        return word.telling
            ? told + " Only the house hears it; the phone keeps a word only until the house has it."
            : told + " So the house knows when you are on the phone and when you are not. Only the house hears it."
    }
}
