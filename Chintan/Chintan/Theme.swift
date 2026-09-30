import ImageIO
import SwiftUI
import UIKit

// The house's look, in one place: a museum at night. Bone and lamp black
// for the grounds, graphite and bone for the ink, old gold for hairlines
// and the active tab, saffron only as a single mark. Each colour has its
// own light and dark in the asset catalog. The painting is the real ground
// of every screen; the colours are for what sits on it.
enum Theme {
    static let ground = Color("Ground")
    static let plaque = Color("Plaque")
    static let ink = Color("Ink")
    static let gilt = Color("AccentColor")
    static let saffron = Color("Saffron")
    static let spacing: CGFloat = 16
    // How tall a scroll dissolves into the painting above the bar: a line
    // that runs under it fades out as a leaf, never cut mid-word.
    static let foot: CGFloat = 96

    // What is lettered straight onto the art, in either mode.
    static let bone = Color(red: 0.925, green: 0.910, blue: 0.875)
    static let lampBlack = Color(red: 0.071, green: 0.067, blue: 0.063)
    static let giltOnArt = Color(red: 0.788, green: 0.647, blue: 0.373)

    static func title(_ style: Font.TextStyle = .title2) -> Font {
        .system(style, design: .serif).weight(.semibold)
    }

    // A wall label: small serif capitals, tracked.
    static func label(_ style: Font.TextStyle = .footnote) -> Font {
        .system(style, design: .serif).smallCaps()
    }

    // The navigation bar is drawn by UIKit, so it is set there once,
    // transparent, so the painting runs under it. The tab bar is our own.
    @MainActor static func apply() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.largeTitleTextAttributes = [.font: serif(.largeTitle, weight: .bold)]
        appearance.titleTextAttributes = [.font: serif(.headline, weight: .semibold)]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }

    private static func serif(_ style: UIFont.TextStyle, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.preferredFont(forTextStyle: style)
        let weighted = base.fontDescriptor.addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: weight.rawValue]])
        let descriptor = weighted.withDesign(.serif) ?? weighted
        return UIFont(descriptor: descriptor, size: base.pointSize)
    }
}

// The gallery: the painting under every tab, and the shelf behind it. The
// shelf (today's and the days ahead) is kept on the phone, pictures and all,
// so the app opens on a painting with no house in reach and "next" is a tap
// (Prab, 2026-09-23 07:15: "a dozen or so artworks that remain downloaded for
// offline use, easily probably one of my favorite features"). His choice
// holds for the day; a new day opens on its own painting.
@MainActor
final class Gallery: ObservableObject {
    @Published var image: UIImage?
    @Published var painting: HouseClient.Painting?
    @Published var shelf: [HouseClient.Painting] = []
    // On the Mac, the picture a turn is fading from, kept under the new one.
    @Published private(set) var under: UIImage?
    // The painting that stood the day before today's, kept on the phone.
    @Published private(set) var yesterday: HouseClient.Painting?

    private var pictures: [String: UIImage] = [:]
    private var fetching = false

