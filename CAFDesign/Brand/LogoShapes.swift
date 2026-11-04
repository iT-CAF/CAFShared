import SwiftUI

/// The «›ك» monogram rebuilt as stroked centre-lines of the official SVG (01_Logo/SVG/itcaf-monogram-app-icon.svg),
/// so every segment can be trimmed/animated. Grid: viewBox -26 -28 152 152 (the app-icon square).
/// Stroke widths: chevron 10, kaf 10, madda 9 — miter joins, butt caps = identical silhouette to the filled logo.
enum LogoGrid {
    static let box = CGRect(x: -26, y: -28, width: 152, height: 152)
    static let chevronWidth: CGFloat = 10
    static let kafWidth: CGFloat = 10
    static let maddaWidth: CGFloat = 9

    static func transform(in rect: CGRect) -> (scale: CGFloat, map: (CGFloat, CGFloat) -> CGPoint) {
        let s = min(rect.width, rect.height) / box.width
        let ox = rect.midX - box.width * s / 2, oy = rect.midY - box.height * s / 2
        return (s, { x, y in CGPoint(x: ox + (x - box.minX) * s, y: oy + (y - box.minY) * s) })
    }
}

/// The amber prompt chevron `›` (points toward the kaf; flips in RTL on purpose is NOT done — the mark is fixed art).
struct ChevronShape: Shape {
    func path(in rect: CGRect) -> Path {
        let m = LogoGrid.transform(in: rect).map
        var p = Path(); p.move(to: m(8, 30)); p.addLine(to: m(28, 50)); p.addLine(to: m(8, 70)); return p
    }
}

/// Kaf body: base + stem (one path, mitred corner).
struct KafBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        let m = LogoGrid.transform(in: rect).map
        var p = Path(); p.move(to: m(40, 82)); p.addLine(to: m(92, 82)); p.addLine(to: m(92, 9)); return p
    }
}

/// Kaf blade (the diagonal stroke).
struct KafBladeShape: Shape {
    func path(in rect: CGRect) -> Path {
        let m = LogoGrid.transform(in: rect).map
        var p = Path(); p.move(to: m(58, 36)); p.addLine(to: m(92, 14)); return p
    }
}

/// The madda / cursor block.
struct MaddaShape: Shape {
    func path(in rect: CGRect) -> Path {
        let m = LogoGrid.transform(in: rect).map
        var p = Path(); p.move(to: m(60, 55)); p.addLine(to: m(73, 62)); return p
    }
}

/// Fits a pre-built path (in horizontal-logo coordinates) into a rect, preserving aspect.
struct FittedPathShape: Shape {
    let source: Path
    func path(in rect: CGRect) -> Path {
        let b = source.boundingRect
        guard b.width > 0, b.height > 0 else { return Path() }
        let s = min(rect.width / b.width, rect.height / b.height)
        let ox = rect.midX - b.width * s / 2 - b.minX * s, oy = rect.midY - b.height * s / 2 - b.minY * s
        return source.applying(CGAffineTransform(a: s, b: 0, c: 0, d: s, tx: ox, ty: oy))
    }
}

enum Wordmark {
    static let arabicAspect: CGFloat = WordmarkPaths.arabic.boundingRect.width / WordmarkPaths.arabic.boundingRect.height
    static let latinAspect: CGFloat = WordmarkPaths.latin.boundingRect.width / WordmarkPaths.latin.boundingRect.height
}
