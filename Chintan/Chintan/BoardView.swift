import SwiftUI

// The board: his to-dos as the house keeps them, read from the house door
// and lettered on a plaque over the painting, soonest first under Today,
// each day left in the week, and Later. A thing opened on tap can be marked done.
struct BoardItem: Identifiable {
    let id = UUID()
    let text: String
    let date: String?
    let done: Bool
    // The line after its checkbox, as the house printed it; what done sends.
    var line: String = ""
}

struct BoardSection: Identifiable {
    let id = UUID()
    let title: String
    let items: [BoardItem]
    // A shelf named by its day (Today, Tomorrow, Friday): the name is the date.
    var named = false
}

// The painting holds the top of the screen; the board is lettered on one
// plaque below it, each thing by Home's short name with the reasons in a
// smaller hand, the rest on tap.
struct BoardView: View {
    @State private var sections: [BoardSection] = []
    @State private var errorText: String?
    @State private var loaded = false
    @State private var open: Set<UUID> = []
    // Lines the house has taken as done; they stay off until the next read.
    @State private var gone: Set<String> = []
    @State private var sending: UUID?
    @State private var refused: [UUID: String] = [:]
    @State private var launchOpened = false
    // The house's own short titles, by the line, when it serves them.
    @State private var titles: [String: BoardItem.Short] = [:]

    private static let foot = Theme.foot

    private var shelves: [BoardSection] { BoardSection.shelves(sections, without: gone) }
    private var count: Int { shelves.reduce(0) { $0 + $1.items.count } }

    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        heading
                            .padding(.top, geo.size.height * 0.30)
                            .padding(.horizontal, 6)
                        if !shelves.isEmpty || errorText != nil {
                            board
                        }
                    }
                    .padding(.horizontal, 16)
                    // The last leaf clears the fade whole, never cut above the tabs.
                    .padding(.bottom, Self.foot + 8)
                }
                .fadedEdges(bottom: Self.foot)
                .accessibilityIdentifier("shelves")
                .onChange(of: open) {
                    if launchOpened, let id = open.first {
                        launchOpened = false
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
        .background { PaintedGround(head: 160) }
        .refreshable { await refresh() }
        .task { await refresh() }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("The board")
                .font(Theme.label())
                .tracking(0.8)
                .foregroundStyle(Theme.bone.opacity(0.9))
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

    // Each shelf is named on the art, and under it one leaf per day: the
    // painting shows between the days instead of one long list.
    private var board: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let errorText {
                Label(errorText, systemImage: "wifi.slash")
                    .font(.footnote)
                    .foregroundStyle(Theme.ink.opacity(0.7))
                    .padding(.vertical, 14)
                    .padding(.horizontal, 18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .plaque()
            }
            ForEach(Array(shelves.enumerated()), id: \.element.title) { index, section in
                Text(section.title)
                    .font(Theme.label())
                    .tracking(1)
                    .foregroundStyle(Theme.giltOnArt)
                    .mount()
                    .padding(.top, index == 0 ? 6 : 18)
                ForEach(section.days) { day in
                    leaf(day.items, named: section.named)
                }
            }
        }
    }

    // Where the shelf's own name is the day, the leaf carries no date of its
    // own; only a thing whose day has passed still says when it fell.
    private func leaf(_ items: [BoardItem], named: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                // The date is lettered once, at the head of its leaf.
                VStack(spacing: 0) {
                    if i > 0 {
                        Rectangle().fill(Theme.gilt.opacity(0.28)).frame(height: 0.5)
                    }
                    row(item, dated: i == 0, marked: !named || item.since != nil)
                }
                .id(item.id)
                .transition(.asymmetric(insertion: .opacity, removal: .opacity.combined(with: .offset(y: -18))))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .plaque()
    }

    private func row(_ item: BoardItem, dated: Bool, marked: Bool) -> some View {
        let isOpen = open.contains(item.id)
        return HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                // Named by Home's cut, the hour in gilt after its last word,
                // so a title that wraps never splits around it.
                let short = titles[item.line] ?? item.short
                (Text(short.title.plainDashes)
                    .foregroundStyle(Theme.ink.opacity(item.done ? 0.45 : 1))
                    .strikethrough(item.done, color: Theme.ink.opacity(0.45))
                 + Text(short.hour.map { "   " + $0 } ?? "")
                    .font(Theme.label())
                    .tracking(0.6)
                    .foregroundStyle(Theme.gilt))
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                if !item.why.isEmpty {
                    Text(item.why)
                        .font(.footnote)
                        .foregroundStyle(Theme.ink.opacity(0.72))
                        .lineLimit(isOpen ? nil : 2)
                }
                if isOpen && !item.line.isEmpty {
                    doneMark(item)
                        .padding(.top, 8)
                        .transition(.opacity)
                }
            }
            Spacer(minLength: 0)
            if marked, let day = item.day {
                DueMark(day: day).opacity(dated ? 1 : 0)
            }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityIdentifier("leaf")
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                if isOpen { open.remove(item.id) } else { open.insert(item.id) }
            }
        }
    }

    // The one action on the board, lettered like a label: a hairline circle
    // and the word, gilt. The thing lifts off only once the house has it.
    private func doneMark(_ item: BoardItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                Task { await markDone(item) }
            } label: {
                HStack(spacing: 7) {
                    ZStack {
                        Circle().strokeBorder(Theme.gilt, lineWidth: 0.8)
                        if sending == item.id {
                            ProgressView().controlSize(.mini).tint(Theme.gilt)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .semibold))
                        }
                    }
                    .frame(width: 18, height: 18)
                    Text("Done")
                        .font(Theme.label(.caption))
                        .tracking(1)
                }
                .foregroundStyle(Theme.gilt)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(sending != nil)
            if let words = refused[item.id] {
                Text(words)
                    .font(.system(.footnote, design: .serif).italic())
                    .foregroundStyle(Theme.ink.opacity(0.6))
            }
        }
    }

    private func markDone(_ item: BoardItem) async {
        guard let address = Keychain.loadHouseAddress(), !address.isEmpty else { return }
        sending = item.id
        refused[item.id] = nil
        defer { sending = nil }
        do {
            try await HouseClient(baseAddress: address).done(item.line)
            withAnimation(.easeOut(duration: 0.35)) {
                _ = gone.insert(item.line)
                open.remove(item.id)
            }
        } catch HouseError.noDoor {
            withAnimation { refused[item.id] = "The house cannot take this from the phone yet." }
        } catch {
            withAnimation { refused[item.id] = "The house did not answer; still open." }
        }
    }

    private func refresh() async {
        guard let address = Keychain.loadHouseAddress(), !address.isEmpty else {
            errorText = "No house address yet. Add it in Settings."
            loaded = true
            return
        }
        let house = HouseClient(baseAddress: address)
        async let short = try? house.titles()
        do {
            let text = try await house.board()
            if let s = await short { titles = s }
            sections = BoardParser.parse(text)
            gone = []
            refused = [:]
            errorText = nil
            // For the house's eyes: a thing opened on launch, to see the action.
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "--open"), i + 1 < args.count, let n = Int(args[i + 1]) {
                let all = shelves.flatMap(\.items)
                if n < all.count {
                    launchOpened = true
                    open = [all[n].id]
                }
            }
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
                .font(Theme.label(.caption))
                .tracking(0.6)
            Text(day.formatted(.dateTime.day().month(.abbreviated)))
                .font(.system(.footnote, design: .serif))
        }
        .foregroundStyle(come ? Theme.saffron : Theme.gilt)
        .layoutPriority(1)
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

