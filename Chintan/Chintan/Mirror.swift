import SwiftUI

// The mirror: him, never the house (his word, 2026-11-20: the app from the
// ground up, an arm of the portrait and the teachers; the chat he did not
// use gives its page to this). The house reads what it already keeps and
// says it with him as the subject (GET /v1/mirror): one line for Home, what
// waits on his word, the day's lesson and teacher, and his own days, each a
// sentence and a line over the last weeks. Nothing of the house's own upkeep
// is lettered anywhere in it.
extension HouseClient {
    struct Mirror: Codable, Equatable {
        struct Line: Codable, Equatable {
            let kind: String
            let kicker: String
            let text: String
            let more: String
            let id: String?
        }
        struct Yours: Codable, Equatable, Identifiable {
            let kind: String
            let id: String
            let text: String
        }
        struct Lesson: Codable, Equatable {
            let id: String
            let title: String
            let kind: String?
            let teller: String
            let source: String?
            let lesson: String
            let quote: String?
            let video: String?
            var mark: String?
        }
        struct Teacher: Codable, Equatable {
            let key: String
            let name: String
            let years: String?
            let occasion: String?
            let field: String?
            let idea: String
        }
        struct Day: Codable, Equatable, Identifiable {
            let key: String
            let title: String
            let said: String
            let series: [Double?]
            let unit: String?
            var id: String { key }
        }
        let day: String
        var line: Line?
        var yours: [Yours]?
        var lesson: Lesson?
        var teacher: Teacher?
        var days: [Day]?
    }

    func mirror() async throws -> Mirror {
        guard let url = houseURL("/v1/mirror") else { throw HouseError.noAddress }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw HouseError.unreachable }
        if http.statusCode == 404 { throw HouseError.noDoor }
        guard http.statusCode == 200 else { throw HouseError.unreachable }
        return try JSONDecoder().decode(Mirror.self, from: data)
    }

    // His mark on a lesson: knew, new or more.
    func mark(lesson id: String, _ word: String) async -> Bool {
        await post("/v1/mirror/mark", ["id": id, "mark": word])
    }

    // What he opened and for how long, a batch as the app leaves the front.
    func taps(_ batch: [Taps.Tap]) async -> Bool {
        guard let url = houseURL("/v1/taps"), let body = try? JSONEncoder().encode(["taps": batch]) else { return false }
        return await send(url, body)
    }

    private func post(_ path: String, _ fields: [String: String]) async -> Bool {
        guard let url = houseURL(path), let body = try? JSONEncoder().encode(fields) else { return false }
        return await send(url, body)
    }

    private func send(_ url: URL, _ body: Data) async -> Bool {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else { return false }
        return (200..<300).contains(http.statusCode)
    }
}

// The mirror as last read, shared by Home (its line, its mark) and the
// Mirror's own page, and kept on the phone so both open lettered offline.
@MainActor final class MirrorStore: ObservableObject {
    static let shared = MirrorStore()

    @Published private(set) var mirror: HouseClient.Mirror?
    @Published private(set) var word: String?
    private var reading = false
    private var readAt = Date.distantPast

    private static let file: URL = FileManager.default
        .urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("mirror.json")

    private init() {
        if let data = try? Data(contentsOf: Self.file),
           let kept = try? JSONDecoder().decode(HouseClient.Mirror.self, from: data) {
            mirror = kept
        }
    }

    var yours: [HouseClient.Mirror.Yours] { mirror?.yours ?? [] }

    // Read again when asked, never twice inside twenty seconds unless forced.
    func read(force: Bool = false) async {
        guard !reading, force || Date.now.timeIntervalSince(readAt) > 20 else { return }
        guard let address = Keychain.loadHouseAddress(), !address.isEmpty else {
            word = "No house address yet. Add it in Settings."
            return
        }
        reading = true
        defer { reading = false }
        do {
            let fresh = try await HouseClient(baseAddress: address).mirror()
            readAt = .now
            if fresh != mirror { withAnimation(.smooth) { mirror = fresh } }
            word = nil
            if let data = try? JSONEncoder().encode(fresh) { try? data.write(to: Self.file, options: .atomic) }
        } catch HouseError.noDoor {
            word = "The house does not keep the mirror yet."
        } catch {
            word = mirror == nil ? "The house is not answering. Are you on the tailnet?" : nil
        }
    }

