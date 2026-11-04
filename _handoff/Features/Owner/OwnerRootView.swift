import SwiftUI

/// The owner's face: sign in → business overview / team / account. Sits beside the cashier face; the role is chosen once and can be changed from the account screen.
struct OwnerRootView: View {
    @Bindable var store: OwnerStore
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        Group {
            switch store.phase {
            case .checking:
                ZStack { BrandBackground(); VStack(spacing: Space.m) { ProgressView().controlSize(.large); Text("common.loading").font(.brandSmall).foregroundStyle(Color.textMuted) } }
            case .signedOut:
                OwnerLoginView(store: store, onBack: { env.backToRoleChoice() })
            case .offline:
                ZStack { BrandBackground(); EmptyState(icon: .server, title: "err.offline_title", message: "err.offline_start", actionTitle: "common.retry") { Task { await store.bootstrap() } } }
            case .ready:
                OwnerShell(store: store)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: store.phase)
        .task { if store.phase != .ready { await store.bootstrap() } }
    }
}

struct OwnerLoginView: View {
    @Bindable var store: OwnerStore
    let onBack: () -> Void
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focus: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: Space.l) {
                VStack(spacing: Space.s) {
                    LogoMark(size: 64)
                    Text("owner.login_title").font(.brandTitle).foregroundStyle(Color.textPrimary).multilineTextAlignment(.center)
                    Text("owner.login_subtitle").font(.brandBody).foregroundStyle(Color.textMuted).multilineTextAlignment(.center)
                }.padding(.top, Space.xl)

                VStack(spacing: Space.s) {
                    FormField(label: "owner.email", text: $email, placeholder: "owner.email_placeholder", icon: .mail, keyboard: .emailAddress, contentType: .username, isLTRContent: true, submitLabel: .next, identifier: "owner.email")
                    FormField(label: "owner.password", text: $password, placeholder: "owner.password_placeholder", icon: .lock, isSecure: true, contentType: .password, isLTRContent: true, submitLabel: .go, onSubmit: submit, identifier: "owner.password")
                    if let e = store.loginError {
                        Text(verbatim: e).font(.brandSmall).foregroundStyle(Color.signal).frame(maxWidth: .infinity, alignment: .leading).accessibilityIdentifier("owner.error")
                    }
                    BrandButton(title: "owner.sign_in", isLoading: store.isSigningIn, action: submit).accessibilityIdentifier("owner.sign_in").padding(.top, Space.xs)
                }

                Text("owner.login_note").font(.brandCaption).foregroundStyle(Color.textMuted).multilineTextAlignment(.center)
                Button(action: onBack) { Text("owner.change_role").font(.brandSmall).foregroundStyle(Color.accentText) }.frame(minHeight: 44).accessibilityIdentifier("owner.back")
            }
            .padding(.horizontal, Space.gutter).frame(maxWidth: 520).frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(BrandBackground())
    }

    private func submit() { Task { await store.signIn(email: email, password: password) } }
}
