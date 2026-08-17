import SwiftUI
import CoreLocation
import MessageUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @AppStorage("timeScale") private var scaleRaw = TimeScale.days.rawValue
    @ObservedObject private var memoryStore = MemoryStore.shared
    @State private var composing = false
    @State private var showingMemories = false
    @State private var showingMailComposer = false
    @State private var opened: OpenedDot?

    /// Randhawa's moments, read once when the app comes forward rather than
    /// again on every dot tapped. Bhullar never writes them, so a snapshot per
    /// foreground is as fresh as the data can be.
    @State private var moments: [Moment] = []

    private var scale: TimeScale { TimeScale(rawValue: scaleRaw) ?? .days }

    var body: some View {
        // Ticks at every minute boundary while visible and catches up on
        // foregrounding, so the grid is always current at every scale; the
        // minute grid visibly fills as you watch.
        TimelineView(.everyMinute) { timeline in
            let position = scale.position(date: timeline.date)
            let onThisDayCount = memoryStore.memories.onThisDayIDs(now: timeline.date).count

            VStack(spacing: 28) {
                DotGrid(
                    position: position,
                    highlighted: memoryHighlights(at: timeline.date),
                    selected: opened?.unit,
                    onSelectUnit: { unit in
                        opened = OpenedDot(unit: unit, scale: scale, reference: timeline.date)
                    },
                    unitName: scale.unitName
                )
                .id(scaleRaw)
                .transition(.opacity)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

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
                    Text("swipe to change scale · tap a dot to open it")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        // Swiping is the zoom now, which leaves the tap free to mean "open
        // this one". A horizontal drag only, so a downward flick still belongs
        // to whatever sheet is on screen.
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    let target = value.translation.width < 0 ? scale.next : scale.previous
                    withAnimation(.easeInOut(duration: 0.2)) {
                        scaleRaw = target.rawValue
                    }
                }
        )
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
        .overlay(alignment: .topTrailing) {
            Button {
                writeToMakers()
            } label: {
                Image(systemName: "envelope")
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
        .sheet(item: $opened) { dot in
            DotDetailSheet(dot: dot, store: memoryStore, moments: moments)
        }
        .sheet(isPresented: $showingMailComposer) {
            MailComposerSheet()
        }
        .onAppear {
            CloudSync.startIfEnabled()
            CloudSync.shared?.fetchNow()
            moments = MomentPersistence.load()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                memoryStore.reloadFromDisk()
                CloudSync.shared?.fetchNow()
                moments = MomentPersistence.load()
            }
        }
        // Randhawa's trail, or a fetch from iCloud, can add dots while Bhullar
        // is on screen. Pick them up when it does.
        .onReceive(NotificationCenter.default.publisher(for: MomentSync.didChangeExternally)) { _ in
            moments = MomentPersistence.load()
        }
    }

    /// The units of the visible scale that hold at least one memory: same
    /// year for the year scales, same day for the day scales.
    ///
    /// Only memories light a dot, never moments. Somewhere you merely were is
    /// not the same as something you chose to keep, and a grid that glowed for
    /// every day you left the house would say nothing at all.
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

    private func writeToMakers() {
        if MFMailComposeViewController.canSendMail() {
            showingMailComposer = true
        } else if let url = URL(string: "mailto:\(LoopMail.address)") {
            openURL(url)
        }
    }
}

/// The dot the user tapped, and everything needed to say what it covers.
struct OpenedDot: Identifiable {
    let unit: Int
    let scale: TimeScale
    /// A date inside the span the grid is currently showing, which fixes which
    /// year (or which day) unit number `unit` belongs to.
    let reference: Date

    var id: String { "\(scale.rawValue)-\(unit)" }

    var interval: DateInterval? {
        scale.interval(ofUnit: unit, containing: reference)
    }

    var title: String {
        scale.label(ofUnit: unit, containing: reference)
    }

