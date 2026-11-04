import SwiftUI

struct BrandSegmentOption<V: Hashable>: Identifiable {
    var id: V { value }
    let value: V
    var title: LocalizedStringKey? = nil
    var systemImage: String? = nil
    var icon: Icon? = nil
    var a11y: LocalizedStringKey
}

/// Brand segmented control with a matched-geometry highlight (replaces `Picker(.segmented)` where we want the amber thumb).
struct BrandSegmented<V: Hashable>: View {
    let options: [BrandSegmentOption<V>]
    @Binding var selection: V
    var compact = false
    @Namespace private var ns
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options) { o in
                let on = o.value == selection
                Button {
                    guard !on else { return }
                    Haptics.selection()
                    withAnimation(reduceMotion ? nil : .snappy(duration: 0.3)) { selection = o.value }
                } label: {
                    HStack(spacing: 6) {
                        if let s = o.systemImage { Image(systemName: s).font(.system(size: compact ? 14 : 15, weight: .semibold)) }
                        if let i = o.icon { IconView(icon: i, size: compact ? 16 : 18) }
                        if let t = o.title { Text(t).font(.brandSmall.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8) }
                    }
                    .foregroundStyle(on ? Color.onAccent : Color.textPrimary)
                    .padding(.horizontal, compact ? 12 : 14)
                    .frame(maxWidth: o.title == nil ? nil : .infinity, minHeight: compact ? 34 : 40)
                    .background {
                        if on { RoundedRectangle(cornerRadius: Radius.control - 2, style: .continuous).fill(Color.accentFill).matchedGeometryEffect(id: "thumb", in: ns) }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(o.a11y))
                .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(3)
        .background(Color.surfaceSunken, in: RoundedRectangle(cornerRadius: Radius.control + 1, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.control + 1, style: .continuous).strokeBorder(Color.lineStrong.opacity(0.35)))
    }
}

/// 5-star display with partial fill. Always left-to-right.
struct StarRating: View {
    let value: Double
    var size: CGFloat = 13
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { i in
                let fill = max(0, min(1, value - Double(i)))
                ZStack(alignment: .leading) {
                    Image(systemName: "star.fill").foregroundStyle(Color.surfaceSunken.opacity(1)).overlay(Image(systemName: "star").foregroundStyle(Color.lineStrong.opacity(0.5)))
                    Image(systemName: "star.fill").foregroundStyle(Color.accent)
                        .mask(alignment: .leading) { Rectangle().frame(width: size * fill) }
                }
            }
        }
        .font(.system(size: size)) // font-ok: SF Symbol glyph size
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: L10n.string("store.a11y.rating", String(format: "%.1f", value))))
    }
}
