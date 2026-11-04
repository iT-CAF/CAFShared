import SwiftUI
import UIKit

/// iT CAF colour tokens (04_Colors/tokens.json). Dark "Graphite" is primary; Bone is the light theme.
/// Raw palette first, then semantic tokens that resolve per interface style (and Increase Contrast).
enum Palette {
    static let graphite = UIColor(hex: 0x0E1113)
    static let deepSlate = UIColor(hex: 0x1A2024)
    static let slateLine = UIColor(hex: 0x2C343A)
    static let sunkenDark = UIColor(hex: 0x090B0C)
    static let bone = UIColor(hex: 0xEDE8DF)
    static let paper = UIColor(hex: 0xF6F3EE)
    static let boneDeep = UIColor(hex: 0xE2DBCF)
    static let lineLight = UIColor(hex: 0xCFC7BA)
    static let amber = UIColor(hex: 0xE8A33D)
    static let amberDeep = UIColor(hex: 0xB07220)
    static let amberInk = UIColor(hex: 0x8C5A12)
    static let verdigris = UIColor(hex: 0x3E8E7E)
    static let verdigrisLight = UIColor(hex: 0x5FB3A1)
    static let verdigrisInk = UIColor(hex: 0x2C6B5E)
    static let copper = UIColor(hex: 0xC2683A)
    static let copperLight = UIColor(hex: 0xDB8556)
    static let copperInk = UIColor(hex: 0x9E4F25)
    static let fogGray = UIColor(hex: 0x8A9399)
    static let fogInk = UIColor(hex: 0x596268)
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
    static func brand(dark: UIColor, light: UIColor, darkHC: UIColor? = nil, lightHC: UIColor? = nil) -> UIColor {
        UIColor { t in
            let hc = t.accessibilityContrast == .high
            if t.userInterfaceStyle == .dark { return hc ? (darkHC ?? dark) : dark }
            return hc ? (lightHC ?? light) : light
        }
    }
}

extension Color {
    /// Semantic tokens. Use these in views, never raw hex.
    static let surface        = Color(uiColor: .brand(dark: Palette.graphite, light: Palette.bone))
    static let surfaceRaised  = Color(uiColor: .brand(dark: Palette.deepSlate, light: Palette.paper))
    static let surfaceSunken  = Color(uiColor: .brand(dark: Palette.sunkenDark, light: Palette.boneDeep))
    /// Decorative hairlines only (1.5:1) — never the sole cue of a control.
    static let hairline       = Color(uiColor: .brand(dark: Palette.slateLine, light: Palette.lineLight, darkHC: Palette.fogGray, lightHC: Palette.fogInk))
    /// Control borders (≥3:1).
    static let lineStrong     = Color(uiColor: .brand(dark: Palette.fogGray, light: Palette.fogInk))
    static let textPrimary    = Color(uiColor: .brand(dark: Palette.bone, light: Palette.graphite))
    static let textMuted      = Color(uiColor: .brand(dark: Palette.fogGray, light: Palette.fogInk))
    /// Brand mark / icon amber.
    static let accent         = Color(uiColor: .brand(dark: Palette.amber, light: Palette.amberDeep))
    /// Accent as text (links, active labels).
    static let accentText     = Color(uiColor: .brand(dark: Palette.amber, light: Palette.amberInk))
    static let accentFill     = Color(uiColor: Palette.amber)
    static let onAccent       = Color(uiColor: Palette.graphite)
    static let success        = Color(uiColor: .brand(dark: Palette.verdigrisLight, light: Palette.verdigrisInk))
    static let successFill    = Color(uiColor: Palette.verdigris)
    static let signal         = Color(uiColor: .brand(dark: Palette.copperLight, light: Palette.copperInk))
    static let signalFill     = Color(uiColor: Palette.copper)
    /// Logo strokes: Bone on dark, Graphite on light.
    static let logoInk        = Color(uiColor: .brand(dark: Palette.bone, light: Palette.graphite))
    static let splashBackground = Color(uiColor: Palette.graphite)
}

enum Radius { static let card: CGFloat = 20, control: CGFloat = 14, chip: CGFloat = 10, sheet: CGFloat = 28 }
enum Space {
    static let xxs: CGFloat = 4, xs: CGFloat = 8, s: CGFloat = 12, m: CGFloat = 16, l: CGFloat = 24, xl: CGFloat = 32, xxl: CGFloat = 48
    /// Screen side gutter.
    static let gutter: CGFloat = 20
}
