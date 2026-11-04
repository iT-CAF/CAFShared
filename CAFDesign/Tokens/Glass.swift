import SwiftUI

/// Liquid Glass lives ONLY on the navigation layer (bars, sheets, floating controls).
/// Content (cards, lists) is always solid. Pre-iOS 26, Reduce Transparency and Increase Contrast fall back to solid surfaces.
struct BarGlass: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    var shape: AnyShape = AnyShape(Rectangle())

    func body(content: Content) -> some View {
        if reduceTransparency || contrast == .increased {
            content.background(Color.surfaceRaised, in: shape).overlay(alignment: .bottom) { Divider().overlay(Color.hairline) }
        } else if #available(iOS 26, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content.background(.ultraThinMaterial, in: shape)
        }
    }
}

extension View {
    /// Apply to floating bars/controls only.
    func barGlass(in shape: some Shape = Rectangle()) -> some View { modifier(BarGlass(shape: AnyShape(shape))) }

    /// Solid, readable background for sheets — glass comes from the system sheet chrome on iOS 26.
    func brandSheetBackground() -> some View {
        presentationBackground(Color.surface).presentationCornerRadius(Radius.sheet)
    }
}