    // His mark stands at once; the house hears it behind.
    func mark(_ word: String) {
        guard var m = mirror, var lesson = m.lesson else { return }
        lesson.mark = word
        m.lesson = lesson
        withAnimation(.snappy) { mirror = m }
        let id = lesson.id
        Taps.shared.note("lesson.mark", id: word)
        Task {
            guard let address = Keychain.loadHouseAddress(), !address.isEmpty else { return }
            _ = await HouseClient(baseAddress: address).mark(lesson: id, word)
        }
    }
}

// The tap ledger's hand on the phone: what he opened and for how long, noted
// as it happens and handed to the house as the app leaves the front. Use,
// never content; the house learns by watching, so nothing here asks him to
// rate a thing. A batch the house did not hear waits for the next.
@MainActor final class Taps {
    static let shared = Taps()

    struct Tap: Codable {
        let at: String
        let what: String
        var id: String?
        var secs: Double?
    }

    private var waiting: [Tap] = []
    private var began: [String: (Date, String?)] = [:]
    private static let stamp: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.timeZone = .current
        return f
    }()

    // The house's eyes and the walk leave no taps.
    private static let quiet = ProcessInfo.processInfo.arguments.contains("--house")
        || ProcessInfo.processInfo.arguments.contains("--self-walk")

    func note(_ what: String, id: String? = nil, secs: Double? = nil) {
        guard !Self.quiet else { return }
        waiting.append(Tap(at: Self.stamp.string(from: .now), what: what, id: id, secs: secs.map { ($0 * 10).rounded() / 10 }))
        if waiting.count > 400 { waiting.removeFirst(waiting.count - 400) }
    }

    // A thing with a length: begun here, noted with its seconds when it ends.
    func begin(_ what: String, id: String? = nil) {
        began[what] = (.now, id)
    }

    func end(_ what: String) {
        guard let (at, id) = began.removeValue(forKey: what) else { return }
        note(what, id: id, secs: Date.now.timeIntervalSince(at))
    }

    // Everything still open is closed, and the batch goes.
    func leave() {
        for what in Array(began.keys) { end(what) }
        guard !waiting.isEmpty, let address = Keychain.loadHouseAddress(), !address.isEmpty else { return }
        let batch = waiting
        waiting = []
        Task {
            if await HouseClient(baseAddress: address).taps(batch) == false {
                waiting.insert(contentsOf: batch.suffix(200), at: 0)
            }
        }
    }
}

struct MirrorView: View {
    // The mirror is the page in view; each time it comes, it is read again.
    var shown = true
    @ObservedObject private var store = MirrorStore.shared
    @EnvironmentObject private var gallery: Gallery
    @Environment(\.scenePhase) private var phase
    @Environment(\.openURL) private var openURL
    // The day whose line over time is opened tall.
    @State private var openDay: String?
    @State private var marks = 0
    // Opened on launch with --settings, for the house's screenshots.
    @State private var showingSettings = ProcessInfo.processInfo.arguments.contains("--settings")

    private static let foot = Theme.foot

