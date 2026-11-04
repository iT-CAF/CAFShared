import SwiftUI

/// The official Saudi Riyal symbol, drawn from the `riyal` template vector asset so it takes the surrounding
/// foreground colour. Sized from the amount's font so it matches cap height and scales with Dynamic Type.
struct RiyalMark: View {
    /// Aspect ratio of the artwork (386.6 x 432).
    static let aspect: CGFloat = 386.6 / 432
    /// Symbol height as a fraction of the font point size (cap-height of the brand mono/Plex faces is ~0.70).
    static let heightRatio: CGFloat = 0.72

    @ScaledMetric private var height: CGFloat

    /// - Parameters:
    ///   - pointSize: font point size of the number next to it.
    ///   - style: the text style the font scales with (keeps the mark in step under Dynamic Type).
    init(pointSize: CGFloat, relativeTo style: Font.TextStyle = .callout) {
        _height = ScaledMetric(wrappedValue: pointSize * Self.heightRatio, relativeTo: style)
    }

    /// Fixed (non-scaling) variant for rendered documents such as invoices.
    init(fixedPointSize: CGFloat) {
        _height = ScaledMetric(wrappedValue: fixedPointSize * Self.heightRatio, relativeTo: .body)
        fixed = fixedPointSize * Self.heightRatio
    }
    private var fixed: CGFloat?

    var body: some View {
        let h = fixed ?? height
        Image("Icons/riyal")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: h * Self.aspect, height: h)
            // Sit on the baseline (a hair below, like the web mark) when used in a firstTextBaseline stack.
            .alignmentGuide(.firstTextBaseline) { $0[.bottom] - h * 0.04 }
            .accessibilityHidden(true)
    }
}

/// Price: Latin digits in JetBrains Mono followed by the riyal symbol (LTR island, same order as the website).
/// Other currencies fall back to their code. Use everywhere a money amount is shown.
struct PriceText: View {
    let value: Double
    var currency = "SAR"
    var emphasis = true
    var strikethrough = false
    @Environment(LanguageManager.self) private var language

    var body: some View {
        let lang = language.language
        let amount = Text(Fmt.amount(value)).font(emphasis ? .brandMono : .brandMonoSmall)
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            amount
            if Fmt.isRiyal(currency) {
                RiyalMark(pointSize: emphasis ? 15 : 12.5, relativeTo: emphasis ? .callout : .caption)
            } else {
                Text(Fmt.symbol(currency, lang: lang)).font(.brandCaption)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .strikethrough(strikethrough)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(Fmt.spokenPrice(value, currency: currency, lang: lang)))
    }
}
