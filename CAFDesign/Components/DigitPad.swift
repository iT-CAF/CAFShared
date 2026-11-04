import SwiftUI

/// Large 3×4 number pad with Latin digits (always LTR so the keys never mirror). Used for the PIN and the amount.
struct DigitPad: View {
    var allowsDecimal = false
    var keyHeight: CGFloat = 64
    let onDigit: (String) -> Void
    let onDelete: () -> Void
    var onDecimal: (() -> Void)? = nil

    var body: some View {
        let rows: [[String]] = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], [allowsDecimal ? "." : "", "0", "⌫"]]
        VStack(spacing: Space.s) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: Space.s) {
                    ForEach(row, id: \.self) { key in keyView(key) }
                }
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    @ViewBuilder private func keyView(_ key: String) -> some View {
        if key.isEmpty {
            Color.clear.frame(maxWidth: .infinity, minHeight: keyHeight)
        } else {
            Button {
                Haptics.selection()
                switch key { case "⌫": onDelete(); case ".": onDecimal?(); default: onDigit(key) }
            } label: {
                Group {
                    if key == "⌫" { Image(systemName: "delete.left").font(.system(size: 24, weight: .medium)) }
                    else { Text(verbatim: key).font(.brandMono(size: 28, bold: true)) }
                }
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, minHeight: keyHeight)
                .background(Color.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.control, style: .continuous).strokeBorder(Color.hairline))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(key == "⌫" ? Text("pad.delete") : key == "." ? Text("pad.decimal") : Text(verbatim: key))
            .accessibilityIdentifier("pad.\(key == "⌫" ? "delete" : key)")
        }
    }
}

/// Input rules of the amount typed on the pad: Latin digits, one dot, ≤ 2 decimals, ≤ 7 integer digits.
enum AmountInput {
    static func append(_ digit: String, to s: String) -> String {
        if s == "0" { return digit == "0" ? s : digit }
        let parts = s.split(separator: ".", omittingEmptySubsequences: false)
        if parts.count == 2 { return parts[1].count >= 2 ? s : s + digit }
        return parts[0].count >= 7 ? s : s + digit
    }
    static func decimal(_ s: String) -> String { s.contains(".") ? s : (s.isEmpty ? "0." : s + ".") }
    static func delete(_ s: String) -> String { String(s.dropLast()) }
    static func value(_ s: String) -> Double? { s.isEmpty ? nil : Double(s.hasSuffix(".") ? String(s.dropLast()) : s) }
    /// Normalises Arabic-Indic / Persian digits and separators a keyboard might have produced.
    static func latin(_ s: String) -> String {
        var out = ""
        for ch in s.unicodeScalars {
            switch ch.value {
            case 0x660...0x669: out.append(Character(UnicodeScalar(ch.value - 0x660 + 0x30)!))
            case 0x6F0...0x6F9: out.append(Character(UnicodeScalar(ch.value - 0x6F0 + 0x30)!))
            case 0x66B, 0x66C, 0x60C: out.append(".")
            default: out.unicodeScalars.append(ch)
            }
        }
        return out
    }
}
