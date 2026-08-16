import SwiftUI
import MapKit
import UIKit
import CoreLocation

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var model = SpaceModel()
    @ObservedObject private var memoryStore = MemoryStore.shared
    @ObservedObject private var trail = LocationTrail.shared
    /// How much of the basemap is hidden under the ink, 0 to 1. One is the
    /// constellation.
    @AppStorage("veil") private var veil = 0.0
    /// The pre-3.2 toggle, honoured once so nobody's constellation turns back
    /// into a map on update.
    @AppStorage("showMap") private var legacyShowMap = true
    @State private var confirmingErase = false
    @State private var composing: ComposerTarget?
    @State private var showingMemories = false
    @State private var showingTrail = false
    @State private var offeringSync = false
    @State private var offeringTrail = false
    @State private var openedMemory: Memory?
    @State private var openedPlace: MomentGeometry.Clump?
    @State private var exportItem: ShareItem?
    @State private var fitRequest = 0

    var body: some View {
        Group {
            switch model.permission {
            case .undetermined:
                IntroView(begin: model.requestPermission)
            case .denied:
                if model.moments.isEmpty {
                    DeniedView()
                } else {
                    spaceView
                }
            case .granted:
                spaceView
            }
        }
        // Sample once per open: onAppear covers the launch (scenePhase may
        // already be .active before this view exists), onChange covers every
        // return from the background. SpaceModel's interval guard dedupes.
        .onAppear {
            if !legacyShowMap {
                veil = 1
                legacyShowMap = true
            }
            CloudSync.startIfEnabled()
            model.sampleIfAuthorized()
            CloudSync.shared?.fetchNow()
            refreshOffers()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.sampleIfAuthorized()
                memoryStore.reloadFromDisk()
                CloudSync.shared?.fetchNow()
                refreshOffers()
            }
        }
        .onChange(of: trail.authorizationStatus) { _, _ in
            refreshOffers()
        }
    }

    private var spaceView: some View {
        ZStack {
            InkMapView(
                moments: model.moments,
                memories: memoryStore.memories,
                veil: veil,
                dark: colorScheme == .dark,
                fitRequest: fitRequest,
                onTapMemory: { openedMemory = $0 },
                onTapPlace: { openedPlace = $0 }
            )
            .ignoresSafeArea()

            VStack {
                HStack(alignment: .top) {
                    Menu {
                        Button {
                            showingMemories = true
                        } label: {
                            Label("Memories", systemImage: "sparkles")
                        }
                        Button {
                            showingTrail = true
                        } label: {
                            Label(trailMenuTitle, systemImage: "figure.walk")
                        }
                        Button {
                            fitRequest += 1
                        } label: {
                            Label("Show everything", systemImage: "arrow.up.left.and.arrow.down.right")
                        }
                        Button {
                            exportMap()
                        } label: {
                            Label("Export your map", systemImage: "square.and.arrow.up")
                        }
                        Divider()
                        Button("Erase everything", role: .destructive) {
                            confirmingErase = true
                        }
                    } label: {
                        ControlIcon(systemName: "ellipsis")
                    }
                    Spacer()
                    VeilControl(veil: $veil)
                }
                Spacer()
                if offeringTrail {
                    TrailOfferCard(
                        turnOn: {
                            TrailSettings.offerAnswered = true
                            LocationTrail.shared.setCadence(.standard)
                            offeringTrail = false
                        },
                        notNow: {
                            TrailSettings.offerAnswered = true
                            LocationTrail.shared.setCadence(.off)
                            offeringTrail = false
                        }
                    )
                    .padding(.bottom, 8)
                } else if offeringSync {
                    SyncOfferCard(
                        turnOn: {
                            CloudSync.setEnabled(true)
                            offeringSync = false
                        },
                        notNow: {
                            CloudSync.declineOffer()
                            offeringSync = false
                        }
                    )
                    .padding(.bottom, 8)
                }
                Text(caption)
                    .font(.subheadline)
                    .monospacedDigit()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.thinMaterial, in: Capsule())
            }
            .padding(20)
            // Once the veil is mostly drawn the map is black whatever the
            // system says, so the controls dress for the dark.
            .environment(\.colorScheme, veil > 0.5 ? .dark : colorScheme)
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                composing = ComposerTarget(here: model.moments.last)
            } label: {
                ControlIcon(systemName: "plus")
            }
            .padding(20)
            .environment(\.colorScheme, veil > 0.5 ? .dark : colorScheme)
        }
        .sheet(item: $composing) { target in
            MemoryComposerView(
                prompt: target.prompt,
                contextLine: target.contextLine,
                onSave: { text, photoData in
                    saveMemory(text: text, photoData: photoData, at: target)
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
        .sheet(isPresented: $showingTrail) {
            TrailSheet(model: model)
        }
        .sheet(item: $openedMemory) { memory in
            NavigationStack {
                MemoryDetailView(memory: memory, photoURL: memoryStore.photoURL(for: memory))
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { openedMemory = nil }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $openedPlace) { clump in
            PlaceSheet(
                clump: clump,
                moments: model.moments,
                memories: memoryStore.memories,
                photoURL: memoryStore.photoURL(for:),
                onRemember: { name in
                    openedPlace = nil
                    composing = ComposerTarget(
                        latitude: clump.latitude,
                        longitude: clump.longitude,
                        placeName: name,
                        isHere: false
                    )
                }
            )
        }
        .sheet(item: $exportItem) { item in
            ShareSheet(items: [item.url])
                .presentationDetents([.medium, .large])
        }
        .confirmationDialog(
            "Erase your map and memories?",
            isPresented: $confirmingErase,
            titleVisibility: .visible
        ) {
            Button("Erase everything", role: .destructive) {
                CloudSync.shared?.eraseEverything()
                model.eraseAll()
                memoryStore.eraseAll()
            }
        } message: {
            Text(eraseMessage)
        }
    }

    private var caption: String {
        let momentCount = model.moments.count
        if momentCount == 0 {
            return "Placing your first dot…"
        }
        let placeCount = model.placeCount
        let momentWord = momentCount == 1 ? "moment" : "moments"
        let placeWord = placeCount == 1 ? "place" : "places"
        return "\(momentCount) \(momentWord) · \(placeCount) \(placeWord)"
    }

    private var trailMenuTitle: String {
        trail.cadence.isOn && trail.isAlwaysAuthorized ? "Trail: on" : "Trail: off"
    }

    private var eraseMessage: String {
        var message = CloudSync.isEnabled
            ? "Every moment and memory is deleted from this device and from your iCloud. This cannot be undone."
            : "Every moment and memory is deleted from this device. There is no copy anywhere else, so this cannot be undone."
        // Erasing does not answer the trail question, so say so rather than
        // let a fresh dot appear a mile down the road and look like a bug.
        if trail.cadence.isOn && trail.isAlwaysAuthorized {
            message += " The trail stays on, so it will begin a new map from wherever you go next. Turn it off first if you would rather it did not."
        }
        return message
    }

    /// Two one-time cards, never both. The trail card goes to people who
    /// granted While Using before 3.2 and have not yet been told the map can
    /// draw itself; the sync card waits its turn behind it.
    private func refreshOffers() {
        let trailUnanswered = model.permission == .granted
            && !trail.isAlwaysAuthorized
            && trail.cadence.isOn
            && !TrailSettings.offerAnswered
        offeringTrail = trailUnanswered
        offeringSync = !trailUnanswered && !CloudSync.isDecided && model.moments.count >= 2
    }

    private func exportMap() {
        if let url = try? MapExport.write() {
            exportItem = ShareItem(url: url)
        }
    }

    private func saveMemory(text: String, photoData: Data?, at target: ComposerTarget) {
        let memory = memoryStore.add(
            text: text,
            latitude: target.latitude,
            longitude: target.longitude,
            placeName: target.placeName,
            photoData: photoData
        )
        guard target.placeName == nil, let latitude = target.latitude, let longitude = target.longitude else { return }
        // Name the place while it is fresh; the name syncs along with the memory.
        PlaceNames.shared.lookup(CLLocationCoordinate2D(latitude: latitude, longitude: longitude)) { name in
            guard let name else { return }
            MemoryStore.shared.setPlaceName(name, for: memory.id)
        }
    }
}

/// What a new memory is pinned to: here and now (the plus button), or a place
/// the user opened on the map.
struct ComposerTarget: Identifiable {
    let id = UUID()
    let latitude: Double?
    let longitude: Double?
    let placeName: String?
    let isHere: Bool

    init(latitude: Double?, longitude: Double?, placeName: String?, isHere: Bool) {
        self.latitude = latitude
        self.longitude = longitude
        self.placeName = placeName
        self.isHere = isHere
    }

    init(here: Moment?) {
        self.init(latitude: here?.latitude, longitude: here?.longitude, placeName: nil, isHere: true)
    }

    var prompt: String {
        isHere ? "What is worth remembering here?" : "What is worth remembering about this place?"
    }

    var contextLine: String {
        if !isHere {
            if let placeName {
                return "Pinned to \(placeName), and to this moment."
            }
            return "Pinned to this place, and to this moment."
        }
        return latitude == nil ? "Pinned to this moment." : "Pinned to this place and this moment."
    }
}

/// The sparkles button. Tap: map or constellation. Press and slide up or
/// down: anywhere in between, the basemap fading under the ink. The slider
/// only shows itself while a finger is on it.
private struct VeilControl: View {
    @Binding var veil: Double
    @State private var dragging = false
    @State private var startVeil = 0.0
    @State private var moved = false

    var body: some View {
        VStack(spacing: 8) {
            ControlIcon(systemName: veil < 0.5 ? "sparkles" : "map")
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !dragging {
                                dragging = true
                                moved = false
                                startVeil = veil
                            }
                            if abs(value.translation.height) > 6 {
                                moved = true
                            }
                            if moved {
                                // Down is more veil: the finger draws the curtain.
                                let next = startVeil + Double(value.translation.height) / 140
                                veil = Swift.min(Swift.max(next, 0), 1)
                            }
                        }
                        .onEnded { _ in
                            if !moved {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    veil = veil < 0.5 ? 1 : 0
                                }
                            }
                            dragging = false
                        }
                )
            if dragging && moved {
                Capsule()
                    .fill(.thinMaterial)
                    .frame(width: 6, height: 90)
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(.orange)
                            .frame(width: 6, height: 90 * veil)
                    }
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: dragging && moved)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Map veil")
        .accessibilityValue(veil < 0.5 ? "Map" : "Constellation")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: veil = Swift.min(veil + 0.25, 1)
            case .decrement: veil = Swift.max(veil - 0.25, 0)
            @unknown default: break
            }
        }
    }
}

