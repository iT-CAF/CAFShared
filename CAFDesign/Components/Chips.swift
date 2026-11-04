import SwiftUI

enum Tone { case neutral, accent, success, signal
    var fg: Color { switch self { case .neutral: .textMuted; case .accent: .accentText; case .success: .success; case .signal: .signal } }
    var bg: Color { switch self { case .neutral: .surfaceSunken; case .accent: .accent.opacity(0.14); case .success: .successFill.opacity(0.16); case .signal: .signalFill.opacity(0.16) } }
}

/// Small tag: optional icon + word. Status is never colour-only.
struct Chip: View {
    let text: LocalizedStringKey
    var icon: Icon? = nil
    var tone: Tone = .neutral
    var body: some View {
        HStack(spacing: 4) {
            if let icon { IconView(icon: icon, size: 13) }
            Text(text).font(.brandCaption)
        }
        .foregroundStyle(tone.fg)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(tone.bg, in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Order / ticket status: icon + localized word + tone.
struct StatusBadge: View {
    let text: String
    var icon: Icon = .clock
    var tone: Tone = .neutral
    var body: some View {
        HStack(spacing: 4) {
            IconView(icon: icon, size: 13)
            Text(text).font(.brandCaption)
        }
        .foregroundStyle(tone.fg)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(tone.bg, in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

/// Section title led by the amber prompt chevron `›` (`.ic-prompt`). Mirrors in RTL like the web.
struct SectionHeader: View {
    let title: LocalizedStringKey
    var actionTitle: LocalizedStringKey? = nil
    var action: (() -> Void)? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
            Text(verbatim: "›").font(.brandMono(size: 22, bold: true)).foregroundStyle(Color.accent)
                .scaleEffect(x: L10n.language == .ar ? -1 : 1).accessibilityHidden(true)
            Text(title).font(.brandHeading).foregroundStyle(Color.textPrimary).accessibilityAddTraits(.isHeader)
            Spacer(minLength: Space.s)
            if let actionTitle, let action {
                Button(action: action) { Text(actionTitle).font(.brandSmall).foregroundStyle(Color.accentText) }
                    .frame(minHeight: 44)
            }
        }
    }
}
