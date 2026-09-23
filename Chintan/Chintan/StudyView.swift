import SwiftUI

// A conversation with chintan over the day's painting: chintan's words on
// plaques at the left, his own on smoked glass at the right, the composer
// resting on the foot of the picture, send on return.
struct StudyView: View {
    @EnvironmentObject var store: ConversationStore
    @State private var draft = ""
    @State private var isThinking = false
    @State private var errorText: String?
    @State private var showingSettings = false

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(store.messages) { message in
                            bubble(for: message).id(message.id)
                        }
                        if isThinking {
                            HStack(spacing: 8) {
                                ProgressView().tint(Theme.bone)
                                Text("chintan is thinking")
                                    .font(.system(.subheadline, design: .serif).italic())
                                    .foregroundStyle(Theme.bone)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                            .environment(\.colorScheme, .dark)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
                .defaultScrollAnchor(.bottom)
                .fadedEdges()
                .overlay(alignment: .bottom) {
                    if store.messages.isEmpty && !isThinking {
                        Text("The study is quiet.")
                            .font(.system(.title3, design: .serif).italic())
                            .foregroundStyle(Theme.bone.opacity(0.85))
                            .shadow(color: .black.opacity(0.6), radius: 8)
                            .padding(.bottom, 20)
                    }
                }
                .onChange(of: store.messages) {
                    if let last = store.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            if let errorText {
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
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("The study")
                .font(Theme.label())
                .tracking(0.8)
                .foregroundStyle(Theme.bone.opacity(0.85))
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

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("", text: $draft, prompt: Text("Say something").foregroundStyle(Theme.bone.opacity(0.55)), axis: .vertical)
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
        draft = ""
        errorText = nil
        store.append(ChintanMessage(id: UUID(), text: text, fromHouse: false, date: Date()))
        guard let address = Keychain.loadHouseAddress(), !address.isEmpty else {
            errorText = "No house address yet. Add it in Settings."
            return
        }
        isThinking = true
        Task {
            do {
                let reply = try await HouseClient(baseAddress: address).say(text)
                store.append(ChintanMessage(id: UUID(), text: reply, fromHouse: true, date: Date()))
            } catch {
                errorText = "The house is not answering. Are you on the tailnet?"
            }
            isThinking = false
        }
    }
}
