import SwiftUI

// A conversation with chintan: his messages on the right, chintan's on the
// left, a composer at the bottom, send on return.
struct StudyView: View {
    @EnvironmentObject var store: ConversationStore
    @State private var draft = ""
    @State private var isThinking = false
    @State private var errorText: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(store.messages) { message in
                            bubble(for: message).id(message.id)
                        }
                        if isThinking {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("chintan is thinking").foregroundStyle(.secondary)
                            }
                            .padding(.leading, 4)
                        }
                    }
                    .padding()
                }
                .onChange(of: store.messages) {
                    if let last = store.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            if let errorText {
                Text(errorText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
            }
            Divider()
            HStack(alignment: .bottom) {
                TextField("Say something", text: $draft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...5)
                    .onSubmit(send)
                Button("Send", action: send)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isThinking)
            }
            .padding()
        }
        .navigationTitle("The study")
    }

    private func bubble(for message: ChintanMessage) -> some View {
        HStack {
            if !message.fromHouse { Spacer(minLength: 40) }
            Text(message.text)
                .padding(10)
                .background(message.fromHouse ? Color.gray.opacity(0.15) : Color.accentColor.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            if message.fromHouse { Spacer(minLength: 40) }
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
