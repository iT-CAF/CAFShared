import SwiftUI
import UIKit

/// One place that makes UIKit-hosted text (nav bar, tab bar, segmented controls, search fields, bar buttons, alerts)
/// use the brand faces, and a SwiftUI scope that gives every `Text` a brand default instead of the system font.
///
/// Rule of thumb: Thmanyah Serif Text = Arabic headings/titles, IBM Plex Sans Arabic = all UI, JetBrains Mono = numbers/IDs/codes.
@MainActor
enum BrandAppearance {
    private static func scaled(_ face: BrandFont.Face, _ size: CGFloat, _ style: UIFont.TextStyle) -> UIFont {
        guard let base = UIFont(name: face.rawValue, size: size) else { return .systemFont(ofSize: size) }
        return UIFontMetrics(forTextStyle: style).scaledFont(for: base)
    }

    /// Call at launch and again after an in-app language switch (appearance proxies only affect views created afterwards).
    static func install(language: AppLanguage) {
        let ar = language == .ar
        let titleFace: BrandFont.Face = ar ? .thmanyahBold : .plexBold
        let large = scaled(titleFace, 34, .largeTitle)
        let inline = scaled(ar ? .thmanyahBold : .plexSemiBold, 17, .headline)
        let ink = UIColor(Color.textPrimary)

        let nav = UINavigationBarAppearance()
        nav.configureWithDefaultBackground()
        nav.titleTextAttributes = [.font: inline, .foregroundColor: ink]
        nav.largeTitleTextAttributes = [.font: large, .foregroundColor: ink]
        let barButton = UIBarButtonItemAppearance(style: .plain)
        let btnFont = scaled(.plexMedium, 17, .body)
        for s in [barButton.normal, barButton.highlighted, barButton.disabled, barButton.focused] {
            s.titleTextAttributes = [.font: btnFont]
        }
        nav.buttonAppearance = barButton
        nav.doneButtonAppearance = barButton
        let navProxy = UINavigationBar.appearance()
        navProxy.standardAppearance = nav
        navProxy.scrollEdgeAppearance = nav
        navProxy.compactAppearance = nav
        UIBarButtonItem.appearance().setTitleTextAttributes([.font: btnFont], for: .normal)
        UIBarButtonItem.appearance().setTitleTextAttributes([.font: btnFont], for: .highlighted)

        let tabFont = scaled(.plexMedium, 11, .caption2)
        let tab = UITabBarAppearance()
        tab.configureWithDefaultBackground()
        for item in [tab.stackedLayoutAppearance, tab.inlineLayoutAppearance, tab.compactInlineLayoutAppearance] {
            item.normal.titleTextAttributes = [.font: tabFont]
            item.selected.titleTextAttributes = [.font: tabFont]
        }
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
        UITabBarItem.appearance().setTitleTextAttributes([.font: tabFont], for: .normal)
        UITabBarItem.appearance().setTitleTextAttributes([.font: tabFont], for: .selected)

        let seg = UISegmentedControl.appearance()
        seg.setTitleTextAttributes([.font: scaled(.plexMedium, 14, .subheadline)], for: .normal)
        seg.setTitleTextAttributes([.font: scaled(.plexSemiBold, 14, .subheadline)], for: .selected)

        let field = scaled(.plexRegular, 16, .body)
        UITextField.appearance().font = field
        UITextView.appearance().font = field
        UISearchTextField.appearance().font = field
        UILabel.appearance(whenContainedInInstancesOf: [UIAlertController.self]).font = scaled(.plexRegular, 14, .subheadline)
        UILabel.appearance(whenContainedInInstancesOf: [UITableViewHeaderFooterView.self]).font = scaled(.plexMedium, 13, .footnote)
    }
}

/// Default brand typography for any `Text`/control that does not set its own font. Apply once at every presentation root.
struct BrandFontScope: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.brandBody)
            .fontDesign(nil)
    }
}

extension View {
    /// New views inherit IBM Plex Sans Arabic instead of the system font.
    func brandFontScope() -> some View { modifier(BrandFontScope()) }

    /// List/Form section header & footer styling in the brand UI face.
    func brandSectionHeader() -> some View {
        font(.brandCaption).foregroundStyle(Color.textMuted).textCase(nil)
    }
}
