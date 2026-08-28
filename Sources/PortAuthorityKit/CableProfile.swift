import Foundation

/// Everything we can honestly say about the attached cable.
///
/// Note on e-markers: a sink does not perform SOP' Discover Identity. The
/// source does, because it is the one deciding whether to offer 5A. So while
/// charging, the Mac never asks the cable who it is and the e-marker VDOs are
/// simply not present in its registers. What can be established is a lower
/// bound on the cable's rating, since a contract above 3A is only legal over
/// an e-marked cable -- inference, and labelled as such.
public struct CableProfile: Codable, Sendable, Equatable {

    public enum Construction: String, Codable, Sendable {
        case passive = "Passive"
        case active = "Active"
        case optical = "Optical"
    }

    /// What the wire can actually carry, highest capability first.
    public enum DataCapability: String, Codable, Sendable {
        case thunderbolt = "Thunderbolt / USB4"
        case usb3 = "USB 3"
        case usb2 = "USB 2.0"
        case chargeOnly = "Charge only"
    }

    public let construction: Construction
    public let data: DataCapability
    /// USB-C cable current ratings are not a continuum. The Cable VDO encodes
    /// exactly two legal values, 3A and 5A, so a cable is one or the other.
    public enum CurrentRating: String, Codable, Sendable {
        /// Proven: the contract exceeds 3A, which is only permitted over a
        /// 5A e-marked cable, so this cable is certainly the 5A kind.
        case fiveAmp
        /// Undetermined. Every USB-C cable is good for at least 3A, and a 5A
        /// cable carrying 2A is indistinguishable from a 3A one, so at this
        /// load the two cannot be told apart.
        case undetermined

        public var label: String {
            switch self {
            case .fiveAmp: return "5A"
            case .undetermined: return "3A or 5A"
            }
        }

        /// Why we believe it, shown next to the value so the value is never
        /// mistaken for something read off the cable.
        public var basis: String {
            switch self {
            case .fiveAmp: return "e-marked, from contract"
            case .undetermined: return "not distinguishable at this load"
            }
        }
    }

    public let currentRating: CurrentRating?
    public let carriesDisplay: Bool
    public let displayAttached: Bool
    /// High-speed lanes with a pin assignment, out of four.
    public let activeLanes: Int

    public var currentRatingLabel: String? { currentRating?.label }

    public var summary: String {
        var parts = [construction.rawValue]
        if let rating = currentRatingLabel { parts.append(rating) }
        parts.append(data.rawValue)
        return parts.joined(separator: " · ")
    }

    public init(port: PortInfo, contract: PDContract?) {
        if port.opticalCable {
            construction = .optical
        } else if port.activeCable {
            construction = .active
        } else {
            construction = .passive
        }

        // Prefer what is actually running; fall back to what the port says it
        // could run, which is all we have before a device enumerates.
        let transports = port.transportsActive.isEmpty
            ? port.transportsSupported
            : port.transportsActive
        let live = Set(port.transportsActive)

        if live.contains("CIO") {
            data = .thunderbolt
        } else if live.contains("USB3") {
            data = .usb3
        } else if live.contains("USB2") {
            data = .usb2
        } else {
            data = .chargeOnly
        }

        carriesDisplay = transports.contains("DisplayPort")
        displayAttached = port.hpdAsserted

        // Above 3A the cable must be the 5A e-marked kind; at or below it,
        // the two ratings behave identically and cannot be separated.
        if let amps = contract?.request?.operatingAmps, amps > 3.0 {
            currentRating = .fiveAmp
        } else if contract != nil {
            currentRating = .undetermined
        } else {
            currentRating = nil
        }

        let lanes = ["tx1", "tx2", "rx1", "rx2"]
        activeLanes = lanes.reduce(into: 0) { total, pin in
            if let value = port.pinConfiguration[pin], value != 0 { total += 1 }
        }
    }
}
