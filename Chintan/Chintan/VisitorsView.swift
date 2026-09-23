import SwiftUI

// The guest book: the site's visitors as people, the way a museum keeps a
// book by the door. The house folds Pulse's sessions into people (bots and
// datacenters left out); a person is one leaf, newest first, and opens to
// their visits, each page and the time spent on it. Over the painting on
// glass, plaques for the text, the same wall as the board.
// (Prab, 2026-09-23 07:15: "a running list of actual humans who visited,
// where from, and if I want I can click on it and it shows me details".)
struct VisitorsView: View {
    @State private var people: [HouseClient.Visitor] = []
    @State private var errorText: String?
    @State private var loaded = false

    private struct Shelf: Identifiable {
        let title: String
        let rows: [HouseClient.Visitor]
        var id: String { title }
    }

    private var shelves: [Shelf] {
        let now = Date.now.timeIntervalSince1970
        let week = people.filter { now - Double($0.last) < 7 * 86400 }
        let month = people.filter { now - Double($0.last) >= 7 * 86400 && now - Double($0.last) < 31 * 86400 }
        let earlier = people.filter { now - Double($0.last) >= 31 * 86400 }
        return [Shelf(title: "This week", rows: week), Shelf(title: "This month", rows: month), Shelf(title: "Earlier", rows: earlier)]
            .filter { !$0.rows.isEmpty }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    heading
                        .padding(.horizontal, 6)
                        .padding(.top, 18)
                    if let errorText {
                        Text(errorText)
                            .font(.footnote)
                            .foregroundStyle(Theme.ink.opacity(0.7))
                            .padding(.vertical, 14)
                            .padding(.horizontal, 18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .plaque()
                    }
                    ForEach(shelves) { shelf in
                        Text(shelf.title)
                            .font(Theme.label())
                            .tracking(1)
                            .foregroundStyle(Theme.gilt)
                            .padding(.horizontal, 6)
                            .padding(.top, 12)
                        ForEach(shelf.rows) { person in
                            NavigationLink(value: person.id) {
                                VisitorLeaf(person: person)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .navigationDestination(for: String.self) { id in
                VisitorDetailView(person: people.first { $0.id == id })
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .task { await refresh() }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("The guest book")
                .font(Theme.label())
                .tracking(0.8)
                .foregroundStyle(Theme.ink.opacity(0.7))
            Text(summary)
                .font(.system(.title, design: .serif).weight(.semibold))
                .foregroundStyle(Theme.ink)
        }
    }

    private var summary: String {
        guard loaded else { return "Reading the book." }
        if !people.isEmpty {
            let now = Date.now.timeIntervalSince1970
            let month = people.filter { now - Double($0.last) < 31 * 86400 }.count
            switch month {
            case 0: return "No one this month."
            case 1: return "One person this month."
            default: return "\(Self.spelled(month)) people this month."
            }
        }
        return errorText == nil ? "No one has come by." : "The book is out of reach."
    }

    private static func spelled(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .spellOut
        let s = f.string(from: n as NSNumber) ?? "\(n)"
        return s.prefix(1).uppercased() + s.dropFirst()
    }

    private func refresh() async {
        guard let address = Keychain.loadHouseAddress(), !address.isEmpty else {
            errorText = "No house address yet. Add it in Settings."
            loaded = true
            return
        }
        do {
            people = try await HouseClient(baseAddress: address).visitors()
            errorText = nil
        } catch HouseError.noDoor {
            errorText = "The house does not keep the book yet."
        } catch {
            errorText = "The house is not answering. Are you on the tailnet?"
        }
        loaded = true
    }
}

// One person on the wall: where from, on what kind of line, how much they
// read, and when they were last here.
private struct VisitorLeaf: View {
    let person: HouseClient.Visitor

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(person.place)
                        .font(.body)
                        .foregroundStyle(Theme.ink)
                    if person.returning {
                        Text("returning")
                            .font(Theme.label(.caption2))
                            .tracking(0.6)
                            .foregroundStyle(Theme.gilt)
                    }
                }
                Text(line)
                    .font(.footnote)
                    .foregroundStyle(Theme.ink.opacity(0.72))
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            WhenMark(at: person.last)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .plaque()
        .accessibilityIdentifier("visitor")
    }

    private var line: String {
        var bits: [String] = []
        let net = person.network.isEmpty ? "" : person.network
        if !net.isEmpty { bits.append(person.kind.isEmpty ? net : "\(net), \(person.kind)") }
        else if !person.kind.isEmpty { bits.append(person.kind) }
        bits.append(person.visits == 1 ? "one visit" : "\(person.visits) visits")
        bits.append(person.pages == 1 ? "one page" : "\(person.pages) pages")
        bits.append(Told.words(person.seconds))
        if person.masked { bits.append("behind a proxy") }
        return bits.joined(separator: " · ")
    }
}

// A person's visits: each one a leaf with its pages in order and the time
// spent on each, the way a docent would tell it.
private struct VisitorDetailView: View {
    let person: HouseClient.Visitor?
    @State private var detail: HouseClient.Visitor?
    @State private var errorText: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if let p = detail ?? person {
                    header(p)
                    if let visits = detail?.visitList, !visits.isEmpty {
                        Text(visits.count == 1 ? "The visit" : "The visits")
                            .font(Theme.label())
                            .tracking(1)
                            .foregroundStyle(Theme.gilt)
                            .padding(.horizontal, 6)
                            .padding(.top, 12)
                        ForEach(visits) { visit in
                            VisitLeaf(visit: visit)
                        }
                    } else if detail == nil && errorText == nil {
                        ProgressView()
                            .tint(Theme.gilt)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)
                    }
                }
                if let errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundStyle(Theme.ink.opacity(0.7))
                        .padding(.vertical, 14)
                        .padding(.horizontal, 18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .plaque()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) { back }
        .task { await load() }
    }

