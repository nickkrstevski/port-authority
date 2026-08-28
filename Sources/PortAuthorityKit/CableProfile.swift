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
    /// Lower bound on the conductor rating, in amps, or nil if unknown.
    public let minimumCurrentRating: Double?
    /// True when the rating was inferred from the contract rather than read.
    public let ratingInferred: Bool
    public let carriesDisplay: Bool
    public let displayAttached: Bool
    /// High-speed lanes with a pin assignment, out of four.
    public let activeLanes: Int

    public var currentRatingLabel: String? {
        guard let amps = minimumCurrentRating else { return nil }
        let value = amps == amps.rounded() ? String(Int(amps)) : String(format: "%.1f", amps)
        return ratingInferred ? "\(value)A min" : "\(value)A"
    }

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

        // A contract above 3A is only permitted over an e-marked 5A cable, so
        // the negotiated current puts a floor under the cable's rating.
        if let amps = contract?.request?.operatingAmps, amps > 3.0 {
            minimumCurrentRating = 5
            ratingInferred = true
        } else if contract != nil {
            minimumCurrentRating = 3
            ratingInferred = true
        } else {
            minimumCurrentRating = nil
            ratingInferred = false
        }

        let lanes = ["tx1", "tx2", "rx1", "rx2"]
        activeLanes = lanes.reduce(into: 0) { total, pin in
            if let value = port.pinConfiguration[pin], value != 0 { total += 1 }
        }
    }
}
