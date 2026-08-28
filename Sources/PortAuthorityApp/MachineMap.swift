import PortAuthorityKit
import SwiftUI

/// The machine seen from above, with its ports drawn where they physically
/// are, and the connected one lit.
///
/// Which edge each port sits on, and its order along that edge, come from the
/// `port-location` property Apple publishes on the device tree, so this
/// follows whatever machine it runs on. Only two things are conventions
/// rather than data: MagSafe carries no `port-location` and is placed as the
/// rearmost left port, and the spacing between ports along an edge is even
/// rather than measured.
struct MachineMap: View {
    let ports: [PortSnapshot]
    let selectedID: UInt64?
    let onSelect: (UInt64) -> Void

    @Environment(\.colorScheme) private var scheme

    private let size = CGSize(width: 132, height: 92)

    var body: some View {
        ZStack {
            chassis
            ForEach(ports) { entry in
                marker(for: entry)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: chassis

    private var chassis: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Material.aluminium.opacity(scheme == .dark ? 0.34 : 0.26),
                        Material.aluminium.opacity(scheme == .dark ? 0.20 : 0.16),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.18), lineWidth: 0.8)
            )
            .overlay(alignment: .top) {
                // Hinge line, so the rear of the machine is unambiguous.
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(Color.primary.opacity(0.16))
                    .frame(width: size.width * 0.62, height: 2)
                    .padding(.top, 7)
            }
            .overlay(alignment: .bottom) {
                // Trackpad, which reads as "this end is the front".
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.13), lineWidth: 0.8)
                    .frame(width: 34, height: 22)
                    .padding(.bottom, 7)
            }
    }

    // MARK: ports

    private func marker(for entry: PortSnapshot) -> some View {
        let placement = placement(for: entry)
        let connected = entry.port.connected
        let selected = entry.id == selectedID
        let isMagSafe = entry.port.kind == .magSafe

        return Button {
            onSelect(entry.id)
        } label: {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(connected ? Theme.live : Color.primary.opacity(0.30))
                .frame(width: 4, height: isMagSafe ? 12 : 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(selected ? Theme.live : .clear, lineWidth: 1.4)
                        .frame(width: 11, height: (isMagSafe ? 12 : 10) + 7)
                )
                .shadow(color: connected ? Theme.live.opacity(0.7) : .clear, radius: 4)
                // Widen the hit area well past the drawn slot; the marker is
                // only a few points across.
                .frame(width: 22, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .position(placement)
    }

    /// Ports run down each edge from the hinge toward the front, in the order
    /// the device tree reports.
    private func placement(for entry: PortSnapshot) -> CGPoint {
        let side = entry.port.location.side
        let onLeft = side != .right
        let x: CGFloat = onLeft ? 2.5 : size.width - 2.5

        let sidePorts = ports
            .filter { ($0.port.location.side != .right) == onLeft }
            .sorted(by: Self.edgeOrder)

        let index = sidePorts.firstIndex { $0.id == entry.id } ?? 0
        let count = max(sidePorts.count, 1)

        // Spread across the middle of the edge, leaving the hinge and the
        // front corner clear.
        let top: CGFloat = 0.26
        let span: CGFloat = 0.48
        let step = count > 1 ? span / CGFloat(count - 1) : 0
        let fraction = count > 1 ? top + step * CGFloat(index) : top + span / 2

        return CGPoint(x: x, y: size.height * fraction)
    }

    /// MagSafe sits behind the USB-C ports on the machines that have it.
    private static func edgeOrder(_ lhs: PortSnapshot, _ rhs: PortSnapshot) -> Bool {
        func key(_ entry: PortSnapshot) -> (Int, Int, Int) {
            (
                entry.port.kind == .magSafe ? 0 : 1,
                entry.port.location.rank,
                entry.port.portNumber
            )
        }
        return key(lhs) < key(rhs)
    }
}
