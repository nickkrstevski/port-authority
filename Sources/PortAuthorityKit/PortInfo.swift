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

/// Where a port physically sits on the machine.
///
/// Read from the `port-location` property that Apple puts on the `hpmN`
/// device tree nodes, so this is the machine's own description of itself
/// rather than a per-model table we would have to maintain.
public enum PortLocation: String, Codable, Sendable {
    case leftBack = "left-back"
    case leftFront = "left-front"
    case left = "left"
    case rightBack = "right-back"
    case rightFront = "right-front"
    case right = "right"
    case unknown = "unknown"

    public enum Side: String, Codable, Sendable { case left, right, unknown }

    public var side: Side {
        switch self {
        case .leftBack, .leftFront, .left: return .left
        case .rightBack, .rightFront, .right: return .right
        case .unknown: return .unknown
        }
    }

    /// Ordering along that edge, front of the machine last.
    public var rank: Int {
        switch self {
        case .leftBack, .rightBack: return 1
        case .left, .right: return 1
        case .leftFront, .rightFront: return 2
        case .unknown: return 9
        }
    }

    public var label: String {
        switch self {
        case .leftBack: return "Left, rear"
        case .leftFront: return "Left, front"
        case .left: return "Left"
        case .rightBack: return "Right, rear"
        case .rightFront: return "Right, front"
        case .right: return "Right"
        case .unknown: return "Unknown"
        }
    }
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
    public let location: PortLocation

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
        builtIn: Bool, location: PortLocation = .unknown,
        rid: Int?, connected: Bool, activeCable: Bool,
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
        self.location = location
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
