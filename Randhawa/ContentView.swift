import SwiftUI
import MapKit
import UIKit
import CoreLocation

/// One geocoder for the app; requests are rare (one per saved memory).
private let geocoder = CLGeocoder()

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = SpaceModel()
    @ObservedObject private var memoryStore = MemoryStore.shared
    @AppStorage("showMap") private var showMap = true
    @State private var confirmingErase = false
    @State private var composing = false
    @State private var showingMemories = false
    @State private var showingTrail = false
    @State private var offeringSync = false

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
            CloudSync.startIfEnabled()
            model.sampleIfAuthorized()
            CloudSync.shared?.fetchNow()
            refreshSyncOffer()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.sampleIfAuthorized()
                memoryStore.reloadFromDisk()
                CloudSync.shared?.fetchNow()
                refreshSyncOffer()
            }
        }
    }

    private var spaceView: some View {
        ZStack {
            if showMap {
                MomentMap(
                    moments: model.moments,
                    memories: memoryStore.memories,
                    onMemoryTap: { showingMemories = true }
                )
                .ignoresSafeArea()
            } else {
                ZStack {
                    Color.black.ignoresSafeArea()
                    ConstellationView(moments: model.moments, dotDiameter: 7, inset: 48)
                }
                .environment(\.colorScheme, .dark)
            }

            VStack {
                HStack {
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
                        Divider()
                        Button("Erase everything", role: .destructive) {
                            confirmingErase = true
                        }
                    } label: {
                        ControlIcon(systemName: "ellipsis")
                    }
                    Spacer()
                    Button {
                        showMap.toggle()
                    } label: {
                        ControlIcon(systemName: showMap ? "sparkles" : "map")
                    }
                }
                Spacer()
                if offeringSync {
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
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                composing = true
            } label: {
                ControlIcon(systemName: "plus")
            }
            .padding(20)
        }
        .sheet(isPresented: $composing) {
            MemoryComposerView(
                prompt: "What is worth remembering here?",
                contextLine: composerContext,
                onSave: saveMemory
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
        TrailSettings.cadence.isOn ? "Trail: on" : "Trail: off"
    }

    private var composerContext: String {
        model.moments.last == nil
            ? "Pinned to this moment."
            : "Pinned to this place and this moment."
    }

    private var eraseMessage: String {
        var message = CloudSync.isEnabled
            ? "Every moment and memory is deleted from this device and from your iCloud. This cannot be undone."
            : "Every moment and memory is deleted from this device. There is no copy anywhere else, so this cannot be undone."
        // Erasing does not answer the trail question, so say so rather than
        // let a fresh dot appear a mile down the road and look like a bug.
        if TrailSettings.cadence.isOn {
            message += " The trail stays on, so it will begin a new map from wherever you go next. Turn it off first if you would rather it did not."
        }
        return message
    }

    /// Offer iCloud sync once the map is worth keeping, and only until the
    /// user has answered one way or the other.
    private func refreshSyncOffer() {
        offeringSync = !CloudSync.isDecided && model.moments.count >= 2
    }

    private func saveMemory(text: String, photoData: Data?) {
        let here = model.moments.last
        let memory = memoryStore.add(
            text: text,
            latitude: here?.latitude,
            longitude: here?.longitude,
            photoData: photoData
        )
        guard let here else { return }
        // Name the place while it is fresh; Apple's geocoder does one lookup
        // and the name syncs along with the memory.
        let location = CLLocation(latitude: here.latitude, longitude: here.longitude)
        geocoder.reverseGeocodeLocation(location) { placemarks, _ in
            guard let placemark = placemarks?.first else { return }
            let name = [placemark.locality ?? placemark.name, placemark.administrativeArea]
                .compactMap { $0 }
                .joined(separator: ", ")
            guard !name.isEmpty else { return }
            Task { @MainActor in
                MemoryStore.shared.setPlaceName(name, for: memory.id)
            }
        }
    }
}

/// The trail settings: the one screen in either app that asks for something
/// bigger than a tap. It says plainly what it will do, what iOS will actually
/// honour, and how to take it all back.
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
                    ForEach(TrailCadence.allCases) { option in
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
                    Text("How often")
                } footer: {
                    Text("A cadence is a ceiling, not a schedule. iOS wakes a sleeping app when you move, not on a clock, so Randhawa marks a dot no more often than this and only once you have actually gone somewhere. Stay in one place and the trail stays quiet.")
                }

                if cadence.isOn && needsAlways {
                    Section {
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                openURL(url)
                            }
                        }
                    } footer: {
                        Text("The trail needs Location set to Always. Without it Randhawa is never woken, so dots would still only arrive when you open the app.")
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
            if cadence.isOn {
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

/// The one-time iCloud pitch: what it does, in the app's own voice.
private struct SyncOfferCard: View {
    let turnOn: () -> Void
    let notNow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Keep your map, even on your next phone")
                .font(.subheadline.weight(.semibold))
            Text("iCloud sync keeps your moments and memories in your private iCloud, which we cannot read. Sign in on a new phone and your map comes back.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Button("Turn On", action: turnOn)
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

/// The real-map view: moments clumped for density, drawn as translucent orange
/// dots that darken where you return, the newest moment ringed in white, and
/// memories as small gold stars you can tap.
private struct MomentMap: View {
    let moments: [Moment]
    let memories: [Memory]
    var onMemoryTap: () -> Void = {}

    @State private var camera: MapCameraPosition = .automatic
    @State private var clumps: [MomentGeometry.Clump] = []

    var body: some View {
        Map(position: $camera) {
            ForEach(clumps) { clump in
                Annotation(
                    "",
                    coordinate: CLLocationCoordinate2D(latitude: clump.latitude, longitude: clump.longitude)
                ) {
                    Circle()
                        .fill(.orange.opacity(clumpOpacity(clump.count)))
                        .frame(width: clumpDiameter(clump.count), height: clumpDiameter(clump.count))
                }
                .annotationTitles(.hidden)
            }

            ForEach(placedMemories) { memory in
                Annotation(
                    "",
                    coordinate: CLLocationCoordinate2D(latitude: memory.latitude ?? 0, longitude: memory.longitude ?? 0)
                ) {
                    Circle()
                        .fill(.yellow)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(.white, lineWidth: 1.5))
                        .onTapGesture(perform: onMemoryTap)
                }
                .annotationTitles(.hidden)
            }

            if let latest = moments.last {
                Annotation(
                    "",
                    coordinate: CLLocationCoordinate2D(latitude: latest.latitude, longitude: latest.longitude)
                ) {
                    Circle()
                        .fill(.orange)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll, showsTraffic: false))
        // Clustering is O(n^2)-ish, so do it when moments change, not on
        // every body evaluation while the map is panned.
        .onAppear { recluster() }
        .onChange(of: moments) { _, _ in recluster() }
    }

    private var placedMemories: [Memory] {
        memories.filter(\.hasLocation)
    }

    private func recluster() {
        clumps = MomentGeometry.clumps(in: moments, radiusMeters: 35)
    }

    private func clumpOpacity(_ count: Int) -> Double {
        Swift.min(0.25 + 0.1 * Double(count), 0.85)
    }

    private func clumpDiameter(_ count: Int) -> CGFloat {
        CGFloat(10 + Swift.min(count, 14))
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
            Text("Each time you open Randhawa, it marks a dot where you are. Slowly, your places draw a map only you can read.")
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
                Text("Randhawa reads your location while you have it open. If you ever want the map to keep drawing itself, there is a trail you can switch on, off until you do. Everything stays on this device unless you turn on iCloud sync, which keeps a copy in your private iCloud, invisible to us. No account to create. No tracking.")
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
