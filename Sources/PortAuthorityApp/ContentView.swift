import PortAuthorityKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            summary
            portPicker
            if let selected = model.selectedPort {
                ConnectionDiagram(
                    snapshot: selected,
                    adapter: model.adapter,
                    liveWatts: liveWatts(for: selected)
                )
                details(for: selected)
            }
            footer
        }
        .padding(15)
        .frame(width: Theme.panelWidth)
    }

    /// Live wattage is machine-wide, not per-port, so only attribute it to a
    /// port that is actually the one negotiating power.
    private func liveWatts(for snapshot: PortSnapshot) -> Double? {
        guard snapshot.contract != nil else { return nil }
        return model.adapter.adapterWatts
    }

    private var summary: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Port Authority")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                if let watts = model.adapter.adapterWatts, watts > 0.5 {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(Watts.short(watts)).readout(27, weight: .semibold)
                        Text("W").readout(13).foregroundStyle(.secondary)
                    }
                } else {
                    Text("On battery").readout(17).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if model.adapter.adapterWatts != nil { powerSplit }
        }
    }

    /// Where the incoming power is going. The split is the interesting part:
    /// it explains why a 100W charger is only pulling 85W.
    private var powerSplit: some View {
        let system = model.adapter.systemWatts ?? 0
        let battery = model.adapter.batteryWatts ?? 0
        let total = max(system + battery, 0.001)

        return VStack(alignment: .trailing, spacing: 4) {
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    Capsule().fill(Theme.live)
                        .frame(width: geometry.size.width * system / total)
                    Capsule().fill(Theme.live.opacity(0.4))
                }
            }
            .frame(width: 116, height: 5)

            HStack(spacing: 9) {
                legend("system", "\(Watts.short(system))W", Theme.live)
                legend("battery", "\(Watts.short(battery))W", Theme.live.opacity(0.4))
            }
        }
    }

    private func legend(_ name: String, _ value: String, _ color: Color) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text("\(name) \(value)").readout(9).foregroundStyle(.secondary)
        }
    }

    private var portPicker: some View {
        HStack(spacing: 5) {
            ForEach(model.ports) { entry in
                let isSelected = model.selectedPort?.id == entry.id
                Button {
                    model.select(portID: entry.id)
                } label: {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(entry.port.connected ? Theme.live : Theme.idle)
                            .frame(width: 5, height: 5)
                        Text(shortName(entry.port))
                            .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(isSelected ? Color.primary.opacity(0.11) : Color.clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func shortName(_ port: PortInfo) -> String {
        switch port.kind {
        case .usbC: return "USB-C \(port.portNumber)"
        case .magSafe: return "MagSafe"
        case .unknown: return port.name
        }
    }

    @ViewBuilder
    private func details(for snapshot: PortSnapshot) -> some View {
        let port = snapshot.port
        VStack(alignment: .leading, spacing: 5) {
            if port.connected {
                detailRow("Orientation", port.orientation == .flipped ? "Flipped" : "Normal")
                detailRow("Cable", cableDescription(snapshot))
                if !port.transportsActive.isEmpty {
                    detailRow("Transports", port.transportsActive.joined(separator: " · "))
                }
                if let contract = snapshot.contract, let watts = contract.contractWatts {
                    detailRow("Contract", "\(Watts.short(watts))W ceiling")
                }
                if snapshot.contract?.supportsPPS == true {
                    detailRow("PPS", "Supported")
                }
            }
            if port.liquidDetected == true {
                detailRow("Liquid", "Detected")
            }
        }
    }

    /// The registry's ActiveCable flag distinguishes active cables from
    /// passive ones; it is not an e-marker test. A passive cable carrying
    /// more than 3A must be e-marked, so we infer that from the contract
    /// rather than claiming to have read the e-marker itself.
    private func cableDescription(_ snapshot: PortSnapshot) -> String {
        var parts: [String] = [snapshot.port.activeCable ? "Active" : "Passive"]
        if snapshot.port.opticalCable { parts.append("optical") }
        if let amps = snapshot.contract?.request?.operatingAmps, amps > 3.0 {
            parts.append("e-marked (>3A)")
        }
        return parts.joined(separator: ", ")
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).readout(10).foregroundStyle(.secondary)
            Spacer()
            Text(value).readout(10).multilineTextAlignment(.trailing)
        }
    }

    private var footer: some View {
        HStack {
            if model.snapshot?.registersAvailable == false {
                Label("PD detail unavailable", systemImage: "exclamationmark.triangle")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }
}

/// chassis -> plug -> cable -> source, left to right, seen from above.
struct ConnectionDiagram: View {
    let snapshot: PortSnapshot
    let adapter: AdapterState
    let liveWatts: Double?

    private var connected: Bool { snapshot.port.connected }
    private var energised: Bool { connected && (liveWatts ?? 0) > 0.5 }

    /// How hard the cable is working relative to what was negotiated.
    private var intensity: Double {
        guard let liveWatts, let ceiling = snapshot.contract?.contractWatts, ceiling > 0 else { return 0 }
        return min(1, liveWatts / ceiling)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            ChassisEdge(dimmed: !connected)

            if !connected { Spacer().frame(width: 14) }

            // An unplugged port still draws the whole assembly, greyed out and
            // pulled clear of the chassis, so the panel keeps its shape and
            // the port reads as "empty" rather than "broken".
            TopDownPlug(
                kind: snapshot.port.kind,
                orientation: connected ? snapshot.port.orientation : .unknown,
                energised: energised,
                dimmed: !connected
            )

            CableView(
                energised: energised,
                intensity: intensity,
                heavyGauge: (snapshot.contract?.request?.operatingAmps ?? 0) > 3.0,
                dimmed: !connected
            )
            .frame(minWidth: 34)
            .layoutPriority(1)

            endpoint
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .animation(.easeInOut(duration: 0.25), value: connected)
    }

    @ViewBuilder
    private var endpoint: some View {
        if !connected {
            EmptyEndView(portName: shortLabel)
        } else if snapshot.contract != nil {
            BrickView(contract: snapshot.contract, adapter: adapter, liveWatts: liveWatts)
        } else {
            PassiveEndView(transports: snapshot.port.transportsActive)
        }
    }

    private var shortLabel: String {
        switch snapshot.port.kind {
        case .usbC: return "USB-C \(snapshot.port.portNumber)"
        case .magSafe: return "MagSafe"
        case .unknown: return snapshot.port.name
        }
    }
}
