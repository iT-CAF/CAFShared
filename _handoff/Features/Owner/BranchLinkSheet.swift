import SwiftUI
import CoreImage.CIFilterBuiltins

/// A branch's private cashier link: QR (to scan from the cashier's phone), copy, share, open it here as a cashier, and — owner only — replace it.
struct BranchLinkSheet: View {
    let name: String
    let url: String
    let rotate: (() -> Void)?
    var active: Bool? = nil
    var toggle: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var env
    @State private var copied = false
    @State private var showQR = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Space.m) {
                    if showQR, let img = QRCode.image(url) {
                        Image(uiImage: img).interpolation(.none).resizable().scaledToFit().frame(width: 220, height: 220)
                            .padding(Space.s).background(Color.white, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                            .accessibilityLabel(Text("owner.qr_a11y")).accessibilityIdentifier("owner.qr")
                    }
                    Text("owner.link_hint").font(.brandSmall).foregroundStyle(Color.textMuted).multilineTextAlignment(.center)
                    Text(verbatim: CashierLink.masked(CashierLink.token(from: url) ?? "").ltr).font(.brandMonoSmall).foregroundStyle(Color.textMuted)

                    VStack(spacing: Space.xs) {
                        HStack(spacing: Space.xs) {
                            BrandButton(title: copied ? "owner.copied" : "owner.copy_link", icon: .link, kind: .secondary) { SecretClipboard.copy(url); copied = true }.accessibilityIdentifier("owner.copy_link")
                            if let u = URL(string: url) {
                                ShareLink(item: u) { Label("owner.share", systemImage: "square.and.arrow.up") }
                                    .buttonStyle(BrandButtonStyle(kind: .secondary, isLoading: false, fullWidth: true)).accessibilityIdentifier("owner.share_link")
                            }
                        }
                        if let token = CashierLink.token(from: url) {
                            BrandButton(title: "owner.open_as_cashier", icon: .device) { dismiss(); env.openBranch(token: token) }.accessibilityIdentifier("owner.open_cashier")
                        }
                        if let toggle, let active {
                            BrandButton(title: active ? "owner.deactivate_branch" : "owner.activate_branch", kind: .secondary) { toggle() }.accessibilityIdentifier("owner.toggle_branch")
                        }
                        if let rotate {
                            BrandButton(title: "owner.rotate", icon: .lock, kind: .destructive) { rotate() }.accessibilityIdentifier("owner.rotate")
                        }
                    }
                    if rotate != nil { Text("owner.rotate_note").font(.brandCaption).foregroundStyle(Color.textMuted).multilineTextAlignment(.center) }
                }
                .padding(Space.gutter)
            }
            .background(Color.surface).brandNavTitle(verbatim: name)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("common.done") { dismiss() } } }
        }
    }
}

enum QRCode {
    /// Black on white, no smoothing: scans reliably from a phone in either appearance.
    static func image(_ text: String) -> UIImage? {
        let f = CIFilter.qrCodeGenerator()
        f.message = Data(text.utf8); f.correctionLevel = "M"
        guard let out = f.outputImage else { return nil }
        let scaled = out.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cg = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

@MainActor enum SecretClipboard {
    /// Links and PINs are secrets: this device only (no Universal Clipboard), gone after a minute.
    static func copy(_ s: String) {
        UIPasteboard.general.setItems([[UIPasteboard.typeAutomatic: s]], options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(60)])
        Haptics.success()
    }
}