    private static let folder: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let url = caches.appendingPathComponent("paintings", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()
    private static let shelfFile = folder.appendingPathComponent("shelf.json")
    private static let yesterdayFile = folder.appendingPathComponent("yesterday.json")
    private static let chosenKey = "gallery.chosen"
    private static let dayFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
    private static var today: String { dayFormat.string(from: .now) }

    private static func file(_ p: HouseClient.Painting) -> URL {
        folder.appendingPathComponent(p.key + ".jpg")
    }

    func load() async {
        #if targetEnvironment(macCatalyst)
        // The wall opens on the last work it hung, house or no house, and
        // then turns by asking; the shelf waits as the fallback.
        if hung.isEmpty, let data = try? Data(contentsOf: Self.hungFile),
           let saved = try? JSONDecoder().decode([HouseClient.Painting].self, from: data),
           let last = saved.last(where: { FileManager.default.fileExists(atPath: Self.file($0).path) }) {
            hung = saved.filter { FileManager.default.fileExists(atPath: Self.file($0).path) }
            await show(last, animated: image == nil)
        }
        if !hung.isEmpty || asking { return }
        if await hang() { return }
        #endif
        await stock()
    }

    // The shelf: what the phone already holds, then the house's, every
    // picture brought down. `show` false on the Mac's fallback, which turns
    // to the shelf itself.
    private func stock(show showing: Bool = true) async {
        // What the phone already holds is shown at once, house or no house.
        if shelf.isEmpty, let data = try? Data(contentsOf: Self.shelfFile),
           let saved = try? JSONDecoder().decode([HouseClient.Painting].self, from: data), !saved.isEmpty {
            if let kept = try? Data(contentsOf: Self.yesterdayFile) {
                yesterday = try? JSONDecoder().decode(HouseClient.Painting.self, from: kept)
            }
            shelf = saved
            if showing { await show(chosen(in: saved), animated: image == nil) }
        }
        guard !fetching, let address = Keychain.loadHouseAddress(), !address.isEmpty else { return }
        fetching = true
        defer { fetching = false }
        let house = HouseClient(baseAddress: address)
        var fresh: [HouseClient.Painting] = []
        #if targetEnvironment(macCatalyst)
        // The Mac hangs the wide shelf, landscape works chosen for its frame;
        // a house with none yet answers empty or 404, and the phone's shelf
        // is hung instead, each in its landscape cut.
        fresh = (try? await house.paintings(frame: "wall")) ?? []
        #endif
        if fresh.isEmpty { fresh = (try? await house.paintings()) ?? [] }
        if fresh.isEmpty, let one = try? await house.painting() { fresh = [one] }   // an older house
        guard !fresh.isEmpty else { return }
        keepYesterday(before: fresh)
        shelf = fresh
        try? JSONEncoder().encode(fresh).write(to: Self.shelfFile, options: .atomic)
        // A picture kept from before the house framed them for the phone
        // comes down again, refitted.
        for p in fresh where FileManager.default.fileExists(atPath: Self.file(p).path) && !Self.framed(Self.file(p)) {
            try? FileManager.default.removeItem(at: Self.file(p))
            pictures[p.key] = nil
        }
        if showing { await show(chosen(in: fresh), animated: true) }
        // The rest of the shelf comes down quietly, so next and an evening
        // without the house both have pictures; what left the shelf leaves the phone.
        for p in fresh where !FileManager.default.fileExists(atPath: Self.file(p).path) {
            _ = await picture(p, from: house)
        }
        let keep = Set((fresh + hung + [yesterday].compactMap { $0 }).map { $0.key + ".jpg" } + ["shelf.json", "yesterday.json", "hung.json"])
        for name in (try? FileManager.default.contentsOfDirectory(atPath: Self.folder.path)) ?? [] where !keep.contains(name) {
            try? FileManager.default.removeItem(at: Self.folder.appendingPathComponent(name))
        }
    }

    // The next painting on the shelf that the phone holds; his choice is
    // remembered for the day. False when there is nothing to turn to yet.
    @discardableResult
    func next() async -> Bool {
        await turn(1, wrap: true)
    }

    // One step along the paintings the phone holds, yesterday's first, then
    // today's and the days ahead. A swipe stops at either end; the label's
    // next goes round. False when there is nowhere to turn.
    @discardableResult
    func turn(_ by: Int, wrap: Bool = false) async -> Bool {
        await step(walk, by, wrap: wrap)
    }

    private func step(_ list: [HouseClient.Painting], _ by: Int, wrap: Bool) async -> Bool {
        let ready = list.filter { pictures[$0.key] != nil || FileManager.default.fileExists(atPath: Self.file($0).path) }
        guard ready.count > 1 else { return false }
        let at = ready.firstIndex { $0.key == painting?.key } ?? (by > 0 ? -1 : ready.count)
        var to = at + by
        if wrap { to = (to + ready.count) % ready.count }
        guard ready.indices.contains(to) else { return false }
        let p = ready[to]
        UserDefaults.standard.set(p.key + "|" + Self.today, forKey: Self.chosenKey)
        await show(p, animated: true)
        return true
    }

    // A tap on the widget: the work it hung, when the phone holds it too,
    // chosen for the day; otherwise the painting on the wall stays.
    func choose(id: String) async {
        guard let p = walk.first(where: { $0.id == id }), p.key != painting?.key else { return }
        UserDefaults.standard.set(p.key + "|" + Self.today, forKey: Self.chosenKey)
        await show(p, animated: true)
    }

    // What a hold on the painting alone came to, said at its foot.
    enum Kept { case kept, already, noDoor, unheard }

    // The painting on the wall filed in the vault's baithak by the house.
    // The phone remembers only the ids the house took, so a second hold
    // says so and asks nothing. `staged` answers as the house would, unasked,
    // for the house's own eyes.
    func keep(staged: Bool = false) async -> Kept {
        guard let p = painting, let id = p.id else { return .unheard }
        var kept = Set(UserDefaults.standard.stringArray(forKey: Self.keptKey) ?? [])
        if kept.contains(id) { return .already }
        if !staged {
            guard let address = Keychain.loadHouseAddress(), !address.isEmpty else { return .unheard }
            do {
                try await HouseClient(baseAddress: address).keep(p)
            } catch HouseError.noDoor {
                return .noDoor
            } catch {
                return .unheard
            }
            kept.insert(id)
            UserDefaults.standard.set(Array(kept), forKey: Self.keptKey)
        }
        return .kept
    }

    private static let keptKey = "gallery.kept"

    // Whether the painting on the wall is yesterday's, kept by the phone.
    var showingYesterday: Bool { painting != nil && painting?.key == yesterday?.key }

    #if targetEnvironment(macCatalyst)
    // The Mac wall's own loop (Prab, 2026-09-27 17:41: "run the full
    // collection on the Mac as well"): each turn asks the house for one fresh
    // work off its whole wide pool, and the last few stay, so a swipe back
    // still finds them; kept on disk, so the wall reopens on the last one.
    @Published private(set) var hung: [HouseClient.Painting] = []
    private var asking = false
    private static let hungFile = folder.appendingPathComponent("hung.json")
    private static let hungKept = 6

    // The house's next work, brought down and hung with the slow crossfade.
    // False when the house does not answer or is asked already.
    @discardableResult
    func hang() async -> Bool {
        guard !asking, let address = Keychain.loadHouseAddress(), !address.isEmpty else { return false }
        asking = true
        defer { asking = false }
        let house = HouseClient(baseAddress: address)
        guard let p = try? await house.wallNext() else { return false }
        if pictures[p.key] == nil, !FileManager.default.fileExists(atPath: Self.file(p).path) {
            guard await picture(p, from: house) != nil else { return false }
        }
        hung.removeAll { $0.key == p.key }
        hung.append(p)
        // What falls off the end leaves the Mac, unless the shelf holds it.
        while hung.count > Self.hungKept {
            let old = hung.removeFirst()
            guard !shelf.contains(where: { $0.key == old.key }) else { continue }
            pictures[old.key] = nil
            try? FileManager.default.removeItem(at: Self.file(old))
        }
        try? JSONEncoder().encode(hung).write(to: Self.hungFile, options: .atomic)
        await show(p, animated: true)
        return true
    }

    // A turn of the wall: the house's next work, or with the house silent,
    // the next on the wide shelf, fetched once when the wall has none.
    @discardableResult
    func turnWall() async -> Bool {
        guard !asking else { return false }
        if await hang() { return true }
        if shelf.isEmpty { await stock(show: false) }
        return await step(shelfWalk, 1, wrap: true)
    }

    // Back and forth through what the wall has hung; the shelf when it has
    // hung nothing yet.
    private var walk: [HouseClient.Painting] { hung.isEmpty ? shelfWalk : hung }
    #else
    private var walk: [HouseClient.Painting] { shelfWalk }
    private var hung: [HouseClient.Painting] { [] }
    #endif

    private var shelfWalk: [HouseClient.Painting] {
        guard let yesterday, !shelf.contains(where: { $0.key == yesterday.key }) else { return shelf }
        return [yesterday] + shelf
    }

    // When the house's shelf has moved on a day, the painting that stood
    // before today's is kept, picture and all, so it is one swipe back. A
    // shelf that has moved further than the phone knew keeps nothing.
    private func keepYesterday(before fresh: [HouseClient.Painting]) {
        guard let old = shelf.first, old.key != fresh[0].key else { return }
        var kept: HouseClient.Painting?
        if let i = shelf.firstIndex(where: { $0.key == fresh[0].key }), i > 0 {
            kept = shelf[i - 1]
        }
        if let k = kept, !FileManager.default.fileExists(atPath: Self.file(k).path) { kept = nil }
        yesterday = kept
        if let kept, let data = try? JSONEncoder().encode(kept) {
            try? data.write(to: Self.yesterdayFile, options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: Self.yesterdayFile)
        }
    }

    private func chosen(in list: [HouseClient.Painting]) -> HouseClient.Painting {
        if let saved = UserDefaults.standard.string(forKey: Self.chosenKey) {
            let parts = saved.split(separator: "|", maxSplits: 1).map(String.init)
            if parts.count == 2, parts[1] == Self.today,
               let p = (list + [yesterday].compactMap { $0 }).first(where: { $0.key == parts[0] }) {
                return p
            }
        }
        return list[0]
    }

    private func show(_ p: HouseClient.Painting, animated: Bool) async {
        painting = p
        var ui = pictures[p.key]
        if ui == nil, let data = try? Data(contentsOf: Self.file(p)), let raw = UIImage(data: data) {
            ui = await Self.prepared(raw)
            pictures[p.key] = ui
        }
        if ui == nil, let address = Keychain.loadHouseAddress(), !address.isEmpty {
            ui = await picture(p, from: HouseClient(baseAddress: address))
        }
        guard let ui, painting?.key == p.key else { return }
        #if targetEnvironment(macCatalyst)
        // The wall turns by a slow crossfade: the old picture stays whole
        // under the new one while it comes up, so nothing dips and nothing slides.
        if animated, image != nil {
            under = image
            withAnimation(.easeInOut(duration: 2.6)) { image = ui }
            return
        }
        #endif
        if animated {
            withAnimation(.easeInOut(duration: 0.6)) { image = ui }
        } else {
            image = ui
        }
    }

    // One picture from the house, kept on disk and decoded once.
    private func picture(_ p: HouseClient.Painting, from house: HouseClient) async -> UIImage? {
        guard let data = try? await house.paintingImage(p), let raw = UIImage(data: data) else { return nil }
        try? data.write(to: Self.file(p), options: .atomic)
        let ui = await Self.prepared(raw)
        pictures[p.key] = ui
        return ui
    }

    // Whether a kept picture is the phone's frame (1179 by 2556), read from
    // its header without decoding it. On the Mac, the wall's (1920 by 1080);
    // a phone's cut kept while the house had no wall cut comes down again.
    private static func framed(_ url: URL) -> Bool {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Double, let h = props[kCGImagePropertyPixelHeight] as? Double,
              w > 0 else { return false }
        #if targetEnvironment(macCatalyst)
        return abs(h / w - 1080.0 / 1920.0) < 0.02
        #else
        return abs(h / w - 2556.0 / 1179.0) < 0.02
        #endif
    }

    // Decoded once, off the main thread, at the size the screen fills with
    // it: a full scan left lazy is decoded and scaled again by every tab
    // that shows it, a stall of a tenth of a second on each tap.
    private static func prepared(_ ui: UIImage) async -> UIImage {
        let screen = UIScreen.main
        let fill = max(screen.bounds.width / ui.size.width, screen.bounds.height / ui.size.height) * 1.04
        guard fill < 1 else { return await ui.byPreparingForDisplay() ?? ui }
        let size = CGSize(width: (ui.size.width * fill).rounded(.up), height: (ui.size.height * fill).rounded(.up))
        return await ui.byPreparingThumbnail(ofSize: CGSize(width: size.width * screen.scale, height: size.height * screen.scale)) ?? ui
    }
}

// The painting itself, drawn once under every tab, full bleed, the tabs
// sliding over it. While the picture is missing, the gallery wall after hours.
struct Painting: View {
    @EnvironmentObject private var gallery: Gallery
    // A closer look while the painting stands alone: the pinch's scale, from
    // the point the fingers began at.
    var zoom: CGFloat = 1
    var anchor: UnitPoint = .center

