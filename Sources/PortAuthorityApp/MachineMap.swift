import PortAuthorityKit
import SwiftUI

/// The machine seen from above, drawn to its real proportions, with every
/// port in place. Power ports are selectable; the rest are context.
///
/// Provenance is tracked in MachineGeometry: the body size and port set come
/// from Apple, the left-hand USB-C ordering from this machine's device tree,
/// the right-hand ordering from Apple's labelled product photo, and the
/// distances along each edge are still estimates.
struct MachineMap: View {
    let ports: [PortSnapshot]
    let selectedID: UInt64?
    let onSelect: (UInt64) -> Void

    @Environment(\.colorScheme) private var scheme

    /// Drawn width; everything else derives from the real millimetre figures.
    private let drawnWidth: CGFloat = 176
    private var scale: CGFloat { drawnWidth / MachineGeometry.bodyWidth }
    private var drawnDepth: CGFloat { MachineGeometry.bodyDepth * scale }
    private func mm(_ value: Double) -> CGFloat { value * scale }

    private var caseTop: Color {
        scheme == .dark ? Color(white: 0.30) : Color(white: 0.78)
    }
    /// The keyboard well is markedly darker than the case in life -- close to
    /// black even on a silver machine -- which is most of what makes the top
    /// case read correctly.
    private var wellColor: Color { Color(white: scheme == .dark ? 0.07 : 0.16) }
    private var keyColor: Color { Color(white: scheme == .dark ? 0.17 : 0.26) }

    var body: some View {
        ZStack {
            chassis
            speakers
            keyboard
            trackpad
            fixtures
        }
        .frame(width: drawnWidth, height: drawnDepth)
    }

    // MARK: chassis

