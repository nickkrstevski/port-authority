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

    /// Moulded cable and housing, inverted against the panel: white cable on
    /// a dark panel, black cable on a light one, so it always separates from
    /// the background.
    static func cable(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(white: 0.85) : Color(white: 0.15)
    }

    /// A dark cable would be blown out by the same highlight that a white one
    /// needs, so gloss scales with the base.
    static func gloss(_ scheme: ColorScheme) -> Double {
        scheme == .dark ? 0.70 : 0.40
    }

    /// Edge shading. On a pale cable the form is described by darkening the
    /// edges; on a dark one there is no headroom left below the base, so the
    /// edges are carried by the highlight falling away instead.
    private static func edge(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.black.opacity(0.55) : Color.black.opacity(0.85)
    }

    /// A flat-topped moulding seen from above. The housing of a USB-C plug is
    /// a slab with softened edges, not a barrel: almost the entire visible
    /// face is one even tone, with a thin highlight near the upper edge and a
    /// narrow shadow at the lower one. A broad specular through the middle is
    /// what made this read as a cylindrical barrel jack.
    static func topFace(_ base: Color, scheme: ColorScheme, specular: Double? = nil) -> LinearGradient {
        let gloss = (specular ?? Material.gloss(scheme)) * 0.42
        return LinearGradient(
            stops: [
                .init(color: edge(scheme).opacity(0.45), location: 0.000),
                .init(color: base.opacity(0.80), location: 0.055),
                .init(color: Color.white.opacity(gloss), location: 0.120),
                .init(color: base.opacity(0.99), location: 0.220),
                .init(color: base, location: 0.500),
                .init(color: base.opacity(0.96), location: 0.760),
                .init(color: base.opacity(0.78), location: 0.900),
                .init(color: edge(scheme).opacity(0.45), location: 0.965),
                .init(color: edge(scheme).opacity(0.85), location: 1.000),
            ],
            startPoint: .top, endPoint: .bottom
        )
    }

    /// A round cable is a genuinely circular cross-section, so unlike the
    /// flattened housing it gets a narrow specular line and falls away hard to
    /// both edges. Using the flat-top gradient here made it read as a strip of
    /// tape rather than a wire.
    static func roundCable(_ base: Color, scheme: ColorScheme) -> LinearGradient {
        let gloss = Material.gloss(scheme)
        return LinearGradient(
            stops: [
                .init(color: edge(scheme).opacity(0.75), location: 0.00),
                .init(color: base.opacity(0.55), location: 0.13),
                .init(color: base.opacity(0.92), location: 0.24),
                .init(color: Color.white.opacity(gloss), location: 0.31),
                .init(color: base.opacity(0.96), location: 0.42),
                .init(color: base.opacity(0.74), location: 0.60),
                .init(color: base.opacity(0.40), location: 0.78),
                .init(color: edge(scheme).opacity(0.80), location: 0.92),
                .init(color: edge(scheme), location: 1.00),
            ],
            startPoint: .top, endPoint: .bottom
        )
    }

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
    var heavyGauge: Bool = false

    @Environment(\.colorScheme) private var scheme

    private var metrics: PlugMetrics { .forKind(kind) }
    private var body_: Color { Material.cable(scheme) }

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
            .fill(Material.topFace(Material.steel, scheme: scheme, specular: 0.88))
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
                .fill(Material.topFace(body_, scheme: scheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                        .strokeBorder(
                            scheme == .dark ? Color.black.opacity(0.20) : Color.white.opacity(0.14),
                            lineWidth: 0.6
                        )
                )

            // Orientation is genuinely invisible from above, so it is marked
            // rather than faked: the pip sits on whichever face is up.
            if orientation != .unknown {
                Capsule()
                    .fill(energised ? Theme.live : (scheme == .dark ? Color.black.opacity(0.26) : Color.white.opacity(0.30)))
                    .frame(width: 13, height: 3)
                    .padding(.vertical, 4.5)
            }
        }
        .frame(width: metrics.housingLong, height: metrics.housingAcross)
    }

    private var strainRelief: some View {
        Taper(
            leadingAcross: metrics.housingAcross * 0.76,
            trailingAcross: PlugMetrics.cableAcross(heavyGauge: heavyGauge)
        )
        .fill(Material.topFace(body_, scheme: scheme, specular: Material.gloss(scheme) * 0.8))
        .overlay(ribs)
        .frame(width: metrics.reliefLong, height: metrics.housingAcross)
    }

    private var ribs: some View {
        GeometryReader { geometry in
            ForEach(0..<3, id: \.self) { index in
                let step = (geometry.size.width - 5) / 3
                Capsule()
                    .fill(scheme == .dark ? Color.black.opacity(0.15) : Color.white.opacity(0.16))
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

/// The machine's side wall, seen from above.
///
/// Top and bottom fade out instead of ending in a hard edge: the laptop
/// continues past the frame in both directions, and a finite slab read as a
/// small block parked next to the plug rather than as the side of a machine.
struct MachineBody: View {
    let portKind: PortKind
    var dimmed: Bool = false

    private var slotAcross: CGFloat {
        PlugMetrics.forKind(portKind).shellAcross
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            UnevenRoundedRectangle(
                topLeadingRadius: 0, bottomLeadingRadius: 0,
                bottomTrailingRadius: 7, topTrailingRadius: 7,
                style: .continuous
            )
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: Material.aluminium.opacity(0.24), location: 0.00),
                        .init(color: Material.aluminium.opacity(0.50), location: 0.40),
                        .init(color: Material.aluminium.opacity(0.40), location: 0.78),
                        .init(color: Material.aluminium.opacity(0.22), location: 1.00),
                    ],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            // The machined chamfer along the outer edge, catching light.
            .overlay(alignment: .trailing) {
                LinearGradient(
                    colors: [Color.white.opacity(0.06), Color.white.opacity(0.34), Color.white.opacity(0.06)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(width: 1.2)
            }

            // A hint of the opening at the outer edge, no wider than the
            // shell that fills it. A deep notch drew the eye to a hole rather
            // than to the plug sitting in it.
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(Color.black.opacity(0.34))
                .frame(width: 3.5, height: slotAcross)
                .offset(x: 1.5)
        }
        .frame(width: 40, height: 132)
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.00),
                    .init(color: .black, location: 0.30),
                    .init(color: .black, location: 0.70),
                    .init(color: .clear, location: 1.00),
                ],
                startPoint: .top, endPoint: .bottom
            )
        )
        .opacity(dimmed ? 0.5 : 1)
    }
}