    @Environment(\.dismiss) private var dismiss

    private var back: some View {
        Button {
            dismiss()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .semibold))
                Text("book")
                    .font(Theme.label(.caption))
                    .tracking(1)
            }
            .foregroundStyle(Theme.gilt)
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back to the guest book")
    }

    private func header(_ p: HouseClient.Visitor) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(p.place)
                .font(.system(.title2, design: .serif).weight(.semibold))
                .foregroundStyle(Theme.ink)
                .padding(.top, 26)
            VStack(alignment: .leading, spacing: 3) {
                if !p.network.isEmpty {
                    Text(p.kind.isEmpty ? p.network : "\(p.network), \(p.kind)")
                }
                if !p.device.isEmpty { Text(p.device) }
                if let languages = p.languages, !languages.isEmpty { Text("Speaks \(languages)") }
                if p.masked, let real = p.realRegion, !real.isEmpty {
                    Text("Behind a proxy; the device's clock says \(real).")
                }
                Text(came(p))
            }
            .font(.footnote)
            .foregroundStyle(Theme.ink.opacity(0.72))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .plaque()
    }

    private func came(_ p: HouseClient.Visitor) -> String {
        let first = Date(timeIntervalSince1970: Double(p.first)).formatted(.dateTime.month(.abbreviated).day())
        let visits = p.visits == 1 ? "once" : "\(p.visits) times"
        let from = p.source == "direct" ? "came straight here" : "came by \(p.source)"
        return "First seen \(first), \(visits), \(Told.words(p.seconds)) in all; \(from)."
    }

    private func load() async {
        guard let person, let address = Keychain.loadHouseAddress(), !address.isEmpty else { return }
        do {
            detail = try await HouseClient(baseAddress: address).visitor(person.id)
        } catch {
            errorText = "The house could not read this visit."
        }
    }
}

// One visit: when, how long, from where; then the journey, one line per
// page with the seconds it held them, and any link they followed out.
private struct VisitLeaf: View {
    let visit: HouseClient.Visit

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(Date(timeIntervalSince1970: Double(visit.at)).formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))
                    .font(.system(.subheadline, design: .serif))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                Text(Told.words(visit.seconds))
                    .font(Theme.label(.caption))
                    .tracking(0.6)
                    .foregroundStyle(Theme.gilt)
            }
            if let line = arrival {
                Text(line)
                    .font(.footnote)
                    .foregroundStyle(Theme.ink.opacity(0.72))
            }
            if !visit.steps.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(visit.steps.enumerated()), id: \.offset) { i, step in
                        if i > 0 {
                            Rectangle().fill(Theme.gilt.opacity(0.22)).frame(height: 0.5)
                        }
                        HStack(alignment: .firstTextBaseline) {
                            Text(step.page == "/" ? "the front page" : step.page)
                                .font(.system(.callout, design: .serif))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            Text(step.seconds > 0 ? Told.words(step.seconds) : "passed through")
                                .font(.caption)
                                .foregroundStyle(Theme.ink.opacity(0.6))
                        }
                        .padding(.vertical, 6)
                    }
                }
                .padding(.top, 2)
            }
            if let links = visit.links, !links.isEmpty {
                ForEach(links, id: \.self) { href in
                    Text("followed \(Self.plain(href))")
                        .font(.system(.caption, design: .serif).italic())
                        .foregroundStyle(Theme.ink.opacity(0.7))
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .plaque()
    }

    private var arrival: String? {
        var bits: [String] = []
        if let source = visit.source, source != "direct" { bits.append("by \(source)") }
        if let device = visit.device, !device.isEmpty { bits.append(device) }
        if let scroll = visit.scroll, scroll > 0 { bits.append("read \(scroll) percent of the way down") }
        return bits.isEmpty ? nil : bits.joined(separator: " · ")
    }

    private static func plain(_ href: String) -> String {
        var s = href
        for prefix in ["https://", "http://", "www."] where s.hasPrefix(prefix) { s = String(s.dropFirst(prefix.count)) }
        while s.hasSuffix("/") { s.removeLast() }
        return s
    }
}

// When someone was last here, lettered like a due mark: the day, saffron
// if today.
private struct WhenMark: View {
    let at: Int

    var body: some View {
        let date = Date(timeIntervalSince1970: Double(at))
        let today = Calendar.current.isDateInToday(date)
        VStack(alignment: .trailing, spacing: 0) {
            Text(today ? "today" : date.formatted(.dateTime.weekday(.abbreviated)))
                .font(Theme.label(.caption))
                .tracking(0.6)
            if !today {
                Text(date.formatted(.dateTime.day().month(.abbreviated)))
                    .font(.system(.footnote, design: .serif))
            }
        }
        .foregroundStyle(today ? Theme.saffron : Theme.gilt)
        .layoutPriority(1)
    }
}

// Seconds said the way a person would.
private enum Told {
    static func words(_ seconds: Int) -> String {
        switch seconds {
        case ..<1: return "a glance"
        case ..<60: return "\(seconds) seconds"
        case ..<3600:
            let m = seconds / 60
            return m == 1 ? "a minute" : "\(m) minutes"
        default:
            let h = seconds / 3600
            let m = (seconds % 3600) / 60
            return (h == 1 ? "an hour" : "\(h) hours") + (m > 0 ? " \(m) min" : "")
        }
    }
}
