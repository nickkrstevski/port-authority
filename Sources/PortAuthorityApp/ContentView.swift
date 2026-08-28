import PortAuthorityKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel

    init(model: AppModel, initialShowChart: Bool = false) {
        self.model = model
        if initialShowChart { model.showChart = true }
    }

    private var showChart: Bool { model.showChart }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if let selected = model.selectedPort {
                ConnectionDiagram(
                    snapshot: selected,
                    adapter: model.adapter,
                    liveWatts: liveWatts(for: selected)
                )
                if selected.port.connected { modeToggle }

                // Fixed height, deliberately. The panel is a window that
                // sizes to its content, and swapping regions of different
                // heights made NSHostingView push new size extrema onto that
                // window mid-constraint-pass, which AppKit answers with an
                // exception. Holding this region's height constant means the
                // panel never has to resize, so that path is never taken.
                VStack(alignment: .leading, spacing: 0) {
                    if showChart {
                        PowerChart(
                            trace: model.trace(for: selected.id) ?? PowerTrace(),
                            contract: selected.contract
                        )
                    } else {
                        details(for: selected)
                    }
                    Spacer(minLength: 0)
                }
                .frame(height: selected.port.connected ? 250 : 0, alignment: .top)
                .clipped()
            }
            footer
        }
        .padding(15)
        .frame(width: Theme.panelWidth)
    }

    /// Readouts on the left, the machine on the right. Side by side rather
    /// than stacked: the panel is tall enough already.
    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 9) {
                summary
                if model.adapter.adapterWatts != nil { powerSplit }
                selectedPortSummary
            }
            Spacer(minLength: 0)
            MachineMap(
                ports: model.ports,
                selectedID: model.selectedPort?.id,
                onSelect: { model.select(portID: $0) }
            )
        }
    }

    @ViewBuilder
    private var selectedPortSummary: some View {
        if let selected = model.selectedPort {
            VStack(alignment: .leading, spacing: 2) {
                Text(shortName(selected.port))
                    .font(.system(size: 12, weight: .semibold))
                HStack(spacing: 4) {
                    Circle()
                        .fill(selected.port.connected ? Theme.live : Theme.idle)
                        .frame(width: 5, height: 5)
                    Text("\(selected.port.location.label) · \(selected.port.connected ? "Connected" : "Empty")")
                        .readout(10)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// Live wattage is machine-wide, not per-port, so only attribute it to a
    /// port that is actually the one negotiating power.
    private func liveWatts(for snapshot: PortSnapshot) -> Double? {
        guard snapshot.contract != nil else { return nil }
        return model.adapter.adapterWatts
    }

    private var summary: some View {
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
    }

    /// Where the incoming power is going. The split is the interesting part:
    /// it explains why a 100W charger is only pulling 85W.
    private var powerSplit: some View {
        let system = model.adapter.systemWatts ?? 0
        let battery = model.adapter.batteryWatts ?? 0
        let total = max(system + battery, 0.001)

        return VStack(alignment: .leading, spacing: 4) {
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
        if port.connected {
            VStack(alignment: .leading, spacing: 10) {
                if let cable = snapshot.cable { cableSection(cable, port: port) }
                if let display = snapshot.display { displaySection(display) }
                if let contract = snapshot.contract {
                    contractSection(contract, liveWatts: liveWatts(for: snapshot))
                }
                portSection(port)
            }
        }
    }

    private func cableSection(_ cable: CableProfile, port: PortInfo) -> some View {
        section("Cable") {
            detailRow("Construction", cable.construction.rawValue)
            if let rating = cable.currentRating {
                // The basis is shown alongside: a sink never reads the cable's
                // e-marker, so this is deduced, never read off the cable.
                detailRow("Rated for", rating.label, note: rating.basis)
            }
            detailRow("Data", cable.data.rawValue)
            if cable.activeLanes > 0 {
                detailRow("High-speed lanes", "\(cable.activeLanes) of 4")
            }
            detailRow("Orientation", port.orientation == .flipped ? "Flipped" : "Normal")
            if cable.carriesDisplay {
                detailRow("DisplayPort", cable.displayAttached ? "Display attached" : "Capable")
            }
        }
    }

    private func displaySection(_ display: DisplayStream) -> some View {
        section("Display") {
            detailRow("Mode", display.modeLabel)
            detailRow(
                "Stream", String(format: "%.2f Gb/s", display.gigabitsPerSecond),
                note: "at \(display.bitsPerPixel / 3) bpc"
            )
        }
    }

    private func contractSection(_ contract: PDContract, liveWatts: Double?) -> some View {
        section("Contract") {
            if let volts = contract.contractVolts, let amps = contract.contractAmps {
                detailRow("Negotiated", "\(trimmed(volts))V · \(trimmed(amps))A")
            }
            if let ceiling = contract.contractWatts {
                detailRow("Ceiling", "\(Watts.short(ceiling))W")
            }
            if let liveWatts, let volts = contract.contractVolts, volts > 0 {
                detailRow("Drawing", "\(Watts.short(liveWatts))W · \(trimmed(liveWatts / volts))A")
            }
            detailRow("Profiles offered", "\(contract.sourceCapabilities.count)")
            let features = [
                contract.supportsPPS ? "PPS" : nil,
                contract.supportsEPR ? "EPR" : nil,
                contract.unconstrainedPower ? "Mains" : nil,
            ].compactMap { $0 }
            if !features.isEmpty {
                detailRow("Supports", features.joined(separator: " · "))
            }
            if contract.request?.capabilityMismatch == true {
                detailRow("Warning", "Capability mismatch")
            }
        }
    }

    private func portSection(_ port: PortInfo) -> some View {
        section("Port") {
            if !port.transportsActive.isEmpty {
                detailRow("Active", port.transportsActive.joined(separator: " · "))
            }
            detailRow("Connections", "\(port.connectionCount)")
            if port.overcurrentCount > 0 {
                detailRow("Overcurrent events", "\(port.overcurrentCount)")
            }
            if port.liquidDetected == true {
                detailRow("Liquid", "Detected")
            }
        }
    }

    private func trimmed(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }

    @ViewBuilder
    private func section<Content: View>(
        _ title: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
                .tracking(0.6)
            content()
        }
    }

    private func detailRow(_ label: String, _ value: String, note: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label).readout(10).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            if let note {
                Text(note)
                    .font(.system(size: 8.5))
                    .foregroundStyle(.tertiary)
            }
            Text(value).readout(10).multilineTextAlignment(.trailing)
        }
    }

    /// Morphs between the list and plot glyphs on tap. SF Symbols' replace
    /// transition does the interpolation, so the two icons swap as one mark
    /// rather than cross-fading.
    private var modeToggle: some View {
        HStack {
            Button {
                model.showChart.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showChart ? "chart.xyaxis.line" : "list.bullet")
                        .contentTransition(.symbolEffect(.replace.downUp))
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 14)
                        .animation(.snappy(duration: 0.28), value: showChart)
                    Text(showChart ? "Trace" : "Details")
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(Color.primary.opacity(0.09))
                )
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .help(showChart ? "Show details" : "Show power trace")

            Spacer()

            if showChart, let selected = model.selectedPort,
               let trace = model.trace(for: selected.id), trace.duration > 0 {
                Text("since plugged in · \(PowerChart.clock(trace.duration))")
                    .readout(9)
                    .foregroundStyle(.tertiary)
            }
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

    /// A port on the machine's left edge has its cable leaving to the left,
    /// so the whole scene mirrors: machine on the right, source on the left,
    /// plug pointing right into it.
    private var mirrored: Bool { snapshot.port.location.side == .left }
    private var energised: Bool { connected && (liveWatts ?? 0) > 0.5 }

    /// How hard the cable is working relative to what was negotiated.
    private var heavyGauge: Bool {
        (snapshot.contract?.request?.operatingAmps ?? 0) > 3.0
    }

    private var intensity: Double {
        guard let liveWatts, let ceiling = snapshot.contract?.contractWatts, ceiling > 0 else { return 0 }
        return min(1, liveWatts / ceiling)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            MachineBody(portKind: snapshot.port.kind, dimmed: !connected)
                // Drawn above the plug so the shell disappears into the port
                // rather than lying across the chassis.
                .zIndex(1)

            if !connected { Spacer().frame(width: 14) }

            // An unplugged port still draws the whole assembly, greyed out and
            // pulled clear of the chassis, so the panel keeps its shape and
            // the port reads as "empty" rather than "broken".
            TopDownPlug(
                kind: snapshot.port.kind,
                orientation: connected ? snapshot.port.orientation : .unknown,
                energised: energised,
                dimmed: !connected,
                heavyGauge: heavyGauge
            )
            // A seated connector has its whole contact shell inside the
            // machine: only the housing shows, butted against the chassis.
            // Unplugged, the shell is visible because it is out in the air.
            .padding(.leading, connected ? -PlugMetrics.forKind(snapshot.port.kind).shellLong : 0)

            CableView(
                energised: energised,
                intensity: intensity,
                heavyGauge: heavyGauge,
                dimmed: !connected
            )
            .frame(minWidth: 30)
            .layoutPriority(1)
            // Tuck under the strain relief so the wire meets the plug with no
            // seam between them.
            .padding(.leading, -4)

            endpoint
        }
        // Mirroring the assembled scene keeps the geometry exact; the source
        // panel counter-flips its own contents so its text still reads.
        .scaleEffect(x: mirrored ? -1 : 1, y: 1, anchor: .center)
        .frame(maxWidth: .infinity, alignment: mirrored ? .trailing : .leading)
        .padding(.vertical, 6)
        .padding(mirrored ? .trailing : .leading, -15)
        .animation(.easeInOut(duration: 0.25), value: connected)
    }

    @ViewBuilder
    private var endpoint: some View {
        if !connected {
            EmptyEndView(portName: shortLabel, mirrored: mirrored)
        } else if snapshot.contract != nil {
            BrickView(
                contract: snapshot.contract, adapter: adapter,
                liveWatts: liveWatts, mirrored: mirrored
            )
        } else {
            PassiveEndView(transports: snapshot.port.transportsActive, mirrored: mirrored)
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
