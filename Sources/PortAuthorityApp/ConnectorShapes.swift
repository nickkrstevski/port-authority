import PortAuthorityKit
import SwiftUI

/// Shading for objects seen from directly above.
///
/// A USB-C plug is a flattened body, so from above most of what you see is a
/// broad, nearly flat top face with the form falling away only near the two
/// long edges. The gradient therefore holds a wide bright plateau through the
/// middle and darkens late. Narrow highlights with heavy falloff read as a
/// circular tube seen side-on, which is the wrong view entirely.
enum Material {
    static func topFace(_ base: Color, specular: Double = 0.70) -> LinearGradient {
        LinearGradient(
            stops: [
                .init(color: base.opacity(0.50), location: 0.00),
                .init(color: base.opacity(0.86), location: 0.09),
                .init(color: Color.white.opacity(specular), location: 0.21),
                .init(color: base, location: 0.34),
                .init(color: base.opacity(0.95), location: 0.62),
                .init(color: base.opacity(0.66), location: 0.82),
                .init(color: Color.black.opacity(0.34), location: 0.94),
                .init(color: Color.black.opacity(0.55), location: 1.00),
            ],
            startPoint: .top, endPoint: .bottom
        )
    }

    static let shell = Color(white: 0.82)
    static let steel = Color(red: 0.71, green: 0.73, blue: 0.76)
    static let aluminium = Color(red: 0.55, green: 0.57, blue: 0.60)
}

/// Real plug dimensions in millimetres, rendered at a fixed scale.
///
/// Getting these right is what separates the two views. Seen from above a
/// USB-C plug is 8.34mm shell / 12mm housing / 4mm cable, so the shell is
/// nearly as wide as the housing and the cable is a third of it. The same
/// parts in side elevation are 2.56 / 6 / 4, where the cable is two thirds of
/// the housing and the shell is a thin lip. Cable-to-housing ratio is the
/// single strongest cue for which view the reader is looking at.
struct PlugMetrics {
    var shellAcross: CGFloat
    var shellLong: CGFloat
    var shellRadius: CGFloat
    var housingAcross: CGFloat
    var housingLong: CGFloat
    var reliefLong: CGFloat

    static let scale: CGFloat = 2.5

    static func forKind(_ kind: PortKind) -> PlugMetrics {
        switch kind {
        case .magSafe:
            // The MagSafe head is the widest part and much shorter than a
            // USB-C shell; it sits proud of the housing behind it.
            return PlugMetrics(
                shellAcross: 15.0 * scale, shellLong: 8.5 * scale, shellRadius: 2.0 * scale,
                housingAcross: 11.5 * scale, housingLong: 15.0 * scale,
                reliefLong: 6.0 * scale
            )
        case .usbC, .unknown:
            return PlugMetrics(
                shellAcross: 8.34 * scale, shellLong: 6.5 * scale, shellRadius: 1.0 * scale,
                housingAcross: 12.0 * scale, housingLong: 17.5 * scale,
                reliefLong: 7.0 * scale
            )
        }
    }

    /// Cable diameter for the gauge, in the same scale.
    static func cableAcross(heavyGauge: Bool) -> CGFloat {
        (heavyGauge ? 4.8 : 4.0) * scale
    }
}

/// A plug seen from directly above, as it sits when plugged into the side of
/// an open laptop and you look straight down at the keyboard plane.
struct TopDownPlug: View {
    let kind: PortKind
    let orientation: PlugOrientation
    let energised: Bool
    var dimmed: Bool = false

    private var metrics: PlugMetrics { .forKind(kind) }

    var body: some View {
        HStack(spacing: -3) {
            shell
            housing.zIndex(2)
            strainRelief.zIndex(1)
        }
        .frame(height: 42)
        .shadow(color: .black.opacity(dimmed ? 0.14 : 0.42), radius: 3.5, x: 0, y: 3)
        .saturation(dimmed ? 0 : 1)
        .opacity(dimmed ? 0.4 : 1)
    }

