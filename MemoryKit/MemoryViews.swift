import SwiftUI
import PhotosUI
import UIKit

/// Shared photo handling: memories keep a reasonably sized JPEG, not the
/// original, so the store and iCloud stay light.
enum MemoryPhoto {
    static func processed(_ data: Data, maxDimension: CGFloat = 2048, quality: CGFloat = 0.8) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let largestSide = max(image.size.width, image.size.height)
        guard largestSide > maxDimension else {
            return image.jpegData(compressionQuality: quality)
        }
        let scale = maxDimension / largestSide
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}

/// One sheet for writing a memory down, shared by both apps. The caller
/// decides what the memory is pinned to; this view only collects the words
/// and an optional photo.
struct MemoryComposerView: View {
    let prompt: String
    let contextLine: String
    let onSave: (String, Data?) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool
    @State private var text = ""
    @State private var pickedItem: PhotosPickerItem?
    @State private var photoData: Data?

    private var canSave: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || photoData != nil
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                TextField(prompt, text: $text, axis: .vertical)
                    .lineLimit(4...12)
                    .focused($focused)

                PhotosPicker(selection: $pickedItem, matching: .images) {
                    if let photoData, let image = UIImage(data: photoData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Label("Add a photo", systemImage: "photo")
                            .font(.subheadline)
                    }
                }

                Spacer()

                Text(contextLine)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .padding(20)
            .navigationTitle("New memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(text, photoData)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear { focused = true }
            .onChange(of: pickedItem) { _, item in
                guard let item else { return }
                Task {
                    if let raw = try? await item.loadTransferable(type: Data.self) {
                        photoData = MemoryPhoto.processed(raw)
                    }
                }
            }
        }
    }
}

/// The memory list both apps present: what happened on this date first, then
/// everything, newest first. Also home to the iCloud sync switch, since this
/// is the data it protects.
struct MemoryListSheet: View {
    @ObservedObject var store: MemoryStore
    var onThisDayIDs: Set<UUID> = []

    @Environment(\.dismiss) private var dismiss
    @State private var syncEnabled = CloudSync.isEnabled

    private var onThisDay: [Memory] {
        store.memories.filter { onThisDayIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            List {
                if store.memories.isEmpty {
                    ContentUnavailableView(
                        "No memories yet",
                        systemImage: "sparkles",
                        description: Text("Save a thought or a photo and it will come back here, in its place and in its time.")
                    )
                    .listRowSeparator(.hidden)
                } else {
                    if !onThisDay.isEmpty {
                        Section("On this day") {
                            ForEach(onThisDay) { memory in
                                row(for: memory)
                            }
                        }
                    }
                    Section(onThisDay.isEmpty ? "" : "Everything") {
                        ForEach(store.memories) { memory in
                            row(for: memory)
                        }
                    }
                }

                Section {
                    Toggle("iCloud sync", isOn: $syncEnabled)
                        .tint(.orange)
                } footer: {
                    Text("Keeps your moments and memories in your private iCloud, which we cannot read, and brings them back when you sign in on a new phone.")
                }
            }
            .navigationTitle("Memories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: syncEnabled) { _, enabled in
                CloudSync.setEnabled(enabled)
            }
            .onAppear {
                syncEnabled = CloudSync.isEnabled
            }
        }
    }

    private func row(for memory: Memory) -> some View {
        NavigationLink {
            MemoryDetailView(memory: memory, photoURL: store.photoURL(for: memory))
        } label: {
            MemoryRow(memory: memory, photoURL: store.photoURL(for: memory))
        }
        .swipeActions {
            Button("Delete", role: .destructive) {
                store.delete(memory)
            }
        }
    }
}

struct MemoryRow: View {
    let memory: Memory
    let photoURL: URL?

    private var caption: String {
        var parts = [memory.date.formatted(date: .abbreviated, time: .shortened)]
        if let placeName = memory.placeName, !placeName.isEmpty {
            parts.append(placeName)
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            if let photoURL, let image = UIImage(contentsOfFile: photoURL.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            VStack(alignment: .leading, spacing: 3) {
                if !memory.text.isEmpty {
                    Text(memory.text)
                        .lineLimit(2)
                }
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct MemoryDetailView: View {
    let memory: Memory
    let photoURL: URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let photoURL, let image = UIImage(contentsOfFile: photoURL.path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                if !memory.text.isEmpty {
                    Text(memory.text)
                        .font(.body)
                        .textSelection(.enabled)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(memory.date.formatted(date: .long, time: .shortened))
                    if let placeName = memory.placeName, !placeName.isEmpty {
                        Text(placeName)
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .navigationTitle("Memory")
        .navigationBarTitleDisplayMode(.inline)
    }
}