    private static var eyes: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--open"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    heading
                        .padding(.top, geo.size.height * 0.30)
                        .padding(.horizontal, 6)
                    if let word = store.word {
                        Text(word)
                            .font(.footnote)
                            .foregroundStyle(Theme.ink.opacity(0.7))
                            .padding(.vertical, 14)
                            .padding(.horizontal, 18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .plaque()
                    }
                    if let days = store.mirror?.days, !days.isEmpty {
                        shelf("Your days") {
                            ForEach(days) { day in
                                DayLeaf(day: day, open: openDay == day.key)
                                    .onTapGesture {
                                        withAnimation(.snappy) { openDay = openDay == day.key ? nil : day.key }
                                        if openDay == day.key { Taps.shared.note("day", id: day.key) }
                                    }
                            }
                        }
                    }
                    if let lesson = store.mirror?.lesson {
                        shelf("The lesson") { LessonLeaf(lesson: lesson, mark: mark, talk: talk) }
                            .id("lesson")
                    }
                    if let teacher = store.mirror?.teacher {
                        shelf("The teacher") { TeacherLeaf(teacher: teacher) }
                    }
                }
                .padding(.horizontal, 16)
                // The last leaf clears the fade whole, never cut above the tabs.
                .padding(.bottom, Self.foot + 8)
            }
            .fadedEdges(bottom: Self.foot)
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("mirror")
            // For the house's eyes: `--open lesson` opens on the lesson.
            .task(id: store.mirror?.lesson?.id) {
                guard Self.eyes == "lesson", store.mirror?.lesson != nil else { return }
                try? await Task.sleep(for: .seconds(0.6))
                proxy.scrollTo("lesson", anchor: .top)
            }
            }
        }
        .background { PaintedGround(head: 160) }
        .overlay(alignment: .topTrailing) { gear }
        .refreshable { await store.read(force: true) }
        .task { await store.read() }
        .onChange(of: phase) { _, now in
            if now == .active, shown { Task { await store.read() } }
        }
        .onChange(of: shown) { _, now in
            if now { Task { await store.read() } }
        }
        .sensoryFeedback(.selection, trigger: marks)
        .sheet(isPresented: $showingSettings) {
            // The sheet hangs on the same painting as the tabs.
            SettingsView()
                .environmentObject(gallery)
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("The mirror")
                .font(Theme.label())
                .tracking(0.8)
                .foregroundStyle(Theme.bone.opacity(0.9))
            Text("You, lately.")
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
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("heading")
    }

    // Settings, where the Study kept it: a small mark at the head.
    private var gear: some View {
        Button {
            showingSettings = true
        } label: {
            Image(systemName: "gearshape")
                .font(.body)
                .foregroundStyle(Theme.bone.opacity(0.85))
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial, in: Circle())
                .environment(\.colorScheme, .dark)
        }
        .padding(.trailing, 22)
        .padding(.top, 6)
        .accessibilityLabel("Settings")
    }

    private func shelf<Leaves: View>(_ name: String, @ViewBuilder leaves: () -> Leaves) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(name)
                .font(Theme.label(.caption))
                .tracking(1)
                .foregroundStyle(Theme.giltOnArt)
                // On a mount, so a pale passage of the picture never takes it.
                .mount()
                .padding(.top, 6)
                .accessibilityAddTraits(.isHeader)
            leaves()
        }
    }

    private func mark(_ word: String) {
        store.mark(word)
        marks += 1
    }

    private func talk(_ link: String) {
        if let url = URL(string: link) { openURL(url) }
    }
}

// The day's lesson, whole: its name, whose telling, the lesson in the
// house's words, the teller's own line set apart, and his three marks.
private struct LessonLeaf: View {
    let lesson: HouseClient.Mirror.Lesson
    let mark: (String) -> Void
    let talk: (String) -> Void

