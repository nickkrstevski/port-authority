import PortAuthorityKit
import SwiftUI

/// The plug seen from above: contact tip at the left, pointing into the
/// machine, with the overmold and strain relief stepping down toward the
/// cable on the right.
///
/// The sections butt together with a small negative overlap so their rounded
/// corners merge into one silhouette instead of showing seams.
struct TopDownPlug: View {
    let kind: PortKind
    let orientation: PlugOrientation
    let energised: Bool
    var dimmed: Bool = false

    var body: some View {
        HStack(spacing: -5) {
            tip
            overmold.zIndex(1)
            strainRelief
        }
        .frame(height: 34)
        .saturation(dimmed ? 0 : 1)
        .opacity(dimmed ? 0.45 : 1)
    }

    // MARK: sections

    /// The metal shell that actually enters the port. Rounded to a stadium at
    /// the leading edge; the vertical gradient reads as a cylindrical body.
    private var tip: some View {
        let size = tipSize
        return RoundedRectangle(cornerRadius: size.height / 2, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Theme.metal.opacity(0.95),
                        Theme.metal.opacity(0.55),
                        Theme.metal.opacity(0.8),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: size.height / 2, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.35), lineWidth: 0.75)
            )
            .frame(width: size.width, height: size.height)
            .shadow(color: energised ? Theme.live.opacity(0.5) : .clear, radius: 5)
    }

    private var tipSize: CGSize {
        switch kind {
        case .usbC: return CGSize(width: 34, height: 17)
        case .magSafe: return CGSize(width: 19, height: 25)
        case .unknown: return CGSize(width: 28, height: 17)
        }
    }

    /// The moulded housing you actually hold.
    private var overmold: some View {
        ZStack(alignment: orientationAlignment) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.20), Color.black.opacity(0.55)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.45), lineWidth: 0.75)
                )

            // Orientation is invisible from above on a real connector, so it
            // gets an explicit marker rather than a fake asymmetry: the pip
            // sits on whichever side is up.
            if orientation != .unknown {
                Capsule()
                    .fill(energised ? Theme.live.opacity(0.9) : Theme.idle)
                    .frame(width: 12, height: 3)
                    .padding(.vertical, 3.5)
            }
        }
        .frame(width: overmoldWidth, height: 34)
    }

    private var orientationAlignment: Alignment {
        orientation == .flipped ? .bottom : .top
    }

    private var overmoldWidth: CGFloat {
        switch kind {
        case .usbC: return 40
        case .magSafe: return 36
        case .unknown: return 36
        }
    }

    /// Tapers the silhouette down to cable diameter.
    private var strainRelief: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.12), Color.black.opacity(0.5)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.4), lineWidth: 0.75)
            )
            .frame(width: 17, height: 22)
    }
}

/// The machine's chassis edge, so the plug reads as inserted into something
/// rather than floating in space.
struct ChassisEdge: View {
    var dimmed: Bool = false

    var body: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: 5, bottomLeadingRadius: 5,
            bottomTrailingRadius: 1, topTrailingRadius: 1,
            style: .continuous
        )
        .fill(
            LinearGradient(
                colors: [Theme.metal.opacity(0.45), Theme.metal.opacity(0.14)],
                startPoint: .leading, endPoint: .trailing
            )
        )
        .frame(width: 14, height: 58)
        .opacity(dimmed ? 0.4 : 1)
    }
}
