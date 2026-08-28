import Foundation

/// A single Power Data Object from a source's advertised capabilities.
/// Layouts are fixed by the USB PD specification, so this decoding is
/// spec-driven and does not depend on Apple's register layout.
public enum PowerDataObject: Codable, Sendable, Equatable {
    case fixed(volts: Double, maxAmps: Double, unconstrained: Bool, eprCapable: Bool)
    case battery(minVolts: Double, maxVolts: Double, maxWatts: Double)
    case variable(minVolts: Double, maxVolts: Double, maxAmps: Double)
    /// Programmable Power Supply: a continuously adjustable range.
    case programmable(minVolts: Double, maxVolts: Double, maxAmps: Double)
    /// EPR Adjustable Voltage Supply, above 100W.
    case adjustable(minVolts: Double, maxVolts: Double, watts: Double)

    public init?(raw: UInt32) {
        func bits(_ high: Int, _ low: Int) -> UInt32 {
            (raw >> UInt32(low)) & ((1 << UInt32(high - low + 1)) - 1)
        }

        switch raw >> 30 {
        case 0b00:
            let volts = Double(bits(19, 10)) * 0.05
            let amps = Double(bits(9, 0)) * 0.01
            guard volts > 0, amps > 0 else { return nil }
            self = .fixed(
                volts: volts, maxAmps: amps,
                unconstrained: bits(27, 27) == 1,
                eprCapable: bits(23, 23) == 1
            )
        case 0b01:
            let maxV = Double(bits(29, 20)) * 0.05
            let minV = Double(bits(19, 10)) * 0.05
            let watts = Double(bits(9, 0)) * 0.25
            guard maxV > 0, watts > 0 else { return nil }
            self = .battery(minVolts: minV, maxVolts: maxV, maxWatts: watts)
        case 0b10:
            let maxV = Double(bits(29, 20)) * 0.05
            let minV = Double(bits(19, 10)) * 0.05
            let amps = Double(bits(9, 0)) * 0.01
            guard maxV > 0, amps > 0 else { return nil }
            self = .variable(minVolts: minV, maxVolts: maxV, maxAmps: amps)
        default:
            // Augmented PDO. Sub-type lives in bits 29:28.
            switch bits(29, 28) {
            case 0b00:
                let maxV = Double(bits(24, 17)) * 0.1
                let minV = Double(bits(15, 8)) * 0.1
                let amps = Double(bits(6, 0)) * 0.05
                guard maxV > 0, amps > 0 else { return nil }
                self = .programmable(minVolts: minV, maxVolts: maxV, maxAmps: amps)
            case 0b01:
                let maxV = Double(bits(25, 17)) * 0.1
                let minV = Double(bits(15, 8)) * 0.1
                let watts = Double(bits(9, 0))
                guard maxV > 0, watts > 0 else { return nil }
                self = .adjustable(minVolts: minV, maxVolts: maxV, watts: watts)
            default:
                return nil
            }
        }
    }

    /// Peak deliverable power, used for ranking and for the summary line.
    public var maxWatts: Double {
        switch self {
        case .fixed(let v, let a, _, _): return v * a
        case .battery(_, _, let w): return w
        case .variable(_, let v, let a): return v * a
        case .programmable(_, let v, let a): return v * a
        case .adjustable(_, _, let w): return w
        }
    }

    public var isProgrammable: Bool {
        if case .programmable = self { return true }
        if case .adjustable = self { return true }
        return false
    }

    /// Short label for the brick render, e.g. "20V 5A" or "PPS 5-21V 5A".
    public var label: String {
        func trim(_ value: Double) -> String {
            value == value.rounded()
                ? String(Int(value))
                : String(format: "%.1f", value)
        }
        switch self {
        case .fixed(let v, let a, _, _):
            return "\(trim(v))V \(trim(a))A"
        case .battery(let lo, let hi, let w):
            return "\(trim(lo))-\(trim(hi))V \(trim(w))W batt"
        case .variable(let lo, let hi, let a):
            return "\(trim(lo))-\(trim(hi))V \(trim(a))A var"
        case .programmable(let lo, let hi, let a):
            return "PPS \(trim(lo))-\(trim(hi))V \(trim(a))A"
        case .adjustable(let lo, let hi, let w):
            return "AVS \(trim(lo))-\(trim(hi))V \(trim(w))W"
        }
    }
}

/// The Request Data Object: which capability we asked for, and how hard.
public struct RequestDataObject: Codable, Sendable, Equatable {
    /// 1-based index into the source's advertised PDO list.
    public let objectPosition: Int
    public let operatingAmps: Double
    public let maxAmps: Double
    public let capabilityMismatch: Bool

    public init?(raw: UInt32) {
        func bits(_ high: Int, _ low: Int) -> UInt32 {
            (raw >> UInt32(low)) & ((1 << UInt32(high - low + 1)) - 1)
        }
        let position = Int(bits(31, 28))
        guard position > 0 else { return nil }
        self.objectPosition = position
        self.operatingAmps = Double(bits(19, 10)) * 0.01
        self.maxAmps = Double(bits(9, 0)) * 0.01
        self.capabilityMismatch = bits(26, 26) == 1
    }
}

