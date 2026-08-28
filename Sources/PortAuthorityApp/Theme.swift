import SwiftUI

enum Theme {
    /// Power is the one thing this app is about, so it gets the only
    /// saturated colour in the palette. Everything else stays neutral.
    static let live = Color(red: 1.00, green: 0.74, blue: 0.26)
    static let liveDim = Color(red: 0.82, green: 0.56, blue: 0.13)
    static let idle = Color.secondary.opacity(0.35)
    static let metal = Color(red: 0.62, green: 0.64, blue: 0.68)
    static let contact = Color(red: 0.90, green: 0.76, blue: 0.42)

    static let panelWidth: CGFloat = 372

    static func accent(forWatts watts: Double?) -> Color {
        guard let watts, watts > 0.5 else { return idle }
        return live
    }
}

extension View {
    /// Numbers in this UI change every two seconds; without fixed-width
    /// digits the whole layout twitches on each refresh.
    func readout(_ size: CGFloat, weight: Font.Weight = .medium) -> some View {
        font(.system(size: size, weight: weight, design: .rounded).monospacedDigit())
    }
}
