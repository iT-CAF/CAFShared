import SwiftUI
import UIKit

/// Minimal SVG path parser: m/M l/L h/H v/V c/C z (what the website's four lines use). Pure → unit-testable.
enum SVGPathParser {
    static func parse(_ d: String) -> Path {
        var tokens: [String] = []
        var cur = ""
        func flush() { if !cur.isEmpty { tokens.append(cur); cur = "" } }
        for ch in d {
            if ch.isLetter { flush(); tokens.append(String(ch)) }
            else if ch == "," || ch == " " || ch == "\n" { flush() }
            else if ch == "-" { flush(); cur = "-" }
            else { cur.append(ch) }
        }
        flush()
        var path = Path()
        var p = CGPoint.zero, start = CGPoint.zero
        var cmd: Character = "m"
        var i = 0
        func num() -> CGFloat? { guard i < tokens.count, let v = Double(tokens[i]) else { return nil }; i += 1; return CGFloat(v) }
        while i < tokens.count {
            if let c = tokens[i].first, c.isLetter, tokens[i].count == 1 { cmd = c; i += 1; if c == "z" || c == "Z" { path.closeSubpath(); p = start; continue } }
            let rel = cmd.isLowercase
            switch cmd.lowercased().first! {
            case "m":
                guard let x = num(), let y = num() else { return path }
                p = rel ? CGPoint(x: p.x + x, y: p.y + y) : CGPoint(x: x, y: y); start = p; path.move(to: p)
                cmd = rel ? "l" : "L"
            case "l":
                guard let x = num(), let y = num() else { return path }
                p = rel ? CGPoint(x: p.x + x, y: p.y + y) : CGPoint(x: x, y: y); path.addLine(to: p)
            case "h":
                guard let x = num() else { return path }
                p.x = rel ? p.x + x : x; path.addLine(to: p)
            case "v":
                guard let y = num() else { return path }
                p.y = rel ? p.y + y : y; path.addLine(to: p)
            case "c":
                guard let x1 = num(), let y1 = num(), let x2 = num(), let y2 = num(), let x = num(), let y = num() else { return path }
                let o = rel ? p : .zero
                let c1 = CGPoint(x: o.x + x1, y: o.y + y1), c2 = CGPoint(x: o.x + x2, y: o.y + y2), e = CGPoint(x: o.x + x, y: o.y + y)
                path.addCurve(to: e, control1: c1, control2: c2); p = e
            default: return path
            }
        }
        return path
    }
}

/// Shared, non-observed state read by the canvas every frame (no SwiftUI invalidation on scroll).
final class FlowMotion: @unchecked Sendable {
    static let shared = FlowMotion()
    /// 0…1 scroll progress of the screen currently on top.
    var progress: CGFloat = 0
}

/// Finds the scroll view next to this (background) view and mirrors its progress into `FlowMotion`.
private struct ScrollProgressProbe: UIViewRepresentable {
    func makeUIView(context: Context) -> ProbeView { ProbeView() }
    func updateUIView(_ uiView: ProbeView, context: Context) {}

    final class ProbeView: UIView {
        private var observation: NSKeyValueObservation?
        private weak var scroll: UIScrollView?
        override init(frame: CGRect) { super.init(frame: frame); isUserInteractionEnabled = false; isAccessibilityElement = false }
        required init?(coder: NSCoder) { fatalError() }
        override func didMoveToWindow() {
            super.didMoveToWindow()
            observation = nil
            guard window != nil else { return }
            for delay in [0.05, 0.4, 1.2] { DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.attach() } }
        }
        private func firstScroll(in v: UIView) -> UIScrollView? {
            if let s = v as? UIScrollView, !(s is UITableView && s.bounds.height < 2), s.bounds.width > 100 { return s }
            for sub in v.subviews { if let s = firstScroll(in: sub) { return s } }
            return nil
        }
        private func attach() {
            guard scroll == nil || observation == nil, window != nil else { return }
            var v: UIView = self
            while let up = v.superview {
                if let s = firstScroll(in: up) {
                    scroll = s
                    observation = s.observe(\.contentOffset, options: [.new]) { sv, _ in
                        let maxY = sv.contentSize.height + sv.adjustedContentInset.bottom - sv.bounds.height
                        let y = sv.contentOffset.y + sv.adjustedContentInset.top
                        FlowMotion.shared.progress = maxY > 0 ? min(1, max(0, y / maxY)) : 0
                    }
                    return
                }
                v = up
            }
        }
    }
}

struct FlowingLinesLayer: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var phase
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

    private static let paths: [(Path, CGFloat, [CGFloat])] = FlowingLinesData.lines.map { (SVGPathParser.parse($0.path), $0.width, $0.dash) }

    var body: some View {
        let active = phase == .active
        // 8%-opacity strokes drifting at 7 pt/s do not need more than 20 fps; every redraw is main-thread work competing with scrolling.
        let interval = lowPower ? 1.0 / 10 : 1.0 / 20
        TimelineView(.animation(minimumInterval: interval, paused: reduceMotion || !active)) { tl in
            Canvas(rendersAsynchronously: true) { ctx, size in      // rasterised off the main thread
                let t = reduceMotion ? 0 : tl.date.timeIntervalSinceReferenceDate
                draw(ctx, size, offset: -(2600 * FlowMotion.shared.progress) - CGFloat(t.truncatingRemainder(dividingBy: 100_000)) * 7)
            }
        }
        .background(ScrollProgressProbe().allowsHitTesting(false))
        .opacity(scheme == .dark ? 0.08 : 0.11)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled }
    }

    private func draw(_ ctx: GraphicsContext, _ size: CGSize, offset: CGFloat) {
        let vb = FlowingLinesData.viewBox
        let width = min(1150, size.width * 1.35)
        let s = width / vb.width
        var c = ctx
        c.translateBy(x: (size.width - width) / 2, y: -40)
        c.scaleBy(x: s, y: s)
        let color = scheme == .dark ? Color.accent : Color.accent
        for (path, w, dash) in Self.paths {
            let period = dash.reduce(0, +)
            var phase = offset.truncatingRemainder(dividingBy: period)
            if phase < 0 { phase += period }
            c.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: w, lineCap: .round, dash: dash, dashPhase: phase))
        }
    }
}
