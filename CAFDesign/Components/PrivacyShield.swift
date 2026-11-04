import SwiftUI

/// Covers the app in the App Switcher (customer data must not show in snapshots).
struct PrivacyShield: View {
    var body: some View { ZStack { Color.surface; LogoMark(size: 72) }.ignoresSafeArea() }
}