/// One place, opened from the map: what it is called, how often you were
/// there, what you kept there, and a way to keep something more.
private struct PlaceSheet: View {
    let clump: MomentGeometry.Clump
    let moments: [Moment]
    let memories: [Memory]
    let photoURL: (Memory) -> URL?
    let onRemember: (String?) -> Void

    @ObservedObject private var placeNames = PlaceNames.shared
    @Environment(\.dismiss) private var dismiss

    private var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: clump.latitude, longitude: clump.longitude)
    }

    /// Moments within the clump's neighbourhood; the clump itself only knows
    /// its count, and the sheet wants dates.
    private var nearby: [Moment] {
        moments.filter {
            MomentGeometry.metersBetween($0.latitude, $0.longitude, clump.latitude, clump.longitude) <= 60
        }
    }

    private var memoriesHere: [Memory] {
        memories.filter { memory in
            guard let latitude = memory.latitude, let longitude = memory.longitude else { return false }
            return MomentGeometry.metersBetween(latitude, longitude, clump.latitude, clump.longitude) <= 150
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(summary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button {
                        onRemember(placeNames.name(for: coordinate))
                    } label: {
                        Label("Remember something here", systemImage: "plus")
                    }
                }
                if !memoriesHere.isEmpty {
                    Section("Kept here") {
                        ForEach(memoriesHere) { memory in
                            NavigationLink {
                                MemoryDetailView(memory: memory, photoURL: photoURL(memory))
                            } label: {
                                MemoryRow(memory: memory, photoURL: photoURL(memory))
                            }
                        }
                    }
                }
            }
            .navigationTitle(placeNames.name(for: coordinate) ?? "This place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear { placeNames.resolve(coordinate) }
    }

    private var summary: String {
        let here = nearby
        let count = here.count
        guard count > 0, let first = here.first?.date, let last = here.last?.date else {
            return "A place on your map."
        }
        let calendar = Calendar.current
        let days = Set(here.map { calendar.startOfDay(for: $0.date) }).count
        let momentWord = count == 1 ? "moment" : "moments"
        let dayWord = days == 1 ? "day" : "days"
        if count == 1 {
            return "One moment here, \(first.formatted(date: .abbreviated, time: .shortened))."
        }
        var line = "\(count) \(momentWord) on \(days) \(dayWord). First \(first.formatted(date: .abbreviated, time: .omitted))"
        line += calendar.isDate(first, inSameDayAs: last)
            ? "."
            : ", last \(last.formatted(date: .abbreviated, time: .omitted))."
        return line
    }
}

