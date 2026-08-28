import PortAuthorityKit
import SwiftUI

/// The laptop-side connector, drawn face-on as it would look plugged in.
struct ConnectorView: View {
    let kind: PortKind
    let orientation: PlugOrientation
    let energised: Bool

    var body: some View {
        switch kind {
        case .usbC: usbC
        case .magSafe: magSafe
        case .unknown: unknownPort
        }
    }

    private var shellStroke: Color { energised ? Theme.metal : Theme.metal.opacity(0.55) }

    private var usbC: some View {
        // Outer shell is a true stadium; the tongue sits slightly off-centre
        // so a flipped cable is actually visible rather than implied.
        ZStack {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color.black.opacity(0.55), Color.black.opacity(0.25)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(Capsule().strokeBorder(shellStroke, lineWidth: 1.4))

            Capsule()
                .fill(Theme.contact.opacity(energised ? 0.85 : 0.4))
                .frame(width: 30, height: 4)
                .offset(y: tongueOffset)
        }
        .frame(width: 48, height: 17)
    }

    private var tongueOffset: CGFloat {
        switch orientation {
        case .normal: return -2.5
        case .flipped: return 2.5
        case .unknown: return 0
        }
    }

    private var magSafe: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.black.opacity(0.5), Color.black.opacity(0.22)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                        .strokeBorder(shellStroke, lineWidth: 1.4)
                )

            // Five contacts, matching the real connector.
            HStack(spacing: 3.5) {
                ForEach(0..<5, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill(Theme.contact.opacity(energised ? 0.9 : 0.42))
                        .frame(width: 4.5, height: 5)
                }
            }
        }
        .frame(width: 54, height: 13)
    }

    private var unknownPort: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .strokeBorder(Theme.idle, style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
            .frame(width: 48, height: 15)
    }
}

/// The machine's chassis edge, so the connector reads as plugged into
/// something rather than floating.
struct ChassisEdge: View {
    var body: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: 4, bottomLeadingRadius: 4,
            bottomTrailingRadius: 0, topTrailingRadius: 0,
            style: .continuous
        )
        .fill(
            LinearGradient(
                colors: [Theme.metal.opacity(0.42), Theme.metal.opacity(0.16)],
                startPoint: .leading, endPoint: .trailing
            )
        )
        .frame(width: 13)
    }
}
