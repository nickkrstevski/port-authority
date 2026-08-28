import SwiftUI

/// A run of cable seen from above, with charge visibly moving toward the
/// machine while power is being drawn.
struct CableView: View {
    let energised: Bool
    /// 0...1, how hard the cable is working relative to the contract.
    let intensity: Double
    /// 5A / e-marked cables are physically thicker than 3A ones.
    let heavyGauge: Bool
    var dimmed: Bool = false

    @Environment(\.colorScheme) private var scheme

    /// From above a ~4mm cable is a third the width of the ~12mm housing it
    /// leaves. That ratio is the clearest signal that this is a top view and
    /// not a side elevation, where the same cable would be two thirds of it.
    private var thickness: CGFloat { PlugMetrics.cableAcross(heavyGauge: heavyGauge) }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Capsule()
                    .fill(Material.roundCable(Material.cable(scheme), scheme: scheme))
                    .overlay(
                        Capsule().strokeBorder(
                            scheme == .dark
                                ? Color.black.opacity(0.28)
                                : Color.white.opacity(0.12),
                            lineWidth: 0.6
                        )
                    )
                    .frame(height: thickness)

                if energised && !dimmed {
                    flow(width: geometry.size.width)
                        .frame(height: thickness)
                        .clipShape(Capsule())
                        .allowsHitTesting(false)
                }
            }
            .frame(height: geometry.size.height, alignment: .center)
        }
        .frame(height: thickness)
        .shadow(color: .black.opacity(dimmed ? 0.12 : 0.35), radius: 2.5, x: 0, y: 2)
        .saturation(dimmed ? 0 : 1)
        .opacity(dimmed ? 0.4 : 1)
    }

    /// Charge travels right-to-left: power flows from the source into the
    /// machine, and animating it the other way would be a lie people notice.
    ///
    /// Drawn additively so it reads as light within the cable rather than
    /// as markings painted on top of it.
    private func flow(width: CGFloat) -> some View {
        let spacing: CGFloat = 34
        let count = max(2, Int(width / spacing) + 2)
        let speed = 1.0 + intensity * 1.7

        return TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let phase = CGFloat((time * speed).truncatingRemainder(dividingBy: 1)) * spacing

            Canvas { context, size in
                context.addFilter(.blur(radius: 3.4))
                for index in 0..<count {
                    let x = width - (CGFloat(index) * spacing - phase)
                    guard x > -spacing, x < width + spacing else { continue }
                    let height = thickness * 0.22
                    let rect = CGRect(
                        x: x - 9, y: size.height / 2 - height / 2,
                        width: 18, height: height
                    )
                    context.fill(
                        Capsule().path(in: rect),
                        with: .color(Theme.live.opacity(0.16 + intensity * 0.16))
                    )
                }
            }
            .blendMode(.plusLighter)
        }
    }
}