    /// Whether this dot is still ahead of the reference date.
    var isFuture: Bool {
        guard let interval else { return false }
        return interval.start > reference
    }
}

/// One stay in one place: consecutive moments close enough together to be the
/// same spot, kept as a span rather than a cluster so returning somewhere later
/// in the day reads as a second visit, in order, the way it happened.
private struct Visit: Identifiable {
    let id = UUID()
    var latitude: Double
    var longitude: Double
    var start: Date
    var end: Date
    var count: Int

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// Groups moments into visits by walking them in time order. A moment joins the
/// current visit while it stays within `radiusMeters` of that visit's running
/// centre, and starts a new one when it does not.
private func visits(in moments: [Moment], radiusMeters: Double = 150) -> [Visit] {
    var result: [Visit] = []
    for moment in moments {
        if var current = result.last,
           MomentGeometry.metersBetween(current.latitude, current.longitude, moment.latitude, moment.longitude) <= radiusMeters {
            let n = Double(current.count)
            current.latitude = (current.latitude * n + moment.latitude) / (n + 1)
            current.longitude = (current.longitude * n + moment.longitude) / (n + 1)
            current.end = Swift.max(current.end, moment.date)
            current.count += 1
            result[result.count - 1] = current
        } else {
            result.append(
                Visit(
                    latitude: moment.latitude,
                    longitude: moment.longitude,
                    start: moment.date,
                    end: moment.date,
                    count: 1
                )
            )
        }
    }
    return result
}

/// What one dot held: where you were, and what you kept. This is the whole
/// point of the pairing. Randhawa gathers the places; Bhullar is where they
/// come back, filed under the hour they happened.
private struct DotDetailSheet: View {
    let dot: OpenedDot
    @ObservedObject var store: MemoryStore
    /// Handed in already loaded, so tapping a dot never touches the disk.
    let moments: [Moment]
    @ObservedObject private var placeNames = PlaceNames.shared
    @Environment(\.dismiss) private var dismiss

    @State private var stays: [Visit] = []
    @State private var memories: [Memory] = []

    var body: some View {
        NavigationStack {
            Group {
                if dot.isFuture {
                    empty("Not yet.", "This one has not happened.")
                } else if stays.isEmpty && memories.isEmpty {
                    empty("Nothing kept.", emptyDetail)
                } else {
                    List {
                        if !stays.isEmpty {
                            Section("Where you were") {
                                ForEach(stays) { stay in
                                    row(for: stay)
                                }
                            }
                        }
                        if !memories.isEmpty {
                            Section("What you kept") {
                                ForEach(memories) { memory in
                                    NavigationLink {
                                        MemoryDetailView(memory: memory, photoURL: store.photoURL(for: memory))
                                    } label: {
                                        MemoryRow(memory: memory, photoURL: store.photoURL(for: memory))
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(dot.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear(perform: load)
    }

    private func row(for stay: Visit) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(placeNames.name(for: stay.coordinate) ?? "Locating…")
                .font(.body)
            Text(timeSpan(of: stay))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 2)
        .onAppear { placeNames.resolve(stay.coordinate) }
    }

    private func timeSpan(of stay: Visit) -> String {
        let start = stay.start.formatted(date: .omitted, time: .shortened)
        // A single dot is an instant, not a stay, and saying "9:12 to 9:12"
        // would be a small lie about how much we know.
        guard stay.end.timeIntervalSince(stay.start) >= 60 else { return start }
        return start + " to " + stay.end.formatted(date: .omitted, time: .shortened)
    }

    private var emptyDetail: String {
        TrailSettings.cadence.isOn
            ? "No places and no memories from this stretch of time."
            : "No memories from this stretch of time. Randhawa, the sibling map app, can fill these in with the places you went."
    }

    private func empty(_ title: String, _ detail: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.title3.weight(.semibold))
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func load() {
        guard let interval = dot.interval else { return }
        stays = visits(in: moments.within(interval))
        memories = store.memories.within(interval)
    }
}

#Preview {
    ContentView()
}