/// What the attached source offers and what we settled on.
public struct PDContract: Codable, Sendable, Equatable {
    public let sourceCapabilities: [PowerDataObject]
    public let request: RequestDataObject?
    /// The PDO the request selected, resolved through `objectPosition`.
    public let activePDO: PowerDataObject?

    /// Negotiated ceiling, which is not the same as live draw: it is the
    /// contract voltage times the requested operating current.
    public var contractWatts: Double? {
        guard let request, let activePDO else { return nil }
        switch activePDO {
        case .fixed(let volts, _, _, _):
            return volts * request.operatingAmps
        default:
            return activePDO.maxWatts
        }
    }

    /// Negotiated voltage, when the contract is on a fixed supply.
    public var contractVolts: Double? {
        guard let activePDO else { return nil }
        switch activePDO {
        case .fixed(let volts, _, _, _): return volts
        case .programmable(_, let maxVolts, _): return maxVolts
        case .adjustable(_, let maxVolts, _): return maxVolts
        case .variable(_, let maxVolts, _): return maxVolts
        case .battery(_, let maxVolts, _): return maxVolts
        }
    }

    public var contractAmps: Double? { request?.operatingAmps }

    /// True when the source advertises Extended Power Range, i.e. above 100W.
    public var supportsEPR: Bool {
        sourceCapabilities.contains { pdo in
            if case .fixed(_, _, _, let epr) = pdo { return epr }
            if case .adjustable = pdo { return true }
            return false
        }
    }

    /// A source on mains rather than running off its own battery.
    public var unconstrainedPower: Bool {
        sourceCapabilities.contains { pdo in
            if case .fixed(_, _, let unconstrained, _) = pdo { return unconstrained }
            return false
        }
    }

    public var advertisedWatts: Double? {
        sourceCapabilities.map(\.maxWatts).max()
    }

    public init(
        sourceCapabilities: [PowerDataObject],
        request: RequestDataObject?,
        activePDO: PowerDataObject?
    ) {
        self.sourceCapabilities = sourceCapabilities
        self.request = request
        self.activePDO = activePDO
    }

    public var supportsPPS: Bool {
        sourceCapabilities.contains { $0.isProgrammable }
    }
}

/// Maps HPM registers onto PD structures.
///
/// Register numbers below were established by differential capture on an
/// M4 Pro (Mac16,8): comparing a controller with a charger attached against
/// an idle one, then validating the decode against `AppleSmartBattery`'s
/// independent `UsbHvcMenu` / `UsbHvcHvcIndex` report. They are not
/// documented by Apple and may move between models or firmware revisions,
/// so every read is defensive and failure degrades to `nil`.
public enum PDRegisters {
    /// Received Source Capabilities: one count byte, then N little-endian PDOs.
    public static let receivedSourceCaps: UInt8 = 0x30
    /// Active contract: the RDO, followed by an echo of the PDO it selected.
    public static let activeContract: UInt8 = 0x35
    /// The RDO most recently sent to the source.
    public static let sinkRequest: UInt8 = 0x36
    /// Status; bit 0 indicates a plug is present.
    public static let status: UInt8 = 0x1A

    public static func contract(from controller: HPMController) -> PDContract? {
        let caps = sourceCapabilities(from: controller)
        let request = activeRequest(from: controller)

        guard !caps.isEmpty || request != nil else { return nil }

        var active: PowerDataObject?
        if let request, request.objectPosition <= caps.count {
            active = caps[request.objectPosition - 1]
        }

        return PDContract(sourceCapabilities: caps, request: request, activePDO: active)
    }

    public static func sourceCapabilities(from controller: HPMController) -> [PowerDataObject] {
        guard let bytes = controller.register(receivedSourceCaps), bytes.count > 1 else { return [] }

        // Leading byte is the object count. Trust it, but never read past the
        // register: a stale or partial read must not produce phantom PDOs.
        let declared = Int(bytes[0])
        let available = (bytes.count - 1) / 4
        let count = min(declared, available)
        guard count > 0 else { return [] }

        return (0..<count).compactMap { index in
            let start = 1 + index * 4
            return PowerDataObject(raw: littleEndianWord(bytes, at: start))
        }
    }

    public static func activeRequest(from controller: HPMController) -> RequestDataObject? {
        guard let bytes = controller.register(activeContract), bytes.count >= 4 else { return nil }
        return RequestDataObject(raw: littleEndianWord(bytes, at: 0))
    }

    public static func plugPresent(from controller: HPMController) -> Bool? {
        guard let bytes = controller.register(status), bytes.count >= 1 else { return nil }
        return bytes[0] & 0x01 == 1
    }

    static func littleEndianWord(_ bytes: [UInt8], at offset: Int) -> UInt32 {
        guard offset + 4 <= bytes.count else { return 0 }
        return UInt32(bytes[offset])
            | UInt32(bytes[offset + 1]) << 8
            | UInt32(bytes[offset + 2]) << 16
            | UInt32(bytes[offset + 3]) << 24
    }
}
