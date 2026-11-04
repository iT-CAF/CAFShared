import SwiftUI
import UIKit

/// Type scale from the brand book (05-typography), scaled with Dynamic Type via `relativeTo`.
/// Arabic display/headings: Thmanyah Serif Text. UI: IBM Plex Sans Arabic (merged Arabic+Latin TTF). Numbers/codes: JetBrains Mono.
enum BrandFont {
    enum Face: String {
        case thmanyahBold = "thmanyahseriftext-Bold", thmanyahMedium = "thmanyahseriftext-Medium", thmanyahRegular = "thmanyahseriftext-Regular"
        case plexRegular = "IBMPlexSansArabic-Regular", plexMedium = "IBMPlexSansArabic-Medium", plexSemiBold = "IBMPlexSansArabic-SemiBold", plexBold = "IBMPlexSansArabic-Bold"
        case monoRegular = "JetBrainsMono-Regular", monoMedium = "JetBrainsMono-Medium", monoBold = "JetBrainsMono-Bold"
    }

    static func font(_ face: Face, size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        // Falls back to the system font if the face is missing (never crashes, shows in debug logs).
        UIFont(name: face.rawValue, size: size) == nil
            ? .system(size: size, weight: .regular)
            : .custom(face.rawValue, size: size, relativeTo: style)
    }
}

extension Font {
    /// The App Clip ships no serif display face (size budget): headings use Plex there.
    #if APPCLIP
    private static var isArabic: Bool { false }
    #else
    private static var isArabic: Bool { L10n.language == .ar }
    #endif

    /// Hero title — once per screen (`ar-h1` scaled for phones).
    static var brandDisplay: Font { BrandFont.font(isArabic ? .thmanyahBold : .plexBold, size: 34, relativeTo: .largeTitle) }
    static var brandTitle: Font { BrandFont.font(isArabic ? .thmanyahBold : .plexBold, size: 26, relativeTo: .title) }
    static var brandHeading: Font { BrandFont.font(isArabic ? .thmanyahBold : .plexBold, size: 20, relativeTo: .title3) }
    static var brandSubheading: Font { BrandFont.font(isArabic ? .thmanyahMedium : .plexSemiBold, size: 17, relativeTo: .headline) }
    static var brandBody: Font { BrandFont.font(.plexRegular, size: 16, relativeTo: .body) }
    static var brandBodyStrong: Font { BrandFont.font(.plexMedium, size: 16, relativeTo: .body) }
    static var brandSmall: Font { BrandFont.font(.plexRegular, size: 14, relativeTo: .subheadline) }
    static var brandCaption: Font { BrandFont.font(.plexMedium, size: 12.5, relativeTo: .caption) }
    static var brandButton: Font { BrandFont.font(.plexSemiBold, size: 17, relativeTo: .headline) }
    /// Prices, IDs, codes — Latin digits, fixed-width.
    static var brandMono: Font { BrandFont.font(.monoMedium, size: 15, relativeTo: .callout) }
    static var brandMonoSmall: Font { BrandFont.font(.monoRegular, size: 12.5, relativeTo: .caption) }
    static func brandMono(size: CGFloat, bold: Bool = false, relativeTo: Font.TextStyle = .body) -> Font {
        BrandFont.font(bold ? .monoBold : .monoMedium, size: size, relativeTo: relativeTo)
    }
    /// Uppercase Latin eyebrow (`label` 11/16 +0.12em) — Latin only, never tracked in Arabic.
    static var brandLabel: Font { BrandFont.font(.monoMedium, size: 11, relativeTo: .caption2) }
}
