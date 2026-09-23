import SwiftUI

// The study, three rooms over the day's painting: chintan, darban and yaar
// named at the top the way a gallery names its rooms, the one open in gilt.
// The voice's words on plaques at the left, his own on smoked glass at the
// right, the composer resting on the foot of the picture, send on return.
// Each room keeps its own conversation; a reply finds its room even when
// he has walked into another.
struct StudyView: View {
    @EnvironmentObject var store: ConversationStore
    @AppStorage("studyVoice") private var kept = Voice.chintan.rawValue
    @State private var voice: Voice = StudyView.launchVoice ?? .chintan
    @State private var draft = ""
    @State private var thinking: Set<Voice> = []
    @State private var errors: [Voice: String] = [:]
    @State private var lines: [Voice: String] = [:]
    @State private var away: Set<Voice> = []
    @State private var showingSettings = false
    @Namespace private var rule

    // The room named on the command line, for the house's screenshots.
    private static var launchVoice: Voice? {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "--open"), i + 1 < args.count { return Voice(rawValue: args[i + 1]) }
        return nil
    }

    private var messages: [ChintanMessage] { store.messages(voice) }
    private var isThinking: Bool { thinking.contains(voice) }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { message in
                            bubble(for: message).id(message.id)
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
                .fadedEdges()
                .overlay(alignment: .bottom) {
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
            if let errorText = errors[voice] {
                Label(errorText, systemImage: "wifi.slash")
                    .font(.footnote)
                    .foregroundStyle(Theme.bone.opacity(0.85))
                    .padding(.horizontal)
                    .padding(.bottom, 6)
            }
            composer
        }
        .background { PaintedGround(head: 150, foot: 260) }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .onAppear {
            if StudyView.launchVoice == nil, let v = Voice(rawValue: kept) { voice = v }
        }
        .onChange(of: voice) { kept = voice.rawValue }
        .task { await loadVoices() }
    }

    // An empty room says what the voice is for, in its own line from the house.
    private var quiet: some View {
        VStack(spacing: 12) {
            Rectangle().fill(Theme.giltOnArt).frame(width: 36, height: 0.75)
            Text(lines[voice].map(Self.sentence) ?? "The room is quiet.")
                .font(.system(.title3, design: .serif).italic())
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.bone.opacity(0.9))
        }
        .shadow(color: .black.opacity(0.7), radius: 10)
        .padding(.horizontal, 40)
        .padding(.bottom, 24)
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
            ForEach(Voice.allCases) { v in
                room(v)
            }
            Spacer()
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
        .shadow(color: .black.opacity(0.5), radius: 6)
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

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let room = voice
        draft = ""
        errors[room] = nil
        store.append(ChintanMessage(id: UUID(), text: text, fromHouse: false, date: Date()), to: room)
        guard let address = Keychain.loadHouseAddress(), !address.isEmpty else {
            errors[room] = "No house address yet. Add it in Settings."
            return
        }
        thinking.insert(room)
        Task {
            do {
                let reply = try await HouseClient(baseAddress: address).say(text, to: room.rawValue)
                store.append(ChintanMessage(id: UUID(), text: reply, fromHouse: true, date: Date()), to: room)
            } catch {
                errors[room] = "The house is not answering. Are you on the tailnet?"
            }
            thinking.remove(room)
        }
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
