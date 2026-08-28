import Foundation

public struct PortSnapshot: Codable, Sendable, Identifiable {
    public var id: UInt64 { port.registryEntryID }
    public let port: PortInfo
    /// Nil when nothing is attached, or when the register layer is
    /// unavailable and we are running on registry data alone.
    public let contract: PDContract?
    /// The video stream on this port, when it can be attributed to it.
    public let display: DisplayStream?

    /// Derived cable facts, nil when the port is empty.
    public var cable: CableProfile? {
        port.connected ? CableProfile(port: port, contract: contract) : nil
    }

    public init(port: PortInfo, contract: PDContract?, display: DisplayStream? = nil) {
        self.port = port
        self.contract = contract
        self.display = display
    }
}

public struct SystemSnapshot: Codable, Sendable {
    public let ports: [PortSnapshot]
    public let adapter: AdapterState
    /// False when `hpmdiagnose` is missing or failed. The UI still renders
    /// ports and live wattage; only the PDO and contract detail is lost.
    public let registersAvailable: Bool
    public let registerError: String?

    public var connectedPorts: [PortSnapshot] { ports.filter(\.port.connected) }

    public init(
        ports: [PortSnapshot], adapter: AdapterState,
        registersAvailable: Bool, registerError: String?
    ) {
        self.ports = ports
        self.adapter = adapter
        self.registersAvailable = registersAvailable
        self.registerError = registerError
    }
}

public enum PortAuthority {

    /// Builds a full picture. Set `includeRegisters` to false for the cheap
    /// path: a full `hpmdiagnose` dump costs roughly a second, so callers
    /// polling frequently should skip it and refresh registers only on
    /// plug events.
    public static func snapshot(includeRegisters: Bool = true) -> SystemSnapshot {
        let ports = PortEnumerator.enumerate()
        let adapter = AdapterReader.read()

        guard includeRegisters, ports.contains(where: \.connected) else {
            return SystemSnapshot(
                ports: ports.map { PortSnapshot(port: $0, contract: nil) },
                adapter: adapter,
                registersAvailable: HPMDiagnose.isAvailable,
                registerError: nil
            )
        }

        var controllers: [Int: HPMController] = [:]
        var failure: String?
        do {
            controllers = try HPMDiagnose.dump()
        } catch {
            failure = "\(error)"
        }

        let displays = DisplayReader.externalStreams()
        // macOS does not say which port a display arrived on. Attribution is
        // only safe when it is unambiguous: exactly one port asserting hot
        // plug detect, and exactly one external display. Otherwise leave it
        // unattributed rather than guessing which cable it came down.
        let displayPorts = ports.filter { $0.connected && $0.hpdAsserted }
        let attributable = displayPorts.count == 1 && displays.count == 1

        let snapshots = ports.map { port -> PortSnapshot in
            // Only attempt a contract for ports that actually have something
            // attached; an idle controller's registers are stale, not empty.
            let display = (attributable && port.registryEntryID == displayPorts[0].registryEntryID)
                ? displays.first : nil

            guard port.connected,
                  let rid = port.rid,
                  let controller = controllers[rid]
            else { return PortSnapshot(port: port, contract: nil, display: display) }

            return PortSnapshot(
                port: port,
                contract: PDRegisters.contract(from: controller),
                display: display
            )
        }

        return SystemSnapshot(
            ports: snapshots,
            adapter: adapter,
            registersAvailable: failure == nil && HPMDiagnose.isAvailable,
            registerError: failure
        )
    }
}
