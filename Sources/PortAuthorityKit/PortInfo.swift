import Foundation

/// Physical connector type, as reported by AppleHPM's `PortType`.
public enum PortKind: String, Codable, Sendable {
    case usbC = "USB-C"
    case magSafe = "MagSafe 3"
    case unknown = "Unknown"

    init(portTypeDescription: String?) {
        switch portTypeDescription {
        case "USB-C": self = .usbC
        case "MagSafe 3": self = .magSafe
        default: self = .unknown
        }
    }

    /// Whether this connector can carry data as well as power.
    public var carriesData: Bool { self == .usbC }
}

/// Orientation of the plug in the receptacle. MagSafe reports 0; USB-C
/// reports which way up the cable went in, which we mirror in the render.
public enum PlugOrientation: Int, Codable, Sendable {
    case unknown = 0
    case normal = 1
    case flipped = 2
}

/// A power-capable port, built entirely from the IOAccessory registry plane.
/// Everything here is available without entitlements or root.
public struct PortInfo: Codable, Sendable, Identifiable {
    public var id: UInt64 { registryEntryID }

    public let registryEntryID: UInt64
    public let name: String
    public let kind: PortKind
    public let portNumber: Int
    public let builtIn: Bool

    /// The HPM controller instance backing this port. This is the join key
    /// between the registry and `hpmdiagnose` output.
    public let rid: Int?

    public let connected: Bool
    public let activeCable: Bool
    public let opticalCable: Bool
    public let orientation: PlugOrientation
    public let hpdAsserted: Bool

    public let transportsSupported: [String]
    public let transportsActive: [String]
    public let pinConfiguration: [String: Int]

    public let plugEventCount: Int
    public let overcurrentCount: Int
    public let connectionCount: Int

    /// Liquid detection, USB-C only (MagSafe has no LDCM feature).
    public let liquidDetected: Bool?

    public init(
        registryEntryID: UInt64, name: String, kind: PortKind, portNumber: Int,
        builtIn: Bool, rid: Int?, connected: Bool, activeCable: Bool,
        opticalCable: Bool, orientation: PlugOrientation, hpdAsserted: Bool,
        transportsSupported: [String], transportsActive: [String],
        pinConfiguration: [String: Int], plugEventCount: Int,
        overcurrentCount: Int, connectionCount: Int, liquidDetected: Bool?
    ) {
        self.registryEntryID = registryEntryID
        self.name = name
        self.kind = kind
        self.portNumber = portNumber
        self.builtIn = builtIn
        self.rid = rid
        self.connected = connected
        self.activeCable = activeCable
        self.opticalCable = opticalCable
        self.orientation = orientation
        self.hpdAsserted = hpdAsserted
        self.transportsSupported = transportsSupported
        self.transportsActive = transportsActive
        self.pinConfiguration = pinConfiguration
        self.plugEventCount = plugEventCount
        self.overcurrentCount = overcurrentCount
        self.connectionCount = connectionCount
        self.liquidDetected = liquidDetected
    }
}
