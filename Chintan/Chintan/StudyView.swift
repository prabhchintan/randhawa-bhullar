import SwiftUI

// The study, four rooms over the day's painting: chintan, darban, yaar and
// hawa named at the top the way a gallery names its rooms, the one open in gilt.
// The voice's words on plaques at the left, his own on smoked glass at the
// right, the composer resting on the foot of the picture, send on return.
// Each room keeps its own conversation; a reply finds its room even when
// he has walked into another. hawa's room keeps nothing: it empties when the
// app is put away or the study is left.
struct StudyView: View {
    // Whether the study is the page in view.
    var open = true
    @EnvironmentObject var store: ConversationStore
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.scenePhase) private var phase
    @AppStorage("studyVoice") private var kept = Voice.chintan.rawValue
    @State private var voice: Voice = StudyView.launchVoice ?? .chintan
    @State private var draft = ""
    @State private var thinking: Set<Voice> = []
    @State private var errors: [Voice: String] = [:]
    @State private var lines: [Voice: String] = [:]
    @State private var away: Set<Voice> = []
    @State private var asking: [Voice: Task<Void, Never>] = [:]
    // Opened on launch with --settings, for the house's screenshots.
    @State private var showingSettings = ProcessInfo.processInfo.arguments.contains("--settings")
    @Namespace private var rule

    // The room named on the command line, for the house's screenshots.
    private static var launchVoice: Voice? {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "--open"), i + 1 < args.count { return Voice(rawValue: args[i + 1]) }
        return nil
    }

    // A word said on launch, for the house's screenshots of a room answering.
    private static var launchWord: String? {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "--say"), i + 1 < args.count { return args[i + 1] }
        return nil
    }

    private var messages: [ChintanMessage] { store.messages(voice) }
    private var isThinking: Bool { thinking.contains(voice) }

    // His last word, when nothing came back after it and the house is not
    // thinking on it: it failed, or the app was closed while it waited.
    private var unanswered: ChintanMessage? {
        guard !isThinking, let last = messages.last, !last.fromHouse else { return nil }
        return last
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(messages.enumerated()), id: \.element.id) { i, message in
                            if let when = Self.stamp(message, after: i > 0 ? messages[i - 1] : nil) {
                                stamp(when)
                            }
                            bubble(for: message).id(message.id)
                            if message.id == unanswered?.id {
                                unansweredMark
                            }
                        }
                        if isThinking {
                            Breathing(name: voice.rawValue)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
                .id(voice)
                .defaultScrollAnchor(.bottom)
                // A drag down the conversation puts the keyboard away; the
                // tabs are under it, so it is the only way out unsent.
                .scrollDismissesKeyboard(.interactively)
                .fadedEdges()
                .accessibilityIdentifier("conversation")
                .overlay(alignment: voice.kept ? .bottom : .top) {
                    if messages.isEmpty && !isThinking {
                        quiet
                    }
                }
                .onChange(of: messages) {
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            composer
        }
        .background { PaintedGround(head: 150, foot: 260) }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .onAppear {
            if StudyView.launchVoice == nil, let v = Voice(rawValue: kept) { voice = v }
        }
        .onChange(of: voice) { kept = voice.rawValue }
        .onChange(of: phase) {
            if phase == .active { Voice.allCases.forEach(resume) }
            if phase == .background { letGo() }
        }
        .onChange(of: open) {
            if !open { letGo() }
        }
        .task {
            Voice.allCases.forEach(resume)
            if let word = Self.launchWord {
                draft = word
                send()
            }
            await loadVoices()
        }
    }

    // An empty room says what the voice is for, in its own line from the
    // house; hawa's says, at the head of the room, that it keeps nothing.
    private var quiet: some View {
        VStack(spacing: 12) {
            Rectangle().fill(Theme.giltOnArt).frame(width: 36, height: 0.75)
            Text(voice.kept ? lines[voice].map(Self.sentence) ?? "The room is quiet." : "Said here, gone. The house keeps nothing from this room.")
                .font(.system(.title3, design: .serif).italic())
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.bone)
        }
        .shadow(color: .black.opacity(0.7), radius: 10)
        // A pool of shade under the line, so it reads on the brightest
        // picture, gone to nothing inside its own bounds so it shows no edge.
        .background {
            EllipticalGradient(colors: [.black.opacity(0.5), .clear], center: .center, startRadiusFraction: 0, endRadiusFraction: 0.5)
                .padding(-70)
        }
        .padding(.horizontal, 40)
        .padding(voice.kept ? .bottom : .top, 24)
    }

    private static func sentence(_ line: String) -> String {
        var s = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = s.first else { return s }
        s = first.uppercased() + s.dropFirst()
        if !s.hasSuffix(".") { s += "." }
        return s
    }

    private func loadVoices() async {
        guard let address = Keychain.loadHouseAddress(), !address.isEmpty,
              let found = try? await HouseClient(baseAddress: address).voices() else { return }
        for entry in found.voices {
            guard let v = Voice(rawValue: entry.name) else { continue }
            if let line = entry.line { lines[v] = line }
            if entry.home == false { away.insert(v) } else { away.remove(v) }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 22) {
            // The four names side by side; at the larger text they slide
            // under the thumb instead of running off the phone. Measured only
            // from x large, where four first crowd the gear: ViewThatFits lays
            // the rooms out twice on every turn of a page, a stall to avoid.
            Group {
                if typeSize >= .xLarge {
                    ViewThatFits(in: .horizontal) {
                        rooms
                        ScrollView(.horizontal) { rooms.padding(.vertical, 2) }
                            .scrollIndicators(.hidden)
                    }
                } else {
                    rooms
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 22)
        .padding(.top, 6)
    }

    // The four names share one mount, its edge on the bubbles' edge.
    private var rooms: some View {
        HStack(alignment: .center, spacing: 22) {
            ForEach(Voice.allCases) { v in
                room(v)
            }
        }
        .padding(.top, 3)
        .mount()
        .padding(.leading, -6)
    }

    // A room's name: gilt with a hairline under it when open, bone when not,
    // a saffron mark when the voice is not home.
    private func room(_ v: Voice) -> some View {
        let open = v == voice
        return Button {
            withAnimation(.easeInOut(duration: 0.25)) { voice = v }
        } label: {
            VStack(spacing: 6) {
                Text(v.rawValue)
                    .font(Theme.label(.body))
                    .tracking(1.2)
                    .foregroundStyle(open ? Theme.giltOnArt : Theme.bone.opacity(0.62))
                    .overlay(alignment: .topTrailing) {
                        if away.contains(v) {
                            Circle().fill(Theme.saffron).frame(width: 5, height: 5).offset(x: 7, y: 1)
                        }
                    }
                ZStack {
                    if open {
                        Rectangle().fill(Theme.giltOnArt)
                            .matchedGeometryEffect(id: "rule", in: rule)
                    }
                }
                .frame(height: 0.75)
            }
            .fixedSize()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(v.rawValue)
        .accessibilityAddTraits(open ? .isSelected : [])
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("", text: $draft, prompt: Text("A word for " + voice.rawValue).foregroundStyle(Theme.bone.opacity(0.55)), axis: .vertical)
                .lineLimit(1...5)
                .foregroundStyle(Theme.bone)
                .tint(Theme.giltOnArt)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.giltOnArt.opacity(0.35), lineWidth: 0.5))
                .onSubmit(send)
                .accessibilityIdentifier("composer")
            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(canSend ? Theme.lampBlack : Theme.bone.opacity(0.5))
                    .frame(width: 42, height: 42)
                    .background {
                        if canSend {
                            Circle().fill(Theme.giltOnArt)
                        } else {
                            Circle().fill(.ultraThinMaterial)
                        }
                    }
            }
            .accessibilityLabel("Send")
            .disabled(!canSend)
        }
        .environment(\.colorScheme, .dark)
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isThinking
    }

    @ViewBuilder private func bubble(for message: ChintanMessage) -> some View {
        if message.fromHouse {
            HStack {
                Text(message.text)
                    .foregroundStyle(Theme.ink)
                    .textSelection(.enabled)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .plaque(radius: 16)
                Spacer(minLength: 36)
            }
        } else {
            HStack {
                Spacer(minLength: 56)
                Text(message.text)
                    .foregroundStyle(Theme.bone)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.giltOnArt.opacity(0.4), lineWidth: 0.5))
                    .environment(\.colorScheme, .dark)
            }
        }
    }

    // The hour over a run of the conversation: over the first word, and
    // wherever an hour has passed or the day has turned since the last.
    static func stamp(_ message: ChintanMessage, after previous: ChintanMessage?) -> String? {
        let calendar = Calendar.current
        if let previous, message.date.timeIntervalSince(previous.date) < 3600,
           calendar.isDate(message.date, inSameDayAs: previous.date) { return nil }
        let hour = message.date.formatted(date: .omitted, time: .shortened)
        if calendar.isDateInToday(message.date) { return "Today " + hour }
        if calendar.isDateInYesterday(message.date) { return "Yesterday " + hour }
        if let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: message.date), to: calendar.startOfDay(for: .now)).day,
           days < 7 {
            return message.date.formatted(.dateTime.weekday(.wide)) + " " + hour
        }
        return message.date.formatted(.dateTime.month(.abbreviated).day()) + " " + hour
    }

    private func stamp(_ when: String) -> some View {
        Text(when)
            .font(Theme.label(.caption))
            .tracking(1.1)
            .foregroundStyle(Theme.giltOnArt)
            .mount()
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
    }

    // Under a word that went unanswered: what happened, and the way to send
    // it again, on a mount so it reads on any passage of the picture.
    // At the accessibility sizes the button stands under the words, whole.
    private var unansweredMark: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .trailing, spacing: 10))
            : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            Text(errors[voice] ?? "The house did not answer.")
                .font(.system(.footnote, design: .serif).italic())
                .foregroundStyle(Theme.bone.opacity(0.9))
                .multilineTextAlignment(.trailing)
            Button(action: retry) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption.weight(.semibold))
                    Text("Try again")
                        .font(Theme.label(.footnote))
                        .tracking(1.1)
                }
                .fixedSize()
                .foregroundStyle(Theme.giltOnArt)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).strokeBorder(Theme.giltOnArt.opacity(0.7), lineWidth: 0.75))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("retry")
        }
        .mount()
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        let word = ChintanMessage(id: UUID(), text: text, fromHouse: false, date: Date())
        store.append(word, to: voice)
        ask(word, in: voice)
    }

    // The unanswered word sent once more, where it already stands.
    private func retry() {
        guard let word = unanswered else { return }
        ask(word, in: voice)
    }

    // The word goes with an id kept on the device until its reply lands, so
    // a wait cut short (the app put away, the line dropped) is taken up again.
    private func ask(_ word: ChintanMessage, in room: Voice) {
        errors[room] = nil
        guard let address = Keychain.loadHouseAddress(), !address.isEmpty else {
            errors[room] = "No house address yet. Add it in Settings."
            return
        }
        let id = UUID().uuidString
        store.wait(.init(id: id, word: word.id, since: .now), in: room)
        thinking.insert(room)
        asking[room] = Task {
            do {
                let reply = try await HouseClient(baseAddress: address).say(word.text, to: room.rawValue, id: id) { houseID in
                    if store.waiting[room]?.word == word.id {
                        store.wait(.init(id: houseID, word: word.id, since: .now), in: room)
                    }
                }
                land(reply, answering: word.id, in: room)
                thinking.remove(room)
            } catch {
                if Task.isCancelled { return }
                thinking.remove(room)
                resume(room)
            }
        }
    }

    // A word still waiting when the study opens or the app comes back: ask
    // the house for its reply. A house that does not know the word lets it
    // go, and it reads as unanswered.
    private func resume(_ room: Voice) {
        guard !thinking.contains(room), let w = store.waiting[room] else { return }
        guard let last = store.messages(room).last, last.id == w.word else {
            store.wait(nil, in: room)
            return
        }
        guard let address = Keychain.loadHouseAddress(), !address.isEmpty else { return }
        errors[room] = nil
        thinking.insert(room)
        asking[room] = Task {
            do {
                land(try await HouseClient(baseAddress: address).awaitReply(id: w.id), answering: w.word, in: room)
            } catch HouseError.noDoor {
                store.wait(nil, in: room)
            } catch {
                if Task.isCancelled { return }
                errors[room] = "The house is not answering. Are you on the tailnet?"
            }
            thinking.remove(room)
        }
    }

    // A reply lands only while its word still waits; a room let go takes none.
    private func land(_ reply: String, answering word: UUID, in room: Voice) {
        guard store.waiting[room]?.word == word else { return }
        store.append(ChintanMessage(id: UUID(), text: reply, fromHouse: true, date: Date()), to: room)
        store.wait(nil, in: room)
    }

    // The rooms that keep nothing, let go: the wait cut, the words gone, and
    // an unsent word in them with it.
    private func letGo() {
        for v in Voice.allCases where !v.kept {
            asking[v]?.cancel()
            asking[v] = nil
            thinking.remove(v)
            errors[v] = nil
            store.forget(v)
        }
        if !voice.kept { draft = "" }
    }
}

// The thinking state: the voice named in italic beside a gilt mark that
// breathes, slowly, while the house works.
private struct Breathing: View {
    let name: String
    @State private var full = false

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Theme.giltOnArt)
                .frame(width: 7, height: 7)
                .scaleEffect(full ? 1.0 : 0.6)
                .opacity(full ? 1.0 : 0.35)
            Text("\(name) is thinking")
                .font(.system(.subheadline, design: .serif).italic())
                .foregroundStyle(Theme.bone)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .environment(\.colorScheme, .dark)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { full = true }
        }
    }
}
