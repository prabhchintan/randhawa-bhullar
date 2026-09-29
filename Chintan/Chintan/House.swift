import Foundation

// The house's address as the build was given it, one constant the app and
// its widget both read. ship.sh and see.sh hand CHINTAN_HOUSE to xcodebuild
// and each Info.plist letters it as ChintanHouse, so the address never
// enters this repository and the widget needs no shared container to find
// the house. Nil when the build was given none.
enum House {
    static let address: String? = {
        let word = (Bundle.main.object(forInfoDictionaryKey: "ChintanHouse") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return word.isEmpty || word.hasPrefix("$(") ? nil : word
    }()
}
