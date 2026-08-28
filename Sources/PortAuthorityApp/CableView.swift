import SwiftUI

/// A stub of cable running from the connector toward the source, with
/// charge visibly flowing toward the machine when power is being drawn.
struct CableView: View {
    let energised: Bool
    /// 0...1, how hard the cable is working relative to the contract.
    let intensity: Double
    /// Passive 3A cables are drawn thinner than 5A / e-marked ones.
    let heavyGauge: Bool

    private var thickness: CGFloat { heavyGauge ? 13 : 9 }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.black.opacity(0.42), Color.black.opacity(0.26)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .overlay(
                        Capsule().strokeBorder(
                            energised ? Theme.liveDim.opacity(0.5) : Theme.idle,
                            lineWidth: 1
                        )
                    )
                    .frame(height: thickness)

                if energised {
                    flow(width: geometry.size.width)
                        .frame(height: thickness)
                        .clipShape(Capsule())
                }
            }
            .frame(height: geometry.size.height, alignment: .center)
        }
        .frame(height: thickness)
    }

    /// Dots travel right-to-left: power flows from the source into the machine,
    /// and showing it backwards would be a lie that people would notice.
    private func flow(width: CGFloat) -> some View {
        let spacing: CGFloat = 17
        let count = max(2, Int(width / spacing) + 2)
        let speed = 1.1 + intensity * 1.6

        return TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let phase = CGFloat((time * speed).truncatingRemainder(dividingBy: 1)) * spacing

            Canvas { context, size in
                for index in 0..<count {
                    let x = width - (CGFloat(index) * spacing - phase)
                    guard x > -spacing, x < width + spacing else { continue }
                    let dot = Path(
                        ellipseIn: CGRect(x: x - 2.5, y: size.height / 2 - 2.5, width: 5, height: 5)
                    )
                    context.fill(dot, with: .color(Theme.live.opacity(0.28 + intensity * 0.6)))
                }
            }
        }
    }
}
