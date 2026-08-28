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

/// Wattage formatting: always two or three significant digits, never one and
/// never four. 1.4, 5.7, 10, 85, 140 -- but not 6 and not 100.4.
enum Watts {
    static func short(_ value: Double) -> String {
        // Guard the boundary: 9.97 must not format as "10.0", which would be
        // three digits plus a decimal.
        value < 9.95
            ? String(format: "%.1f", value)
            : String(format: "%.0f", value)
    }

    static func short(_ value: Double?) -> String {
        value.map(short) ?? "--"
    }
}

extension View {
    /// Numbers in this UI change every two seconds; without fixed-width
    /// digits the whole layout twitches on each refresh.
    func readout(_ size: CGFloat, weight: Font.Weight = .medium) -> some View {
        font(.system(size: size, weight: weight, design: .rounded).monospacedDigit())
    }
}
