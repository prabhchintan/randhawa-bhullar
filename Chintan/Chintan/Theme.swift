import SwiftUI
import UIKit

// The house's look, in one place: warm paper for the ground, a lighter
// card for what sits on it, deep saffron for the one accent, a serif for
// titles. Each colour has its own light and dark in the asset catalog.
enum Theme {
    static let paper = Color("Paper")
    static let card = Color("Card")
    static let spacing: CGFloat = 16

    static func title(_ style: Font.TextStyle = .title2) -> Font {
        .system(style, design: .serif).weight(.semibold)
    }

    // Navigation titles are drawn by UIKit, so the serif is set there once.
    @MainActor static func apply() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor(named: "Paper")
        appearance.largeTitleTextAttributes = [.font: serif(.largeTitle, weight: .bold)]
        appearance.titleTextAttributes = [.font: serif(.headline, weight: .semibold)]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance

        let tabs = UITabBarAppearance()
        tabs.configureWithDefaultBackground()
        tabs.backgroundColor = UIColor(named: "Paper")
        UITabBar.appearance().standardAppearance = tabs
        UITabBar.appearance().scrollEdgeAppearance = tabs
    }

    private static func serif(_ style: UIFont.TextStyle, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.preferredFont(forTextStyle: style)
        let weighted = base.fontDescriptor.addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: weight.rawValue]])
        let descriptor = weighted.withDesign(.serif) ?? weighted
        return UIFont(descriptor: descriptor, size: base.pointSize)
    }
}

extension View {
    // The warm ground under a screen, reaching under the bars.
    func paperBackground() -> some View {
        background(Theme.paper.ignoresSafeArea())
    }
}
