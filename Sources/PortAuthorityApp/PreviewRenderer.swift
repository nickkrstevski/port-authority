import AppKit
import PortAuthorityKit
import SwiftUI

/// Offline renderer for the panel, used to inspect layout changes without
/// having to plug and unplug real hardware. Invoked with `--render <dir>`.
@MainActor
enum PreviewRenderer {

    static func run(outputDirectory: String) {
        let directory = URL(fileURLWithPath: outputDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        for (name, snapshot) in samples() {
            for scheme in [ColorScheme.dark, .light] {
                let suffix = scheme == .dark ? "dark" : "light"
                render(
                    AppModel(preview: snapshot, traces: sampleTraces(snapshot)),
                    scheme: scheme, chart: false,
                    to: directory.appendingPathComponent("\(name)-\(suffix).png")
                )
            }
        }
        render(
            AppModel(preview: chargingSnapshot(), traces: sampleTraces(chargingSnapshot())),
            scheme: .dark, chart: true,
            to: directory.appendingPathComponent("trace-dark.png")
        )
    }

    private static func render(_ model: AppModel, scheme: ColorScheme, chart: Bool, to url: URL) {
        let view = ContentView(model: model, initialShowChart: chart)
            .padding(6)
            .background(scheme == .dark ? Color(white: 0.13) : Color(white: 0.96))
            .environment(\.colorScheme, scheme)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2

        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:])
        else {
            FileHandle.standardError.write(Data("failed to render \(url.lastPathComponent)\n".utf8))
            return
        }
        try? png.write(to: url)
        print(url.path)
    }

    /// A plausible charging curve: current tapers as the battery fills, so
    /// power falls while the contract voltage holds.
    private static func sampleTraces(_ snapshot: SystemSnapshot) -> [UInt64: PowerTrace] {
        var result: [UInt64: PowerTrace] = [:]
        for entry in snapshot.ports where entry.port.connected {
            guard let volts = entry.contract?.contractVolts else { continue }
            var trace = PowerTrace()
            for step in 0..<420 {
                let t = Double(step)
                let decay = 1 - 0.55 * (t / 420)
                let ripple = 4 * sin(t / 26)
                trace.append(
                    PowerSample(elapsed: t, watts: max(4, 88 * decay + ripple), volts: volts)
                )
            }
            result[entry.id] = trace
        }
        return result
    }

    // MARK: sample states

    private static func samples() -> [(String, SystemSnapshot)] {
        [
            ("charging-right", chargingSnapshot()),
            ("charging-left", chargingSnapshot(onLeft: true)),
            ("magsafe", magSafeSnapshot()),
            ("empty-port", emptySnapshot()),
        ]
    }

    private static func port(
        id: UInt64, number: Int, kind: PortKind, connected: Bool,
        location: PortLocation = .unknown,
        orientation: PlugOrientation = .normal, transports: [String] = []
    ) -> PortInfo {
        PortInfo(
            registryEntryID: id,
            name: kind == .magSafe ? "Port-MagSafe 3@1" : "Port-USB-C@\(number)",
            kind: kind, portNumber: number, builtIn: true,
            location: location, rid: number - 1,
            connected: connected, activeCable: false, opticalCable: false,
            orientation: orientation, hpdAsserted: false,
            transportsSupported: ["CC", "USB2", "USB3"], transportsActive: transports,
            pinConfiguration: [:], plugEventCount: 1, overcurrentCount: 0,
            connectionCount: 1, liquidDetected: false
        )
    }

    /// Mirrors the real 100W capture in Fixtures/, including the 4.7A contract
    /// that implies an e-marked cable.
    private static func chargingSnapshot(onLeft: Bool = false) -> SystemSnapshot {
        let caps: [PowerDataObject] = [
            .fixed(volts: 5, maxAmps: 3, unconstrained: true, eprCapable: false),
            .fixed(volts: 9, maxAmps: 3, unconstrained: true, eprCapable: false),
            .fixed(volts: 12, maxAmps: 3, unconstrained: true, eprCapable: false),
            .fixed(volts: 15, maxAmps: 3, unconstrained: true, eprCapable: false),
            .fixed(volts: 20, maxAmps: 5, unconstrained: true, eprCapable: false),
            .programmable(minVolts: 5, maxVolts: 21, maxAmps: 5),
        ]
        let request = RequestDataObject(raw: 0x538759D6)
        let contract = PDContract(sourceCapabilities: caps, request: request, activePDO: caps[4])

        return SystemSnapshot(
            ports: [
                PortSnapshot(port: port(id: 1, number: 1, kind: .usbC, connected: false, location: .leftBack), contract: nil),
                PortSnapshot(port: port(id: 2, number: 2, kind: .usbC, connected: false, location: .leftFront), contract: nil),
                PortSnapshot(
                    port: port(
                        id: 3, number: 3, kind: .usbC, connected: true,
                        location: onLeft ? .leftFront : .right, transports: ["USB3"]
                    ),
                    contract: contract
                ),
                PortSnapshot(port: port(id: 4, number: 1, kind: .magSafe, connected: false, location: .left), contract: nil),
            ],
            adapter: AdapterState(
                adapterWatts: 85.37, systemWatts: 19.82, ratedWatts: 100,
                voltageMillivolts: 20000, currentMilliamps: 5000,
                description: "pd charger", isCharging: true
            ),
            registersAvailable: true, registerError: nil
        )
    }

    /// MagSafe charging, to check the wedge render.
    private static func magSafeSnapshot() -> SystemSnapshot {
        let caps: [PowerDataObject] = [
            .fixed(volts: 5, maxAmps: 3, unconstrained: true, eprCapable: false),
            .fixed(volts: 9, maxAmps: 3, unconstrained: true, eprCapable: false),
            .fixed(volts: 20, maxAmps: 4.7, unconstrained: true, eprCapable: false),
        ]
        let request = RequestDataObject(raw: 0x338759D6)
        let contract = PDContract(sourceCapabilities: caps, request: request, activePDO: caps[2])
        return SystemSnapshot(
            ports: [
                PortSnapshot(port: port(id: 1, number: 1, kind: .usbC, connected: false, location: .leftBack), contract: nil),
                PortSnapshot(port: port(id: 2, number: 2, kind: .usbC, connected: false, location: .leftFront), contract: nil),
                PortSnapshot(port: port(id: 3, number: 3, kind: .usbC, connected: false, location: .right), contract: nil),
                PortSnapshot(
                    port: port(id: 4, number: 1, kind: .magSafe, connected: true, location: .left),
                    contract: contract
                ),
            ],
            adapter: AdapterState(
                adapterWatts: 71.2, systemWatts: 18.0, ratedWatts: 96,
                voltageMillivolts: 20000, currentMilliamps: 4700,
                description: "pd charger", isCharging: true
            ),
            registersAvailable: true, registerError: nil
        )
    }

    /// Same layout with the selected port empty, to check the greyed state.
    private static func emptySnapshot() -> SystemSnapshot {
        SystemSnapshot(
            ports: [
                PortSnapshot(port: port(id: 1, number: 1, kind: .usbC, connected: false, location: .leftBack), contract: nil),
                PortSnapshot(port: port(id: 2, number: 2, kind: .usbC, connected: false, location: .leftFront), contract: nil),
                PortSnapshot(port: port(id: 3, number: 3, kind: .usbC, connected: false, location: .right), contract: nil),
                PortSnapshot(port: port(id: 4, number: 1, kind: .magSafe, connected: false, location: .left), contract: nil),
            ],
            adapter: .disconnected,
            registersAvailable: true, registerError: nil
        )
    }
}
