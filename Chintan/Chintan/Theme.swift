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

    private var pictures: [String: UIImage] = [:]
    private var fetching = false

    private static let folder: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let url = caches.appendingPathComponent("paintings", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()
    private static let shelfFile = folder.appendingPathComponent("shelf.json")
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
        // What the phone already holds is shown at once, house or no house.
        if shelf.isEmpty, let data = try? Data(contentsOf: Self.shelfFile),
           let saved = try? JSONDecoder().decode([HouseClient.Painting].self, from: data), !saved.isEmpty {
            shelf = saved
            await show(chosen(in: saved), animated: image == nil)
        }
        guard !fetching, let address = Keychain.loadHouseAddress(), !address.isEmpty else { return }
        fetching = true
        defer { fetching = false }
        let house = HouseClient(baseAddress: address)
        var fresh = (try? await house.paintings()) ?? []
        if fresh.isEmpty, let one = try? await house.painting() { fresh = [one] }   // an older house
        guard !fresh.isEmpty else { return }
        shelf = fresh
        try? JSONEncoder().encode(fresh).write(to: Self.shelfFile, options: .atomic)
        await show(chosen(in: fresh), animated: true)
        // The rest of the shelf comes down quietly, so next and an evening
        // without the house both have pictures; what left the shelf leaves the phone.
        for p in fresh where !FileManager.default.fileExists(atPath: Self.file(p).path) {
            _ = await picture(p, from: house)
        }
        let keep = Set(fresh.map { $0.key + ".jpg" } + ["shelf.json"])
        for name in (try? FileManager.default.contentsOfDirectory(atPath: Self.folder.path)) ?? [] where !keep.contains(name) {
            try? FileManager.default.removeItem(at: Self.folder.appendingPathComponent(name))
        }
    }

    // The next painting on the shelf that the phone holds; his choice is
    // remembered for the day. False when there is nothing to turn to yet.
    @discardableResult
    func next() async -> Bool {
        let ready = shelf.filter { pictures[$0.key] != nil || FileManager.default.fileExists(atPath: Self.file($0).path) }
        guard ready.count > 1 else { return false }
        let at = ready.firstIndex { $0.key == painting?.key } ?? -1
        let p = ready[(at + 1) % ready.count]
        UserDefaults.standard.set(p.key + "|" + Self.today, forKey: Self.chosenKey)
        await show(p, animated: true)
        return true
    }

    private func chosen(in list: [HouseClient.Painting]) -> HouseClient.Painting {
        if let saved = UserDefaults.standard.string(forKey: Self.chosenKey) {
            let parts = saved.split(separator: "|", maxSplits: 1).map(String.init)
            if parts.count == 2, parts[1] == Self.today, let p = list.first(where: { $0.key == parts[0] }) {
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

    var body: some View {
        Theme.lampBlack
            .overlay {
                if let image = gallery.image {
                    // A touch past the edge, so a scan's dark border never shows.
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(1.04)
                        .transition(.opacity)
                }
            }
            .clipped()
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

// A screen's own shade over the one painting: soft at the head where a
// screen letters its name, and always at the foot, so the tab bar's bone
// icons read on any picture. It slides with its screen; the picture stays.
struct PaintedGround: View {
    var head: CGFloat = 0
    var foot: CGFloat = 200
    var footShade: Double = 0.7

    var body: some View {
        Color.clear
            .overlay(alignment: .top) {
                if head > 0 {
                    LinearGradient(colors: [.black.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: head)
                }
            }
            .overlay(alignment: .bottom) {
                LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black.opacity(footShade), location: 0.6)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: foot)
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)
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
