import SwiftUI

struct EmptyState: View {
    var icon: Icon = .package
    let title: LocalizedStringKey
    var message: LocalizedStringKey? = nil
    var actionTitle: LocalizedStringKey? = nil
    var action: (() -> Void)? = nil
    var body: some View {
        VStack(spacing: Space.m) {
            ZStack {
                Circle().fill(Color.surfaceRaised).frame(width: 84, height: 84).overlay(Circle().strokeBorder(Color.hairline))
                IconView(icon: icon, size: 34).foregroundStyle(Color.accent)
            }
            Text(title).font(.brandHeading).foregroundStyle(Color.textPrimary).multilineTextAlignment(.center)
            if let message { Text(message).font(.brandBody).foregroundStyle(Color.textMuted).multilineTextAlignment(.center) }
            if let actionTitle, let action { BrandButton(title: actionTitle, kind: .secondary, fullWidth: false, action: action).padding(.top, Space.xs) }
        }
        .padding(Space.xl)
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }
}

/// Inline error with retry.
struct ErrorBanner: View {
    let message: String
    var retryTitle: LocalizedStringKey = "common.retry"
    var onRetry: (() -> Void)? = nil
    var body: some View {
        HStack(alignment: .top, spacing: Space.s) {
            IconView(icon: .alert, size: 22).foregroundStyle(Color.signal)
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(message).font(.brandSmall).foregroundStyle(Color.textPrimary).fixedSize(horizontal: false, vertical: true)
                if let onRetry { Button(action: onRetry) { Text(retryTitle).font(.brandSmall.weight(.semibold)).foregroundStyle(Color.accentText) }.frame(minHeight: 32) }
            }
            Spacer(minLength: 0)
        }
        .padding(Space.m)
        .background(Color.signalFill.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.control, style: .continuous).strokeBorder(Color.signalFill.opacity(0.5)))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}

/// Shimmer placeholder. Static (no sweep) under Reduce Motion.
struct Skeleton: View {
    var height: CGFloat = 16
    var width: CGFloat? = nil
    var radius: CGFloat = 8
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1
    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(Color.surfaceSunken)
            .overlay {
                if !reduceMotion {
                    GeometryReader { g in
                        LinearGradient(colors: [.clear, Color.hairline.opacity(0.9), .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: g.size.width * 0.6)
                            .offset(x: phase * g.size.width * 1.6)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                }
            }
            .frame(width: width, height: height)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) { phase = 1 }
            }
            .accessibilityHidden(true)
    }
}

/// Generic card-shaped loading placeholder.
struct SkeletonCard: View {
    var body: some View {
        BrandCard { VStack(alignment: .leading, spacing: Space.s) { Skeleton(height: 16, width: 140); Skeleton(height: 12); Skeleton(height: 12, width: 220) } }
            .accessibilityElement(children: .ignore).accessibilityLabel(Text("a11y.loading"))
    }
}
