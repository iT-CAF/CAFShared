import SwiftUI

/// NOTE: the `arrow` asset points LEFT natively (verified on device screenshots): `IconView(.arrow)` is a FORWARD arrow (→ in LTR, ← in RTL); back buttons add `.scaleEffect(x: -1)`.
/// The 26 brand line icons (02_Icons/SVG) as template vector assets: `Icon.shield.image`.
enum Icon: String, CaseIterable {
    case alert, arrow, bell, braces, branch, calendar, check, chip, clock, code, database, device, external, file, folder
    case link, lock, mail, package, search, server, shield, sliders, terminal, upload, user

    /// Asset-catalog template image. Directional icons mirror in RTL (see `IconView`).
    var image: Image {
        Image("Icons/\(rawValue)").renderingMode(.template)
    }
}

struct IconView: View {
    let icon: Icon
    var size: CGFloat = 22
    var body: some View {
        icon.image.resizable().scaledToFit().scaleEffect(x: icon == .arrow && L10n.language != .ar ? -1 : 1)
            .frame(width: size, height: size).accessibilityHidden(true)
    }
}
