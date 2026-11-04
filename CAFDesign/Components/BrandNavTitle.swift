import SwiftUI

/// Small monogram that "types" its amber chevron in when it appears (static under Reduce Motion).
struct AnimatedMark: View {
    var size: CGFloat = 26
    var replayToken: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var chevron: CGFloat = 0
    @State private var rest: CGFloat = 0
    var body: some View {
        LogoMark(size: size, progress: LogoProgress(chevron: reduceMotion ? 1 : chevron, body: reduceMotion ? 1 : rest,
                                                     blade: reduceMotion ? 1 : rest, madda: reduceMotion ? 1 : rest))
            .task(id: replayToken) {
                guard !reduceMotion else { return }
                chevron = 0; rest = 0
                withAnimation(.easeOut(duration: 0.45)) { chevron = 1 }
                withAnimation(.easeOut(duration: 0.6).delay(0.2)) { rest = 1 }
            }
    }
}

/// THE header system (one component, two shapes):
///  • root tab  — compact bar: brand mark + screen title (centred), at most one trailing action (+ optional bell).
///  • detail    — the system back button + a clean inline title (no mark). Sheets use the same title with a Close/Cancel item.
/// Both are inline (no large titles) so every screen's header has the same height, weight and baseline.
enum BrandHeaderKind { case root, detail }

struct BrandBarTitle: View {
    let title: Text
    var kind: BrandHeaderKind = .detail
    var body: some View {
        HStack(spacing: 8) {
            if kind == .root { AnimatedMark(size: 22).accessibilityHidden(true) }
            title.font(.brandSubheading).foregroundStyle(Color.textPrimary).lineLimit(1).minimumScaleFactor(0.75)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

private struct BrandNavTitleModifier: ViewModifier {
    let title: Text
    let kind: BrandHeaderKind
    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .modifier(SolidBarBackground())
            .toolbar { ToolbarItem(placement: .principal) { BrandBarTitle(title: title, kind: kind) } }
    }
}

/// Solid brand bar before iOS 26 (and with Reduce Transparency); iOS 26 keeps the system's scroll-edge glass.
private struct SolidBarBackground: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func body(content: Content) -> some View {
        if #available(iOS 26, *), !reduceTransparency { content }
        else { content.toolbarBackground(Color.surface, for: .navigationBar).toolbarBackground(.visible, for: .navigationBar) }
    }
}

extension View {
    /// Detail / pushed screens: system back button + clean inline title.
    func brandNavTitle(_ key: LocalizedStringKey, large: Bool = false) -> some View {
        navigationTitle(Text(key)).modifier(BrandNavTitleModifier(title: Text(key), kind: large ? .root : .detail))
    }
    func brandNavTitle(verbatim: String, large: Bool = false) -> some View {
        navigationTitle(verbatim).modifier(BrandNavTitleModifier(title: Text(verbatim: verbatim), kind: large ? .root : .detail))
    }
    /// Root tab screens: mark + title.
    func brandRootTitle(_ key: LocalizedStringKey) -> some View {
        navigationTitle(Text(key)).modifier(BrandNavTitleModifier(title: Text(key), kind: .root))
    }
}
