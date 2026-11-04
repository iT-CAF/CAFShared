import SwiftUI

/// Draw progress of every logo segment (0…1). `.complete` is the finished logo.
struct LogoProgress: Equatable {
    var chevron: CGFloat = 1
    var body: CGFloat = 1
    var blade: CGFloat = 1
    var madda: CGFloat = 1
    static let complete = LogoProgress()
    static let empty = LogoProgress(chevron: 0, body: 0, blade: 0, madda: 0)
}

/// The brand monogram as vector shapes. Static by default; the splash animates `progress`.
struct LogoMark: View {
    var size: CGFloat = 64
    var progress: LogoProgress = .complete
    /// Light-theme logos use amber-deep for the chevron; dark uses amber.
    var chevronColor: Color = .accent
    var inkColor: Color = .logoInk

    var body: some View {
        let u = size / LogoGrid.box.width
        ZStack {
            ChevronShape().trim(from: 0, to: progress.chevron)
                .stroke(chevronColor, style: StrokeStyle(lineWidth: LogoGrid.chevronWidth * u, lineCap: .butt, lineJoin: .miter, miterLimit: 10))
            KafBodyShape().trim(from: 0, to: progress.body)
                .stroke(inkColor, style: StrokeStyle(lineWidth: LogoGrid.kafWidth * u, lineCap: .butt, lineJoin: .miter, miterLimit: 10))
            KafBladeShape().trim(from: 0, to: progress.blade)
                .stroke(inkColor, style: StrokeStyle(lineWidth: LogoGrid.kafWidth * u, lineCap: .butt))
            MaddaShape().trim(from: 0, to: progress.madda)
                .stroke(inkColor, style: StrokeStyle(lineWidth: LogoGrid.maddaWidth * u, lineCap: .butt))
        }
        .frame(width: size, height: size)
        // The monogram is fixed art: never mirrored by layout direction.
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement()
        .accessibilityLabel("iT CAF")
        .accessibilityAddTraits(.isImage)
    }
}

/// «كآف» (Thmanyah wordmark path from the logo SVG).
struct ArabicWordmark: View {
    var height: CGFloat = 34
    var color: Color = .logoInk
    var body: some View {
        FittedPathShape(source: WordmarkPaths.arabic).fill(color)
            .frame(width: height * Wordmark.arabicAspect, height: height)
            .environment(\.layoutDirection, .leftToRight)   // shapes mirror in RTL; the wordmark is fixed art
            .accessibilityHidden(true)
    }
}

/// «iT CAF» (JetBrains Mono Bold path from the logo SVG).
struct LatinWordmark: View {
    var height: CGFloat = 12
    var color: Color = .logoInk
    var body: some View {
        FittedPathShape(source: WordmarkPaths.latin).fill(color)
            .frame(width: height * Wordmark.latinAspect, height: height)
            .environment(\.layoutDirection, .leftToRight)
            .accessibilityHidden(true)
    }
}

/// Horizontal lock-up used in headers: monogram + stacked wordmarks (RTL: mark on the right).
struct BrandLockup: View {
    var markSize: CGFloat = 40
    var body: some View {
        HStack(spacing: markSize * 0.22) {
            LogoMark(size: markSize)
            VStack(alignment: .leading, spacing: markSize * 0.06) {
                ArabicWordmark(height: markSize * 0.46)
                LatinWordmark(height: markSize * 0.15)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("app.name"))
    }
}

/// Terminal cursor block that blinks (static when Reduce Motion is on).
struct TerminalCursor: View {
    var width: CGFloat = 14
    var height: CGFloat = 4
    var color: Color = .accent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var on = true
    var body: some View {
        Rectangle().fill(color).frame(width: width, height: height)
            .opacity(on ? 1 : 0.1)
            .task(id: reduceMotion) {
                guard !reduceMotion else { on = true; return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(520))
                    on.toggle()
                }
            }
            .accessibilityHidden(true)
    }
}

/// 2px dots every 16px (`slate-line` on Graphite). Decorative background pattern.
struct DotGrid: View {
    var spacing: CGFloat = 16
    var dot: CGFloat = 2
    var color: Color = .hairline
    var body: some View {
        Canvas { ctx, size in
            var path = Path()
            var y: CGFloat = spacing / 2
            while y < size.height {
                var x: CGFloat = spacing / 2
                while x < size.width {
                    path.addRect(CGRect(x: x - dot / 2, y: y - dot / 2, width: dot, height: dot)); x += spacing
                }
                y += spacing
            }
            ctx.fill(path, with: .color(color))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
