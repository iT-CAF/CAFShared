import SwiftUI

enum BrandButtonKind { case primary, secondary, ghost, destructive }

/// Amber-fill / graphite-text pill (rounded per owner decision). Min 52pt tall hit target.
struct BrandButtonStyle: ButtonStyle {
    var kind: BrandButtonKind = .primary
    var isLoading = false
    var fullWidth = true
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.brandButton)
            .foregroundStyle(foreground)
            .opacity(isLoading ? 0 : 1)
            .overlay { if isLoading { ProgressView().tint(foreground) } }
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 52)
            .padding(.horizontal, fullWidth ? Space.m : Space.l)
            .background(background(pressed: configuration.isPressed), in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            .overlay {
                if kind == .secondary || kind == .destructive {
                    RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                        .strokeBorder(kind == .destructive ? Color.signal : Color.lineStrong, lineWidth: 1.5)
                }
            }
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .spring(duration: 0.2), value: configuration.isPressed)
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(RoundedRectangle(cornerRadius: Radius.control))
    }

    private var foreground: Color {
        switch kind {
        case .primary: .onAccent
        case .secondary, .ghost: .textPrimary
        case .destructive: .signal
        }
    }
    private func background(pressed: Bool) -> Color {
        switch kind {
        case .primary: Color.accentFill.opacity(pressed ? 0.85 : 1)
        case .secondary, .destructive: Color.surfaceRaised.opacity(pressed ? 0.6 : 0)
        case .ghost: Color.clear.opacity(0)
        }
    }
}

struct BrandButton: View {
    let title: LocalizedStringKey
    var icon: Icon? = nil
    var kind: BrandButtonKind = .primary
    var isLoading = false
    var fullWidth = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.xs) {
                if let icon { IconView(icon: icon, size: 20) }
                Text(title)
            }
        }
        .buttonStyle(BrandButtonStyle(kind: kind, isLoading: isLoading, fullWidth: fullWidth))
        .disabled(isLoading)
        .accessibilityLabel(Text(title))
        .accessibilityValue(isLoading ? Text("a11y.loading") : Text(""))
    }
}