    var body: some View {
        Theme.lampBlack
            #if targetEnvironment(macCatalyst)
            .overlay {
                ZStack {
                    if let under = gallery.under { picture(under) }
                    // Each picture its own view, so a turn is one fading in
                    // over the last; the one it replaces goes only once covered.
                    if let image = gallery.image {
                        picture(image)
                            .id(ObjectIdentifier(image))
                            .transition(.asymmetric(insertion: .opacity, removal: .identity))
                    }
                }
            }
            #else
            .overlay {
                if let image = gallery.image {
                    // The house composes each picture for the phone's frame, so
                    // it fills the screen as it came, no offset of our own; a
                    // touch past the edge only, since many scans still carry
                    // their border (a black line, the frame's lip, the page),
                    // until the house trims it before composing.
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(1.04)
                        .scaleEffect(zoom, anchor: anchor)
                        .transition(.opacity)
                }
            }
            #endif
            .clipped()
            .accessibilityHidden(true)
            .ignoresSafeArea()
    }

    private func picture(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .scaleEffect(1.04)
            .scaleEffect(zoom, anchor: anchor)
    }
}

// The painting alone: Home asks for it with a tap on the bare picture, and
// the app puts every page, the bar and the clock away until the next tap.
private struct PaintingAloneKey: EnvironmentKey {
    static let defaultValue: Binding<Bool> = .constant(false)
}

extension EnvironmentValues {
    var paintingAlone: Binding<Bool> {
        get { self[PaintingAloneKey.self] }
        set { self[PaintingAloneKey.self] = newValue }
    }
}

// A screen's own shade over the one painting: soft at the head where a
// screen letters its name, and always at the foot, so the tab bar's bone
// icons read on any picture. It slides with its screen; the picture stays.
// A head that holds keeps its whole dark for that share of its height before
// it dissolves, so a scan's pale border under the letters never shows as a band.
struct PaintedGround: View {
    var head: CGFloat = 0
    var headShade: Double = 0.6
    var headHold: Double = 0
    var foot: CGFloat = 200
    var footShade: Double = 0.7

