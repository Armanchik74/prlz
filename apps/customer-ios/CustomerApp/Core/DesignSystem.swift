import SwiftUI

enum AppColor {
    static let ink = Color(red: 28 / 255, green: 35 / 255, blue: 31 / 255)
    static let muted = Color(red: 116 / 255, green: 128 / 255, blue: 122 / 255)
    static let paper = Color(red: 243 / 255, green: 241 / 255, blue: 233 / 255)
    static let surface = Color.white
    static let primary = Color(red: 31 / 255, green: 61 / 255, blue: 58 / 255)
    static let primaryTint = Color(red: 228 / 255, green: 235 / 255, blue: 230 / 255)
    static let accent = Color(red: 255 / 255, green: 106 / 255, blue: 61 / 255)
    static let accentTint = Color(red: 255 / 255, green: 230 / 255, blue: 219 / 255)
    static let success = Color(red: 47 / 255, green: 158 / 255, blue: 103 / 255)
    static let warning = Color(red: 217 / 255, green: 139 / 255, blue: 31 / 255)
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.black.opacity(0.07))
            }
    }
}

extension View {
    func appCard() -> some View { modifier(CardModifier()) }
}

extension Color {
    init(hex: String) {
        let value = Int(hex.dropFirst(), radix: 16) ?? 0
        self.init(
            red: Double((value >> 16) & 0xff) / 255,
            green: Double((value >> 8) & 0xff) / 255,
            blue: Double(value & 0xff) / 255
        )
    }
}