    private var shell: some View {
        RoundedRectangle(cornerRadius: metrics.shellRadius, style: .continuous)
            .fill(Material.topFace(Material.steel, specular: 0.88))
            .overlay(
                // Seam along the drawn metal shell.
                Rectangle()
                    .fill(Color.black.opacity(0.15))
                    .frame(height: 0.75)
                    .offset(y: -metrics.shellAcross * 0.16)
            )
            .overlay(
                RoundedRectangle(cornerRadius: metrics.shellRadius, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.28), lineWidth: 0.6)
            )
            .frame(width: metrics.shellLong, height: metrics.shellAcross)
            .shadow(color: energised ? Theme.live.opacity(0.5) : .clear, radius: 6)
    }

    private var housing: some View {
        ZStack(alignment: orientation == .flipped ? .bottom : .top) {
            RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                .fill(Material.topFace(Material.shell))
                .overlay(
                    RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.20), lineWidth: 0.6)
                )

            // Orientation is genuinely invisible from above, so it is marked
            // rather than faked: the pip sits on whichever face is up.
            if orientation != .unknown {
                Capsule()
                    .fill(energised ? Theme.live : Color.black.opacity(0.26))
                    .frame(width: 13, height: 3)
                    .padding(.vertical, 4.5)
            }
        }
        .frame(width: metrics.housingLong, height: metrics.housingAcross)
    }

    private var strainRelief: some View {
        Taper(
            leadingAcross: metrics.housingAcross * 0.76,
            trailingAcross: PlugMetrics.cableAcross(heavyGauge: false) + 2
        )
        .fill(Material.topFace(Material.shell, specular: 0.58))
        .overlay(ribs)
        .frame(width: metrics.reliefLong, height: metrics.housingAcross)
    }

    private var ribs: some View {
        GeometryReader { geometry in
            ForEach(0..<3, id: \.self) { index in
                let step = (geometry.size.width - 5) / 3
                Capsule()
                    .fill(Color.black.opacity(0.15))
                    .frame(width: 1.3, height: geometry.size.height * (0.58 - CGFloat(index) * 0.07))
                    .position(x: 3 + CGFloat(index) * step, y: geometry.size.height / 2)
            }
        }
    }
}

/// A symmetric taper, used between housing and cable.
struct Taper: Shape {
    var leadingAcross: CGFloat
    var trailingAcross: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY
        let lead = leadingAcross / 2
        let trail = trailingAcross / 2
        path.move(to: CGPoint(x: rect.minX, y: midY - lead))
        path.addLine(to: CGPoint(x: rect.maxX, y: midY - trail))
        path.addLine(to: CGPoint(x: rect.maxX, y: midY + trail))
        path.addLine(to: CGPoint(x: rect.minX, y: midY + lead))
        path.closeSubpath()
        return path
    }
}

/// The laptop, seen from above: its top case fills the left of the diagram and
/// runs off the edge of the panel, with the port cut into its outer wall.
///
/// The previous version was a narrow vertical bar, which reads as an edge seen
/// side-on and made the whole scene look like a side elevation regardless of
/// how the plug was drawn.
struct MachineBody: View {
    let portKind: PortKind
    var dimmed: Bool = false

    private var slotAcross: CGFloat {
        PlugMetrics.forKind(portKind).shellAcross + 2
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            UnevenRoundedRectangle(
                topLeadingRadius: 0, bottomLeadingRadius: 0,
                bottomTrailingRadius: 9, topTrailingRadius: 9,
                style: .continuous
            )
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: Material.aluminium.opacity(0.30), location: 0.00),
                        .init(color: Material.aluminium.opacity(0.52), location: 0.30),
                        .init(color: Material.aluminium.opacity(0.44), location: 0.72),
                        .init(color: Material.aluminium.opacity(0.22), location: 1.00),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )

            // Chamfered outer edge catching the light.
            UnevenRoundedRectangle(
                topLeadingRadius: 0, bottomLeadingRadius: 0,
                bottomTrailingRadius: 9, topTrailingRadius: 9,
                style: .continuous
            )
            .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)

            // The port cut into the outer wall, mostly hidden by the plug.
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.black.opacity(0.62))
                .frame(width: 8, height: slotAcross)
                .offset(x: 1)
        }
        .frame(width: 40, height: 84)
        .opacity(dimmed ? 0.5 : 1)
    }
}