    // The safe area it reaches past, to the screen's edges.
    @State private var past = EdgeInsets()

    // Reached past the safe area by padding, never by ignoring it: a view
    // ignoring it stood in the accessibility tree as an unnamed element the
    // size of the screen, hidden or not.
    var body: some View {
        Color.clear
            .onGeometryChange(for: EdgeInsets.self) { $0.safeAreaInsets } action: { past = $0 }
            .overlay {
                shade
                    .padding(.top, -past.top)
                    .padding(.bottom, -past.bottom)
                    .padding(.leading, -past.leading)
                    .padding(.trailing, -past.trailing)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var shade: some View {
        Canvas { context, size in
            if head > 0 {
                let band = CGRect(x: 0, y: 0, width: size.width, height: head)
                context.fill(Path(band), with: .linearGradient(
                    Gradient(stops: [.init(color: .black.opacity(headShade), location: 0),
                                     .init(color: .black.opacity(headShade), location: headHold),
                                     .init(color: .black.opacity(headShade / 2), location: (headHold + 1) / 2),
                                     .init(color: .clear, location: 1)]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: head)))
            }
            let top = size.height - foot
            let band = CGRect(x: 0, y: top, width: size.width, height: foot)
            context.fill(Path(band), with: .linearGradient(
                Gradient(stops: [.init(color: .clear, location: 0), .init(color: .black.opacity(footShade), location: 0.6)]),
                startPoint: CGPoint(x: 0, y: top), endPoint: CGPoint(x: 0, y: size.height)))
        }
    }
}

extension View {
    // The densest text sits on a small plaque: bone or lamp black, a gilt
    // hairline at its edge, the picture seen around it.
    // The shadow falls from the plaque alone, never from its letters.
    func plaque(radius: CGFloat = 14) -> some View {
        background {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Theme.plaque.opacity(0.97))
                .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        }
        .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Theme.gilt.opacity(0.55), lineWidth: 0.5))
    }

    // A name lettered on the art stands on a small mount of smoked glass,
    // square cornered like a wall label, so a bright passage of the picture
    // (a face, a sky) never swallows it; the picture is still seen through.
    func mount() -> some View {
        padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(Theme.lampBlack.opacity(0.42))
                    .environment(\.colorScheme, .dark)
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            }
    }

    // A scroll that dissolves into the painting at its edges instead of
    // sliding hard under the bars. The foot eases out and is clear for its
    // last stretch, so no half-lettered line sits on the bar's edge.
    func fadedEdges(top: CGFloat = 24, bottom: CGFloat = 28) -> some View {
        mask {
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom).frame(height: top)
                Color.black
                LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black.opacity(0.5), location: 0.4),
                                       .init(color: .black.opacity(0.1), location: 0.75), .init(color: .clear, location: 0.92)],
                               startPoint: .top, endPoint: .bottom).frame(height: bottom)
            }
        }
    }
}
