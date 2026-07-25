import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("timeScale") private var scaleRaw = TimeScale.days.rawValue
    @ObservedObject private var memoryStore = MemoryStore.shared
    @State private var composing = false
    @State private var showingMemories = false

    private var scale: TimeScale { TimeScale(rawValue: scaleRaw) ?? .days }

    var body: some View {
        // Ticks at every minute boundary while visible and catches up on
        // foregrounding, so the grid is always current at every scale; the
        // minute grid visibly fills as you watch.
        TimelineView(.everyMinute) { timeline in
            let position = scale.position(date: timeline.date)
            let onThisDayCount = memoryStore.memories.onThisDayIDs(now: timeline.date).count

            VStack(spacing: 28) {
                DotGrid(position: position, highlighted: memoryHighlights(at: timeline.date))
                    .id(scaleRaw)
                    .transition(.opacity)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            scaleRaw = scale.next.rawValue
                        }
                    }

                VStack(spacing: 6) {
                    Text("\(position.percent)%")
                        .font(.system(size: 48, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text("\(scale.unitName) \(position.index) of \(position.total) · \(position.remaining) left")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if !memoryStore.memories.isEmpty {
                        Button {
                            showingMemories = true
                        } label: {
                            Text(memoriesLabel(onThisDay: onThisDayCount))
                                .font(.caption)
                                .foregroundStyle(onThisDayCount > 0 ? AnyShapeStyle(.orange) : AnyShapeStyle(.tertiary))
                        }
                        .buttonStyle(.plain)
                    }
                    Text("tap the dots to zoom")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .overlay(alignment: .bottomTrailing) {
            Button {
                composing = true
            } label: {
                Image(systemName: "plus")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .frame(width: 38, height: 38)
                    .background(.thinMaterial, in: Circle())
            }
            .padding(20)
        }
        .sheet(isPresented: $composing) {
            MemoryComposerView(
                prompt: "What is worth remembering right now?",
                contextLine: "Pinned to this moment. If you also use Randhawa, memories made there carry their place.",
                onSave: { text, photoData in
                    memoryStore.add(text: text, photoData: photoData)
                }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingMemories) {
            MemoryListSheet(
                store: memoryStore,
                onThisDayIDs: memoryStore.memories.onThisDayIDs()
            )
        }
        .onAppear {
            CloudSync.startIfEnabled()
            CloudSync.shared?.fetchNow()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                memoryStore.reloadFromDisk()
                CloudSync.shared?.fetchNow()
            }
        }
    }

    /// The units of the visible scale that hold at least one memory: same
    /// year for the year scales, same day for the day scales.
    private func memoryHighlights(at date: Date) -> Set<Int> {
        let calendar = Calendar.current
        var indices: Set<Int> = []
        for memory in memoryStore.memories {
            switch scale {
            case .months, .weeks, .days:
                guard calendar.isDate(memory.date, equalTo: date, toGranularity: .year) else { continue }
            case .hours, .minutes:
                guard calendar.isDate(memory.date, inSameDayAs: date) else { continue }
            }
            indices.insert(scale.position(date: memory.date, calendar: calendar).index)
        }
        return indices
    }

    private func memoriesLabel(onThisDay: Int) -> String {
        if onThisDay > 0 {
            return onThisDay == 1 ? "1 memory on this day" : "\(onThisDay) memories on this day"
        }
        let total = memoryStore.memories.count
        return total == 1 ? "1 memory" : "\(total) memories"
    }
}

#Preview {
    ContentView()
}