    private var chassis: some View {
        RoundedRectangle(cornerRadius: mm(MachineGeometry.cornerRadius), style: .continuous)
            .fill(
                LinearGradient(
                    colors: [caseTop, caseTop.opacity(0.82)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: mm(MachineGeometry.cornerRadius), style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.20), lineWidth: 0.8)
            )
            .overlay(alignment: .top) {
                // Hinge, so the rear of the machine is never in doubt.
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(Color.primary.opacity(0.20))
                    .frame(width: drawnWidth * 0.58, height: 1.6)
                    .padding(.top, mm(8))
            }
            .overlay(alignment: .bottom) {
                // Finger recess in the front edge, for opening the lid.
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.black.opacity(scheme == .dark ? 0.45 : 0.22))
                    .frame(width: mm(60), height: mm(4))
                    .offset(y: mm(1.5))
            }
            .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
    }

    // MARK: keyboard

    /// Relative key widths per row, in units of one standard key. This is the
    /// real ANSI Mac layout rather than an even grid, which is most of what
    /// makes a keyboard read as a keyboard.
    /// The function row is half height on a real keyboard; every other row is
    /// full. Drawing them all equal was the giveaway.
    private static let rowHeights: [Double] = [0.62, 1, 1, 1, 1, 1]

    private static let keyRows: [[Double]] = [
        [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
        [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1.5],
        [1.5, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
        [1.75, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1.75],
        [2.25, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2.25],
        [1, 1, 1, 1.25, 5, 1.25, 1, 1],
    ]

    private var keyboard: some View {
        let width = mm(MachineGeometry.keyboardWidth)
        let depth = mm(MachineGeometry.keyboardDepth)
        let rowGap: CGFloat = 1.0
        let units = Self.rowHeights.reduce(0, +)
        let unit = (depth - 5 - rowGap * CGFloat(Self.keyRows.count - 1)) / CGFloat(units)

        return VStack(spacing: rowGap) {
            ForEach(Array(Self.keyRows.enumerated()), id: \.offset) { index, row in
                keyRow(row, width: width, height: unit * CGFloat(Self.rowHeights[index]))
            }
        }
        .padding(2.5)
        .background(
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(wellColor)
        )
        .frame(width: width, height: depth)
        .position(x: drawnWidth / 2, y: mm(MachineGeometry.keyboardFromRear) + depth / 2)
    }

    private func keyRow(_ row: [Double], width: CGFloat, height: CGFloat) -> some View {
        let gap: CGFloat = 0.9
        let units = row.reduce(0, +)
        let unitWidth = (width - gap * CGFloat(row.count - 1) - 4) / CGFloat(units)

        return HStack(spacing: gap) {
            ForEach(Array(row.enumerated()), id: \.offset) { _, span in
                RoundedRectangle(cornerRadius: 0.9, style: .continuous)
                    .fill(keyColor)
                    .frame(width: max(1, unitWidth * CGFloat(span)), height: height)
            }
        }
    }

    /// Perforated strips either side of the keyboard.
    private var speakers: some View {
        let depth = mm(MachineGeometry.keyboardDepth)
        let width = mm(MachineGeometry.speakerWidth)
        let inset = (drawnWidth - mm(MachineGeometry.keyboardWidth)) / 2 - width - mm(3)

        return HStack {
            grille(width: width, height: depth)
            Spacer()
            grille(width: width, height: depth)
        }
        .padding(.horizontal, max(mm(5), inset))
        .frame(width: drawnWidth)
        .position(x: drawnWidth / 2, y: mm(MachineGeometry.keyboardFromRear) + depth / 2)
    }

    private func grille(width: CGFloat, height: CGFloat) -> some View {
        Canvas { context, size in
            let pitch: CGFloat = 2.0
            let radius: CGFloat = 0.42
            var y: CGFloat = radius
            var row = 0
            while y < size.height - radius {
                var x: CGFloat = row.isMultiple(of: 2) ? radius : radius + pitch / 2
                while x < size.width - radius {
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - radius, y: y - radius,
                                               width: radius * 2, height: radius * 2)),
                        with: .color(Color.primary.opacity(0.28))
                    )
                    x += pitch
                }
                y += pitch * 0.86
                row += 1
            }
        }
        .frame(width: width, height: height)
    }

    private var trackpad: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(wellColor.opacity(0.35))
            .overlay(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.16), lineWidth: 0.7)
            )
            .frame(width: mm(MachineGeometry.trackpadWidth), height: mm(MachineGeometry.trackpadDepth))
            .position(
                x: drawnWidth / 2,
                y: mm(MachineGeometry.keyboardFromRear + MachineGeometry.keyboardDepth)
                    + mm(MachineGeometry.trackpadDepth) / 2 + mm(6)
            )
    }

    // MARK: ports

    private var fixtures: some View {
        ForEach(Array(MachineGeometry.placements.enumerated()), id: \.offset) { _, placement in
            fixture(placement)
        }
    }

    @ViewBuilder
    private func fixture(_ placement: MachineGeometry.Placement) -> some View {
        let onLeft = placement.side == .left
        let x: CGFloat = onLeft ? 1.6 : drawnWidth - 1.6
        let y = mm(placement.fromRear)
        let length = max(3, mm(placement.fixture.width))
        let entry = matchingPort(placement.fixture)

        if let entry {
            let connected = entry.port.connected
            let selected = entry.id == selectedID
            Button { onSelect(entry.id) } label: {
                slot(length: length, live: connected, selected: selected)
                    .frame(width: 20, height: max(18, length + 10))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .position(x: x, y: y)
        } else {
            // Ports the app has nothing to say about: drawn for context only.
            slot(length: length, live: false, selected: false)
                .position(x: x, y: y)
        }
    }

    private func slot(length: CGFloat, live: Bool, selected: Bool) -> some View {
        ZStack {
            if live {
                TimelineView(.animation) { timeline in
                    let phase = timeline.date.timeIntervalSinceReferenceDate * 1.7
                    let pulse = 0.55 + 0.45 * (sin(phase) + 1) / 2
                    Capsule()
                        .fill(Theme.live)
                        .frame(width: 4.2, height: length)
                        .shadow(color: Theme.live.opacity(pulse), radius: 4 + pulse * 5)
                }
            }
            Capsule()
                .fill(live ? Theme.live : Color.primary.opacity(0.45))
                .overlay(
                    Capsule().strokeBorder(Color.black.opacity(0.30), lineWidth: 0.5)
                )
                .frame(width: 4.2, height: length)

            if selected {
                Capsule()
                    .strokeBorder(Theme.live, lineWidth: 1.4)
                    .frame(width: 11, height: length + 8)
            }
        }
    }

    /// Ties a drawn fixture back to a real port, where one exists.
    private func matchingPort(_ fixture: MachineGeometry.Fixture) -> PortSnapshot? {
        switch fixture {
        case .magSafe:
            return ports.first { $0.port.kind == .magSafe }
        case .usbC(let location):
            return ports.first { $0.port.kind == .usbC && $0.port.location == location }
        case .hdmi, .sdCard, .audio:
            return nil
        }
    }
}
