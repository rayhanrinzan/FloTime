import SwiftUI

enum FloTimeTheme {
    static let background = Color(red: 1.0, green: 0.98, blue: 0.95)
    static let surface = Color.white
    static let primary = Color(red: 0.95, green: 0.45, blue: 0.12)
    static let secondary = Color(red: 1.0, green: 0.72, blue: 0.46)
    static let accent = Color(red: 0.99, green: 0.84, blue: 0.70)
    static let text = Color(red: 0.20, green: 0.16, blue: 0.13)
    static let mutedText = Color(red: 0.45, green: 0.39, blue: 0.34)
}

struct PulseCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(FloTimeTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: FloTimeTheme.primary.opacity(0.08), radius: 20, x: 0, y: 10)
    }
}

extension View {
    func floTimeCard() -> some View {
        modifier(PulseCardModifier())
    }
}