/// The trail settings: the one screen in either app that talks about
/// something bigger than a tap. It says plainly what the trail does, what iOS
/// will actually honour, and how to take it all back.
private struct TrailSheet: View {
    @ObservedObject var model: SpaceModel
    @ObservedObject private var trail = LocationTrail.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var confirmingForget = false

    private var cadence: TrailCadence { trail.cadence }

    /// True whenever the trail is on but iOS has not granted Always, whether
    /// the user declined the prompt or revoked it later in Settings.
    private var needsAlways: Bool { !trail.isAlwaysAuthorized }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(TrailCadence.offered(including: cadence)) { option in
                        Button {
                            choose(option)
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(option.title)
                                        .foregroundStyle(.primary)
                                    Text(option.detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                if option == cadence {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("How the map is made")
                } footer: {
                    Text("iOS wakes a sleeping app when you move, not on a clock, so a dot lands only once you have actually gone somewhere, and never more often than this. Stay in one place and the trail stays quiet. It never runs continuously and never keeps your phone awake.")
                }

                if cadence.isOn && needsAlways {
                    Section {
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                openURL(url)
                            }
                        }
                    } footer: {
                        Text("The trail needs Location set to Always. Without it Randhawa is never woken, so dots only arrive when you open the app.")
                    }
                }

                Section("What it has gathered") {
                    // The count is a row rather than a footer so the section
                    // never renders as a header and footer with a hole in it.
                    Text(gatheredFooter)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if model.trailCount > 0 {
                        Button("Forget the trail", role: .destructive) {
                            confirmingForget = true
                        }
                    }
                }
            }
            .navigationTitle("The trail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Forget every dot the trail placed?",
                isPresented: $confirmingForget,
                titleVisibility: .visible
            ) {
                Button("Forget the trail", role: .destructive) {
                    model.eraseTrailDots()
                }
            } message: {
                Text("The dots you placed by opening Randhawa stay. The rest are deleted from this device, and from your iCloud if sync is on.")
            }
        }
        .presentationDetents([.large])
    }

    private var gatheredFooter: String {
        let trailDots = model.trailCount
        let opened = model.moments.count - trailDots
        let openedWord = opened == 1 ? "dot" : "dots"
        if trailDots == 0 {
            if cadence.isOn && !needsAlways {
                return "\(opened) \(openedWord) so far, every one of them from opening the app. The trail adds its first once you have gone somewhere."
            }
            return "\(opened) \(openedWord) so far, every one of them from opening the app."
        }
        let trailWord = trailDots == 1 ? "dot" : "dots"
        var line = "\(trailDots) \(trailWord) from the trail, \(opened) \(openedWord) from opening the app."
        // Saying when the last one landed is the only honest way to show the
        // trail is alive: there is nothing to watch, by design.
        if let last = model.lastTrailDate {
            let elapsed = Date().timeIntervalSince(last)
            line += elapsed < 120
                ? " The last one just now."
                : " The last one \(last.formatted(.relative(presentation: .named)))."
        }
        return line
    }

    private func choose(_ option: TrailCadence) {
        TrailSettings.offerAnswered = true
        LocationTrail.shared.setCadence(option)
    }
}

