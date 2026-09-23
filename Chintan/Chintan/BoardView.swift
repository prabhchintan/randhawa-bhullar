import SwiftUI

// The board: his to-dos as the house keeps them, read from the house door
// and lettered on a plaque over the painting, in the house's order. Read
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

// The painting holds the top of the screen; the board is lettered on one
// plaque below it, each thing by its gist with the reasons in a smaller
// hand, the rest on tap.
struct BoardView: View {
    @State private var sections: [BoardSection] = []
    @State private var errorText: String?
    @State private var loaded = false
    @State private var open: Set<UUID> = []

    private var count: Int { sections.reduce(0) { $0 + $1.items.filter { !$0.done }.count } }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    heading
                        .padding(.top, geo.size.height * 0.30)
                        .padding(.horizontal, 6)
                    if !sections.isEmpty || errorText != nil {
                        board.plaque()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .fadedEdges()
        }
        .background { PaintedGround(head: 160) }
        .toolbar(.hidden, for: .navigationBar)
        .refreshable { await refresh() }
        .task { await refresh() }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("The board")
                .font(Theme.label())
                .tracking(0.8)
                .foregroundStyle(Theme.bone.opacity(0.78))
            Text(summary)
                .font(.system(.title, design: .serif).weight(.semibold))
                .foregroundStyle(Theme.bone)
        }
        .shadow(color: .black.opacity(0.6), radius: 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .bottom) {
            LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black.opacity(0.45), location: 0.55), .init(color: .clear, location: 1)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 340)
                .padding(.horizontal, -40)
                .offset(y: 110)
        }
    }

    private var summary: String {
        if !loaded { return " " }
        if errorText != nil && sections.isEmpty { return "Out of reach." }
        switch count {
        case 0: return "Nothing on the board."
        case 1: return "One thing open."
        default:
            let f = NumberFormatter()
            f.numberStyle = .spellOut
            let n = f.string(from: count as NSNumber) ?? "\(count)"
            return n.prefix(1).uppercased() + n.dropFirst() + " things open."
        }
    }

    private var board: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let errorText {
                Label(errorText, systemImage: "wifi.slash")
                    .font(.footnote)
                    .foregroundStyle(Theme.ink.opacity(0.7))
                    .padding(.vertical, 14)
            }
            ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                Text(section.title)
                    .font(Theme.label(.caption))
                    .tracking(1)
                    .foregroundStyle(Theme.gilt)
                    .padding(.top, index == 0 ? 16 : 26)
                    .padding(.bottom, 4)
                ForEach(Array(section.items.enumerated()), id: \.element.id) { i, item in
                    // The date is lettered once for a run of things due the same day.
                    row(item, dated: i == 0 || section.items[i - 1].date != item.date)
                    if item.id != section.items.last?.id {
                        Rectangle().fill(Theme.gilt.opacity(0.28)).frame(height: 0.5)
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 8)
    }

    private func row(_ item: BoardItem, dated: Bool) -> some View {
        let isOpen = open.contains(item.id)
        return HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.gist)
                    .font(.body)
                    .foregroundStyle(Theme.ink.opacity(item.done ? 0.45 : 1))
                    .strikethrough(item.done, color: Theme.ink.opacity(0.45))
                if !item.why.isEmpty {
                    Text(item.why)
                        .font(.footnote)
                        .foregroundStyle(Theme.ink.opacity(0.6))
                        .lineLimit(isOpen ? nil : 2)
                }
            }
            Spacer(minLength: 0)
            if let day = item.day {
                DueMark(day: day).opacity(dated ? 1 : 0)
            }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                if isOpen { open.remove(item.id) } else { open.insert(item.id) }
            }
        }
    }

    private func refresh() async {
        guard let address = Keychain.loadHouseAddress(), !address.isEmpty else {
            errorText = "No house address yet. Add it in Settings."
            loaded = true
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

// When a thing is due, lettered small: the weekday over the day, saffron
// once the day has come.
private struct DueMark: View {
    let day: Date

    var body: some View {
        let come = Calendar.current.startOfDay(for: day) <= Calendar.current.startOfDay(for: .now)
        VStack(alignment: .trailing, spacing: 0) {
            Text(day.formatted(.dateTime.weekday(.abbreviated)))
                .font(Theme.label(.caption2))
                .tracking(0.6)
            Text(day.formatted(.dateTime.day().month(.abbreviated)))
                .font(.system(.footnote, design: .serif))
        }
        .foregroundStyle(come ? Theme.saffron : Theme.gilt)
        .fixedSize()
    }
}

extension BoardItem {
    // The reasons after the gist, as the house wrote them.
    var why: String {
        var rest = String(text.dropFirst(gist.count))
        while let first = rest.first, " ,;:".contains(first) { rest.removeFirst() }
        if rest.hasPrefix("(") {
            rest.removeFirst()
            if rest.hasSuffix(")") {
                rest.removeLast()
            } else if let close = rest.firstIndex(of: ")") {
                rest.replaceSubrange(close...close, with: ";")
            }
        }
        return rest.prefix(1).uppercased() + rest.dropFirst()
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
