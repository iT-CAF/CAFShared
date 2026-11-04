import SwiftUI

/// One place that reads the accessibility environment so components stay consistent.
struct A11y {
    var reduceMotion: Bool
    var reduceTransparency: Bool
    var highContrast: Bool
}

private struct A11yKey: EnvironmentKey { static let defaultValue = A11y(reduceMotion: false, reduceTransparency: false, highContrast: false) }

struct A11yReader: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var rm
    @Environment(\.accessibilityReduceTransparency) private var rt
    @Environment(\.colorSchemeContrast) private var contrast
    func body(content: Content) -> some View {
        content.environment(\.a11y, A11y(reduceMotion: rm, reduceTransparency: rt, highContrast: contrast == .increased))
    }
}

extension EnvironmentValues {
    var a11y: A11y { get { self[A11yKey.self] } set { self[A11yKey.self] = newValue } }
}
extension View { func readsAccessibility() -> some View { modifier(A11yReader()) } }
