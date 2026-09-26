import AppIntents

// The one thing no app can see for itself: which other app he opens (chunk N,
// slice 5). A Shortcuts automation on App, Is Opened, run at once, runs this
// without bringing chintan forward, and the phone's word carries the app's
// name to the house: {"event": "app", "app", "source": "shortcut"}. Quiet
// when When you are on the phone is stopped.
struct TellAppOpened: AppIntent {
    static var title: LocalizedStringResource = "Tell the house an app opened"
    static var description = IntentDescription("The phone tells the house which app you opened. Only the house hears it.")
    static var openAppWhenRun = false

    @Parameter(title: "App")
    var app: String

    static var parameterSummary: some ParameterSummary {
        Summary("Tell the house \(\.$app) opened")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let name = app.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            await PhoneWord.shared.say(.app, app: String(name.prefix(80)))?.value
        }
        return .result()
    }
}
