import SwiftUI

// The board: his to-dos as the house keeps them, read from the house door
// and shown as a list, newest section first as the house prints it. Read
// only for now; marking a thing done from the phone is a later rung.
struct BoardItem: Identifiable {
    let id = UUID()
    let text: String
    let date: String?
    let done: Bool
}

struct BoardSection: Identifiable {
    let id = UUID()
    let title: String
    let items: [BoardItem]
}

struct BoardView: View {
    @State private var sections: [BoardSection] = []
    @State private var errorText: String?
    @State private var loaded = false

    var body: some View {
        List {
            if let errorText {
                Section {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(sections) { section in
                Section(section.title) {
                    ForEach(section.items) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.text)
                                .strikethrough(item.done)
                            if let date = item.date {
                                Text(date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            if loaded && sections.isEmpty && errorText == nil {
                Text("Nothing on the board.")
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await refresh() }
        .task { await refresh() }
        .navigationTitle("The board")
    }

    private func refresh() async {
        guard let address = Keychain.loadHouseAddress(), !address.isEmpty else {
            errorText = "No house address yet. Add it in Settings."
            return
        }
        do {
            let text = try await HouseClient(baseAddress: address).board()
            sections = BoardParser.parse(text)
            errorText = nil
        } catch {
            errorText = "The house is not answering. Are you on the tailnet?"
        }
        loaded = true
    }
}

// The house prints the board as plain text: a heading in capitals, then
// one task per line in the vault's own task shape, a date after the
// calendar mark and an optional phone lead after the bell. Anything the
// parser does not know is kept as a plain line.
enum BoardParser {
    static func parse(_ text: String) -> [BoardSection] {
        var sections: [BoardSection] = []
        var title = "The board"
        var items: [BoardItem] = []
        func flush() {
            if !items.isEmpty {
                sections.append(BoardSection(title: title, items: items))
            }
            items = []
        }
        for raw in text.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if line.hasPrefix("- [") {
                let done = line.hasPrefix("- [x]") || line.hasPrefix("- [X]")
                var body = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                var date: String?
                if let mark = body.range(of: "📅") {
                    let tail = body[mark.upperBound...].trimmingCharacters(in: .whitespaces)
                    date = tail.components(separatedBy: " ").first
                    body = String(body[..<mark.lowerBound]).trimmingCharacters(in: .whitespaces)
                }
                items.append(BoardItem(text: body, date: date, done: done))
            } else if !line.hasPrefix("-"), line == line.uppercased(), line.count < 40 {
                flush()
                title = line.capitalized
            } else {
                items.append(BoardItem(text: line, date: nil, done: false))
            }
        }
        flush()
        return sections
    }
}
