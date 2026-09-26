import BackgroundTasks
import UIKit

// The wakes the app earns for itself (chunk N, slice 5), beside the ones a
// move or Health gives it. Now and then iOS lets it run a moment (app
// refresh, half an hour after the last at the soonest, when iOS judges the
// phone will be used); and once a night, on the charger with a network, it
// runs for minutes (processing), long enough for Health's backlog and the
// week's motion. Each says the phone's "wake" word, drains what the senses
// hold, and asks for the next. Asked for at launch and each time the app is
// put away; a sense that is off sends nothing, as always.
@MainActor
enum Wakes {
    static let refresh = "Prabhchintan.Chintan.refresh"
    static let fold = "Prabhchintan.Chintan.fold"

    // The house's eyes in the simulator never tell the house anything.
    private static let eyes = ProcessInfo.processInfo.arguments.contains("--house")

    // Before launch ends, as iOS requires; the handlers run on the main queue.
    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refresh, using: .main) { task in
            MainActor.assumeIsolated { run(task, within: 25) }
        }
        BGTaskScheduler.shared.register(forTaskWithIdentifier: fold, using: .main) { task in
            MainActor.assumeIsolated { run(task, within: 8 * 60) }
        }
    }

    // A request for the same wake replaces the one before, so asking often is free.
    static func ask() {
        guard !eyes else { return }
        let soon = BGAppRefreshTaskRequest(identifier: refresh)
        soon.earliestBeginDate = Date().addingTimeInterval(30 * 60)
        try? BGTaskScheduler.shared.submit(soon)
        let night = BGProcessingTaskRequest(identifier: fold)
        night.requiresExternalPower = true
        night.requiresNetworkConnectivity = true
        night.earliestBeginDate = Calendar.current.nextDate(
            after: Date(), matching: DateComponents(hour: 2), matchingPolicy: .nextTime)
        try? BGTaskScheduler.shared.submit(night)
    }

    // The word first, then the motion, then Health with the time this wake
    // has. Cut short by iOS, the task ends at once; every sense keeps its
    // place until the house has heard, so the next wake carries the rest.
    private static func run(_ task: BGTask, within seconds: TimeInterval) {
        ask()
        var over = false
        func end(_ whole: Bool) {
            guard !over else { return }
            over = true
            task.setTaskCompleted(success: whole)
        }
        let work = Task {
            await PhoneWord.shared.say(.wake)?.value
            await Motion.shared.drained()
            await Health.shared.catchUp(within: seconds)
            end(true)
        }
        task.expirationHandler = {
            Task { @MainActor in
                work.cancel()
                end(false)
            }
        }
    }
}
