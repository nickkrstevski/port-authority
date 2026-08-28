import Foundation

public struct PortSnapshot: Codable, Sendable, Identifiable {
    public var id: UInt64 { port.registryEntryID }
    public let port: PortInfo
    /// Nil when nothing is attached, or when the register layer is
    /// unavailable and we are running on registry data alone.
    public let contract: PDContract?

    /// Derived cable facts, nil when the port is empty.
    public var cable: CableProfile? {
        port.connected ? CableProfile(port: port, contract: contract) : nil
    }

    public init(port: PortInfo, contract: PDContract?) {
        self.port = port
        self.contract = contract
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

        let snapshots = ports.map { port -> PortSnapshot in
            // Only attempt a contract for ports that actually have something
            // attached; an idle controller's registers are stale, not empty.
            guard port.connected,
                  let rid = port.rid,
                  let controller = controllers[rid]
            else { return PortSnapshot(port: port, contract: nil) }
            return PortSnapshot(port: port, contract: PDRegisters.contract(from: controller))
        }

        return SystemSnapshot(
            ports: snapshots,
            adapter: adapter,
            registersAvailable: failure == nil && HPMDiagnose.isAvailable,
            registerError: failure
        )
    }
}