extension BoardSection {
    // A run of things due the same day, one leaf on the board.
    struct Day: Identifiable {
        let id: String
        let items: [BoardItem]
    }

    var days: [Day] {
        var runs: [Day] = []
        for item in items {
            if let last = runs.last, last.items.first?.date == item.date {
                runs[runs.count - 1] = Day(id: last.id, items: last.items + [item])
            } else {
                runs.append(Day(id: item.date ?? "undated-\(runs.count)", items: [item]))
            }
        }
        return runs
    }

    // The open things by when they fall, soonest first: Today (and anything
    // already past), then each day left in the week (through Sunday) on a
    // shelf of its own, Tomorrow and then the weekday by name, and Later for
    // the rest combined. Things without a date close Later in the house's
    // own order. Done means gone.
    static func shelves(_ sections: [BoardSection], without gone: Set<String>) -> [BoardSection] {
        var cal = Calendar.current
        cal.firstWeekday = 2
        let today = cal.startOfDay(for: .now)
        // The week ends on Sunday: Monday's bill belongs to the next one.
        let week = cal.dateInterval(of: .weekOfYear, for: today)?.end
            ?? cal.date(byAdding: .day, value: 7, to: today) ?? today
        let open = sections.flatMap(\.items).filter { !$0.done && !gone.contains($0.line) }
        let dated = open.filter { $0.day != nil }.sorted { $0.day! < $1.day! }
        let undated = open.filter { $0.day == nil }
        var shelves = [BoardSection(title: "Today", items: dated.filter { $0.day! <= today }, named: true)]
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today) ?? today
        var day = tomorrow
        while day < week {
            let items = dated.filter { cal.isDate($0.day!, inSameDayAs: day) }
            let title = day == tomorrow ? "Tomorrow" : day.formatted(.dateTime.weekday(.wide))
            shelves.append(BoardSection(title: title, items: items, named: true))
            day = cal.date(byAdding: .day, value: 1, to: day) ?? week
        }
        shelves.append(BoardSection(title: "Later", items: dated.filter { $0.day! >= week } + undated))
        return shelves.filter { !$0.items.isEmpty }
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
                let whole = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                var body = whole
                var date: String?
                if let mark = body.range(of: "📅") {
                    let tail = body[mark.upperBound...].trimmingCharacters(in: .whitespaces)
                    date = tail.components(separatedBy: " ").first
                    body = String(body[..<mark.lowerBound]).trimmingCharacters(in: .whitespaces)
                }
                items.append(BoardItem(text: body, date: date, done: done, line: whole))
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