    private static let words = [("knew", "Knew it"), ("new", "New to me"), ("more", "More of this")]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(lesson.title.plainDashes)
                    .font(.system(.title3, design: .serif).weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(told)
                    .font(Theme.label(.caption))
                    .tracking(0.6)
                    .foregroundStyle(Theme.gilt)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(lesson.lesson.plainDashes)
                .font(.system(.callout, design: .serif))
                .foregroundStyle(Theme.ink.opacity(0.88))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            if let quote = lesson.quote, !quote.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Rectangle().fill(Theme.gilt.opacity(0.7)).frame(width: 1.5)
                    Text("\u{201C}" + quote.plainDashes + "\u{201D}")
                        .font(.system(.callout, design: .serif).italic())
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            Rectangle().fill(Theme.gilt.opacity(0.22)).frame(height: 0.5)
            HStack(spacing: 8) {
                ForEach(Self.words, id: \.0) { key, name in
                    let on = lesson.mark == key
                    Button {
                        mark(key)
                    } label: {
                        Text(name)
                            .font(Theme.label(.caption))
                            .tracking(0.6)
                            .foregroundStyle(on ? Theme.plaque : Theme.gilt)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background {
                                Capsule().fill(on ? Theme.gilt : Color.clear)
                            }
                            .overlay(Capsule().strokeBorder(Theme.gilt.opacity(0.55), lineWidth: 0.5))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
                Spacer(minLength: 0)
                if let video = lesson.video, !video.isEmpty {
                    Button {
                        talk(video)
                    } label: {
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.gilt)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("The talk it came from")
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .plaque()
        .accessibilityIdentifier("lesson")
    }

    private var told: String {
        var bits = [lesson.teller]
        if let source = lesson.source, !source.isEmpty { bits.append(source.plainDashes) }
        return bits.joined(separator: " · ")
    }
}

// The day's teacher: the name, the years, the one idea.
private struct TeacherLeaf: View {
    let teacher: HouseClient.Mirror.Teacher

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(teacher.name)
                    .font(.system(.title3, design: .serif).weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                if let years = teacher.years, !years.isEmpty {
                    Text(years.plainDashes)
                        .font(Theme.label(.caption))
                        .tracking(0.6)
                        .foregroundStyle(Theme.gilt)
                }
            }
            if let occasion = teacher.occasion, !occasion.isEmpty {
                Text(occasion.prefix(1).uppercased() + occasion.dropFirst() + ".")
                    .font(.system(.footnote, design: .serif).italic())
                    .foregroundStyle(Theme.ink.opacity(0.72))
            }
            Text(teacher.idea.plainDashes)
                .font(.system(.callout, design: .serif))
                .foregroundStyle(Theme.ink.opacity(0.88))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .plaque()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("teacher")
    }
}

// One of his days: its name, the sentence, and the line over the last weeks
// beside it; tapped, the line stands tall with its low and high.
private struct DayLeaf: View {
    let day: HouseClient.Mirror.Day
    let open: Bool

    private var known: [Double] { day.series.compactMap { $0 } }
    private var drawn: Bool { known.count >= 3 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(day.title)
                        .font(Theme.label(.caption))
                        .tracking(0.8)
                        .foregroundStyle(Theme.gilt)
                    Text(day.said.plainDashes)
                        .font(.system(.callout, design: .serif))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if drawn && !open {
                    Spark(series: day.series)
                        .frame(width: 64, height: 26)
                        .padding(.top, 4)
                        .accessibilityHidden(true)
                }
            }
            if drawn && open {
                Spark(series: day.series)
                    .frame(height: 72)
                    .accessibilityHidden(true)
                HStack {
                    Text("low " + Self.said(known.min() ?? 0, day.unit))
                    Spacer()
                    Text("\(day.series.count) days")
                    Spacer()
                    Text("high " + Self.said(known.max() ?? 0, day.unit))
                }
                .font(Theme.label(.caption2))
                .tracking(0.6)
                .foregroundStyle(Theme.ink.opacity(0.6))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .plaque()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("day")
    }

    private static func said(_ value: Double, _ unit: String?) -> String {
        let number = value >= 100 || value == value.rounded()
            ? value.formatted(.number.precision(.fractionLength(0)))
            : value.formatted(.number.precision(.fractionLength(1)))
        guard let unit, !unit.isEmpty, unit != "steps", unit != "words" else { return number }
        return unit == "$" ? "$" + number : number + " " + unit
    }
}

// A line over time, drawn the way a pen would: the known days joined, a gap
// left where a day has no reading, the last one a small gilt point.
private struct Spark: View {
    let series: [Double?]

    var body: some View {
        Canvas { context, size in
            let known = series.compactMap { $0 }
            guard known.count >= 2, let low = known.min(), let high = known.max(), series.count > 1 else { return }
            let span = max(high - low, 0.0001)
            let step = size.width / CGFloat(series.count - 1)
            let inset: CGFloat = 3
            func point(_ i: Int, _ v: Double) -> CGPoint {
                CGPoint(x: CGFloat(i) * step, y: inset + (size.height - inset * 2) * (1 - CGFloat((v - low) / span)))
            }
            var path = Path()
            var last: (Int, CGPoint)?
            for (i, value) in series.enumerated() {
                guard let value else { continue }
                let p = point(i, value)
                // A gap of more than three days lifts the pen.
                if let (j, _) = last, i - j <= 3 { path.addLine(to: p) } else { path.move(to: p) }
                last = (i, p)
            }
            context.stroke(path, with: .color(Theme.gilt.opacity(0.9)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
            if let (_, p) = last {
                context.fill(Path(ellipseIn: CGRect(x: p.x - 2.2, y: p.y - 2.2, width: 4.4, height: 4.4)), with: .color(Theme.gilt))
            }
        }
    }
}

extension MirrorView: Equatable {
    static func == (a: MirrorView, b: MirrorView) -> Bool { a.shown == b.shown }
}
