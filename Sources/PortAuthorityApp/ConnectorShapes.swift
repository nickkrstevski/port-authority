import PortAuthorityKit
import SwiftUI

/// Shading helpers shared by the plug and the cable.
///
/// Everything here is drawn looking straight down at a round-ish object lying
/// horizontally, so the form is conveyed by a gradient running across the
/// band (top edge in shadow, specular highlight above centre, underside
/// falling off to dark). Gradients along the length would read as flat.
enum Material {
    static func cylinder(_ base: Color, specular: Double = 0.75) -> LinearGradient {
        LinearGradient(
            stops: [
                .init(color: base.opacity(0.55), location: 0.00),
                .init(color: base.opacity(0.88), location: 0.10),
                .init(color: Color.white.opacity(specular), location: 0.26),
                .init(color: base, location: 0.46),
                .init(color: base.opacity(0.72), location: 0.70),
                .init(color: Color.black.opacity(0.45), location: 0.93),
                .init(color: Color.black.opacity(0.62), location: 1.00),
            ],
            startPoint: .top, endPoint: .bottom
        )
    }

    /// Moulded cable and housing: Apple's are white, and a light neutral
    /// reads correctly against both panel backgrounds.
    static let shell = Color(white: 0.80)
    /// The metal receptacle shell, cooler and brighter than the plastic.
    static let steel = Color(red: 0.70, green: 0.72, blue: 0.75)
}

/// A plug seen from directly above: contact shell at the left pointing into
/// the machine, housing, then strain relief tapering into the cable.
///
/// Proportions follow the real connector. On USB-C the shell is 8.34mm across
/// against a ~12mm housing and a ~4mm cable, so from above the shell is nearly
/// as wide as the housing while the cable is markedly thinner. (Those same
/// parts in side elevation would be 2.56mm, 6mm and 4mm -- a much flatter
/// shape with a comparatively fat cable.)
struct TopDownPlug: View {
    let kind: PortKind
    let orientation: PlugOrientation
    let energised: Bool
    var dimmed: Bool = false

    /// Full width of the housing across the view; everything else is
    /// proportional to it.
    private var housingWidth: CGFloat { kind == .magSafe ? 34 : 30 }

    var body: some View {
        HStack(spacing: -4) {
            shell
            housing.zIndex(2)
            strainRelief.zIndex(1)
        }
        .frame(height: 38)
        .shadow(color: .black.opacity(dimmed ? 0.15 : 0.45), radius: 3.5, x: 0, y: 2.5)
        .saturation(dimmed ? 0 : 1)
        .opacity(dimmed ? 0.4 : 1)
    }

    // MARK: shell

    private var shell: some View {
        let across = housingWidth * (kind == .magSafe ? 1.0 : 0.70)
        let length: CGFloat = kind == .magSafe ? 17 : 25

        return RoundedRectangle(cornerRadius: kind == .magSafe ? 3 : 2.5, style: .continuous)
            .fill(Material.cylinder(Material.steel, specular: 0.9))
            .overlay(
                // The fold seam that runs the length of a drawn metal shell.
                Rectangle()
                    .fill(Color.black.opacity(0.16))
                    .frame(height: 0.75)
                    .offset(y: -across * 0.17)
            )
            .overlay(
                RoundedRectangle(cornerRadius: kind == .magSafe ? 3 : 2.5, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.30), lineWidth: 0.6)
            )
            .frame(width: length, height: across)
            .shadow(color: energised ? Theme.live.opacity(0.55) : .clear, radius: 6)
    }

    // MARK: housing

    private var housing: some View {
        ZStack(alignment: orientation == .flipped ? .bottom : .top) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Material.cylinder(Material.shell))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.22), lineWidth: 0.6)
                )

            // Orientation cannot be seen from above on a real connector, so
            // it is marked rather than faked: the pip sits on whichever face
            // is currently up.
            if orientation != .unknown {
                Capsule()
                    .fill(energised ? Theme.live : Color.black.opacity(0.28))
                    .frame(width: 13, height: 3)
                    .padding(.vertical, 4.5)
            }
        }
        .frame(width: kind == .magSafe ? 34 : 42, height: housingWidth)
    }

    // MARK: strain relief

    private var strainRelief: some View {
        Taper(leadingAcross: housingWidth * 0.78, trailingAcross: housingWidth * 0.44)
            .fill(Material.cylinder(Material.shell, specular: 0.6))
            .overlay(ribs)
            .frame(width: 17, height: housingWidth)
    }

    /// Moulded relief rings, which is what makes this section read as flexible
    /// rather than as more housing.
    private var ribs: some View {
        GeometryReader { geometry in
            let inset: CGFloat = 3
            ForEach(0..<3, id: \.self) { index in
                let x = inset + CGFloat(index) * ((geometry.size.width - inset * 2) / 3)
                Capsule()
                    .fill(Color.black.opacity(0.16))
                    .frame(width: 1.4, height: geometry.size.height * (0.62 - CGFloat(index) * 0.06))
                    .position(x: x, y: geometry.size.height / 2)
            }
        }
    }
}

/// A symmetric taper, used for the strain relief between housing and cable.
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

/// The machine's edge, seen from above: the plug disappears into it.
struct ChassisEdge: View {
    var dimmed: Bool = false

    var body: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: 6, bottomLeadingRadius: 6,
            bottomTrailingRadius: 2, topTrailingRadius: 2,
            style: .continuous
        )
        .fill(
            LinearGradient(
                colors: [
                    Theme.metal.opacity(0.20),
                    Theme.metal.opacity(0.48),
                    Theme.metal.opacity(0.26),
                ],
                startPoint: .top, endPoint: .bottom
            )
        )
        .overlay(
            // Lip of the port opening.
            Rectangle()
                .fill(Color.black.opacity(0.35))
                .frame(width: 1)
                .frame(maxWidth: .infinity, alignment: .trailing)
        )
        .frame(width: 17, height: 62)
        .opacity(dimmed ? 0.45 : 1)
    }
}
