import Foundation
import IOKit

/// Live power figures and charger identity from `AppleSmartBattery`.
///
/// This is ordinary IORegistry data: no entitlement, no root, and cheap
/// enough to poll at 1Hz, unlike `hpmdiagnose`. It is the authoritative
/// source for instantaneous wattage.
public struct AdapterState: Codable, Sendable, Equatable {
    /// Power actually being drawn from the brick right now, in watts.
    public let adapterWatts: Double?
    /// Power the machine itself is consuming, in watts. The remainder is
    /// going into the battery.
    public let systemWatts: Double?
    /// Nameplate rating the adapter reports, in watts.
    public let ratedWatts: Double?
    public let voltageMillivolts: Int?
    public let currentMilliamps: Int?
    public let description: String?
    public let isCharging: Bool

    /// Power flowing into the cells, derived rather than measured.
    public var batteryWatts: Double? {
        guard let adapterWatts, let systemWatts else { return nil }
        return max(0, adapterWatts - systemWatts)
    }

    public static let disconnected = AdapterState(
        adapterWatts: nil, systemWatts: nil, ratedWatts: nil,
        voltageMillivolts: nil, currentMilliamps: nil,
        description: nil, isCharging: false
    )

    public var isConnected: Bool { ratedWatts != nil || adapterWatts != nil }
}

public enum AdapterReader {

    public static func read() -> AdapterState {
        guard let matching = IOServiceNameMatching("AppleSmartBattery") as NSMutableDictionary? else {
            return .disconnected
        }
        let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard service != 0 else { return .disconnected }
        defer { IOObjectRelease(service) }

        guard let props = PortEnumerator.properties(of: service) else { return .disconnected }

        let batteryData = props["BatteryData"] as? [String: Any]
        let details = props["AdapterDetails"] as? [String: Any]

        // AdapterDetails is present but near-empty when nothing is attached
        // (just a FamilyCode), so presence alone is not a connection test.
        let rated = details?["Watts"] as? Double ?? (details?["Watts"] as? Int).map(Double.init)

        return AdapterState(
            adapterWatts: batteryData?["AdapterPower"] as? Double,
            systemWatts: batteryData?["SystemPower"] as? Double,
            ratedWatts: rated,
            voltageMillivolts: details?["AdapterVoltage"] as? Int,
            currentMilliamps: details?["Current"] as? Int,
            description: details?["Description"] as? String,
            isCharging: props["IsCharging"] as? Bool ?? false
        )
    }
}
