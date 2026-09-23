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

    // The bars are drawn by UIKit, so they are set there once: both
    // transparent, so the painting runs under them.
    @MainActor static func apply() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.largeTitleTextAttributes = [.font: serif(.largeTitle, weight: .bold)]
        appearance.titleTextAttributes = [.font: serif(.headline, weight: .semibold)]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance

        let bone = UIColor(Theme.bone)
        let gilt = UIColor(Theme.giltOnArt)
        let item = UITabBarItemAppearance()
        let font = smallCaps(size: 11)
        item.normal.iconColor = bone.withAlphaComponent(0.72)
        item.normal.titleTextAttributes = [.foregroundColor: bone.withAlphaComponent(0.72), .font: font, .kern: 0.6]
        item.selected.iconColor = gilt
        item.selected.titleTextAttributes = [.foregroundColor: gilt, .font: font, .kern: 0.6]

        let tabs = UITabBarAppearance()
        tabs.configureWithTransparentBackground()
        tabs.shadowColor = .clear
        tabs.stackedLayoutAppearance = item
        tabs.inlineLayoutAppearance = item
        tabs.compactInlineLayoutAppearance = item
        UITabBar.appearance().standardAppearance = tabs
        UITabBar.appearance().scrollEdgeAppearance = tabs
    }

    private static func serif(_ style: UIFont.TextStyle, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.preferredFont(forTextStyle: style)
        let weighted = base.fontDescriptor.addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: weight.rawValue]])
        let descriptor = weighted.withDesign(.serif) ?? weighted
        return UIFont(descriptor: descriptor, size: base.pointSize)
    }

    private static func smallCaps(size: CGFloat) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: .medium).fontDescriptor
        let serif = base.withDesign(.serif) ?? base
        let caps = serif.addingAttributes([.featureSettings: [
            [UIFontDescriptor.FeatureKey.type: kLowerCaseType, UIFontDescriptor.FeatureKey.selector: kLowerCaseSmallCapsSelector],
        ]])
        return UIFont(descriptor: caps, size: size)
    }
}

// The day's painting, fetched once from the house and shared by every tab.
@MainActor
final class Gallery: ObservableObject {
    @Published var image: UIImage?
    @Published var painting: HouseClient.Painting?

    func load() async {
        guard let address = Keychain.loadHouseAddress(), !address.isEmpty else { return }
        let house = HouseClient(baseAddress: address)
        async let label = try? house.painting()
        async let picture = try? house.paintingImage()
        let (l, p) = await (label, picture)
        if let l { painting = l }
        if let p, let ui = UIImage(data: p) {
            withAnimation(.easeInOut(duration: 0.6)) { image = ui }
        }
    }
}

// The painting as a screen's ground, full bleed, running under both bars.
// A soft shade at the head where a screen letters its name, and always at
// the foot, so the tab bar's bone icons read on any picture. While the
// picture is missing, the gallery wall after hours.
struct PaintedGround: View {
    @EnvironmentObject private var gallery: Gallery
    var head: CGFloat = 0
    var foot: CGFloat = 200
    var footShade: Double = 0.7

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
    func plaque(radius: CGFloat = 14) -> some View {
        background(Theme.plaque.opacity(0.97), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Theme.gilt.opacity(0.55), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
    }

    // A scroll that dissolves into the painting at its edges instead of
    // sliding hard under the bars.
    func fadedEdges(top: CGFloat = 24, bottom: CGFloat = 28) -> some View {
        mask {
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom).frame(height: top)
                Color.black
                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom).frame(height: bottom)
            }
        }
    }
}