/// Circular material button face shared by the overlay controls.
private struct ControlIcon: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.body.weight(.medium))
            .foregroundStyle(.primary)
            .frame(width: 38, height: 38)
            .background(.thinMaterial, in: Circle())
    }
}

/// A card in the app's own voice, for the two things it asks once.
private struct OfferCard: View {
    let title: String
    let detail: String
    let accept: String
    let turnOn: () -> Void
    let notNow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Button(accept, action: turnOn)
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                Button("Not Now", action: notNow)
                    .buttonStyle(.bordered)
            }
            .font(.subheadline)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

/// The one-time iCloud pitch: what it does, in the app's own voice.
private struct SyncOfferCard: View {
    let turnOn: () -> Void
    let notNow: () -> Void

    var body: some View {
        OfferCard(
            title: "Keep your map, even on your next phone",
            detail: "iCloud sync keeps your moments and memories in your private iCloud, which we cannot read. Sign in on a new phone and your map comes back.",
            accept: "Turn On",
            turnOn: turnOn,
            notNow: notNow
        )
    }
}

/// For people who granted While Using before 3.2: the map can draw itself
/// now, and iOS will ask them whether that is all right.
private struct TrailOfferCard: View {
    let turnOn: () -> Void
    let notNow: () -> Void

    var body: some View {
        OfferCard(
            title: "Your map can draw itself now",
            detail: "Randhawa can mark a dot each time your phone notices you have gone somewhere, and draw the line between. It uses only the low-power signals iOS gives a sleeping app, and everything still stays with you. iOS will ask you to allow it.",
            accept: "Turn On",
            turnOn: turnOn,
            notNow: notNow
        )
    }
}

/// First launch: say what the app does and what it will never do, then ask.
private struct IntroView: View {
    let begin: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Randhawa")
                .font(.system(size: 40, weight: .semibold, design: .rounded))
            Text("Carry your phone and Randhawa draws the map of your life: a dot where you go, a line where you moved, darker where you return. A map only you can read.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
            VStack(spacing: 12) {
                Button(action: begin) {
                    Text("Begin")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                Text("iOS will ask about your location. Randhawa listens only for the moments your phone notices you have moved, using the low-power signals a sleeping app is allowed; it never runs continuously. Everything stays on this device unless you turn on iCloud sync, which keeps a copy in your private iCloud, invisible to us. No account. No tracking. Off in one tap.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(28)
        .background(Color(.systemBackground))
    }
}

/// Shown only when access is denied and there is no map yet to look at.
private struct DeniedView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 16) {
            Text("Randhawa needs location to draw your map")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
            Text("Allow location in Settings. Randhawa reads it to place your dots on your own map, and for nothing else.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    ContentView()
}
