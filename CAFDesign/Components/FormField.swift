import SwiftUI

/// Labelled input: sunken well, ≥3:1 border, amber focus ring, inline error. Secure variant gets a reveal toggle.
struct FormField: View {
    let label: LocalizedStringKey
    @Binding var text: String
    var placeholder: LocalizedStringKey = ""
    var icon: Icon? = nil
    var isSecure = false
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    var capitalization: TextInputAutocapitalization = .never
    /// Forces LTR rendering (emails, phone numbers) inside RTL screens.
    var isLTRContent = false
    var error: String? = nil
    var submitLabel: SubmitLabel = .next
    var onSubmit: (() -> Void)? = nil
    var identifier: String? = nil

    @State private var reveal = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.brandCaption).foregroundStyle(Color.textMuted)
            HStack(spacing: Space.s) {
                if let icon { IconView(icon: icon, size: 20).foregroundStyle(focused ? Color.accent : Color.textMuted) }
                field
                    .accessibilityLabel(Text(label))
                    .accessibilityIdentifier(identifier ?? "")
                    .focused($focused)
                    .font(isLTRContent ? .brandMono : .brandBody)
                    .foregroundStyle(Color.textPrimary)
                    .tint(Color.accent)
                    .keyboardType(keyboard)
                    .textContentType(contentType)
                    .textInputAutocapitalization(capitalization)
                    .autocorrectionDisabled(isSecure || keyboard != .default)
                    .submitLabel(submitLabel)
                    .onSubmit { onSubmit?() }
                    .environment(\.layoutDirection, isLTRContent ? .leftToRight : L10n.language.layoutDirection)
                    .multilineTextAlignment(.leading)
                if isSecure {
                    Button { reveal.toggle() } label: {
                        Image(systemName: reveal ? "eye.slash" : "eye").foregroundStyle(Color.textMuted).frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(Text(reveal ? "field.hide_password" : "field.show_password"))
                }
            }
            .padding(.horizontal, Space.m)
            .frame(minHeight: 54)
            .background(Color.surfaceSunken, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                .strokeBorder(error != nil ? Color.signal : (focused ? Color.accent : Color.lineStrong.opacity(0.7)), lineWidth: focused || error != nil ? 2 : 1))
            .contentShape(Rectangle())
            .onTapGesture { focused = true }
            if let error {
                HStack(spacing: 6) { IconView(icon: .alert, size: 14); Text(error).font(.brandCaption) }
                    .foregroundStyle(Color.signal).accessibilityLabel(Text(error))
            }
        }
    }

    @ViewBuilder private var field: some View {
        if isSecure && !reveal { SecureField(placeholder, text: $text) } else { TextField(placeholder, text: $text) }
    }
}
