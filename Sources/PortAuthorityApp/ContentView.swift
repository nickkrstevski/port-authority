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
                        Text(String(format: "%.1f", watts)).readout(27, weight: .semibold)
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
                legend("system", String(format: "%.0fW", system), Theme.live)
                legend("battery", String(format: "%.0fW", battery), Theme.live.opacity(0.4))
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
                    model.selectedPortID = entry.id
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
                    detailRow("Contract", String(format: "%.0fW ceiling", watts))
                }
                if snapshot.contract?.supportsPPS == true {
                    detailRow("PPS", "Supported")
                }
            } else {
                detailRow("Status", "Nothing connected")
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

/// chassis -> connector -> cable -> source, left to right.
struct ConnectionDiagram: View {
    let snapshot: PortSnapshot
    let adapter: AdapterState
    let liveWatts: Double?

    private var energised: Bool { (liveWatts ?? 0) > 0.5 }

    private var intensity: Double {
        guard let liveWatts, let ceiling = snapshot.contract?.contractWatts, ceiling > 0 else { return 0 }
        return min(1, liveWatts / ceiling)
    }

    var body: some View {
        HStack(spacing: 0) {
            ChassisEdge()
            if snapshot.port.connected {
                ConnectorView(
                    kind: snapshot.port.kind,
                    orientation: snapshot.port.orientation,
                    energised: energised
                )
                CableView(
                    energised: energised,
                    intensity: intensity,
                    heavyGauge: (snapshot.contract?.request?.operatingAmps ?? 0) > 3.0
                )
                .frame(minWidth: 26)

                if snapshot.contract != nil {
                    BrickView(contract: snapshot.contract, adapter: adapter, liveWatts: liveWatts)
                } else {
                    PassiveEndView(transports: snapshot.port.transportsActive)
                }
            } else {
                ConnectorView(kind: snapshot.port.kind, orientation: .unknown, energised: false)
                    .opacity(0.4)
                Spacer()
                Text("Empty")
                    .readout(11)
                    .foregroundStyle(.tertiary)
                    .frame(width: 172)
            }
        }
        .frame(height: 116)
        .padding(.vertical, 4)
    }
}
