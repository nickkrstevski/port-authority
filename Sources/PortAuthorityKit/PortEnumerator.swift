import Foundation
import IOKit

/// Reads the power-capable ports out of the IORegistry.
///
/// Both `AppleHPMInterfaceType10` (USB-C) and `AppleHPMInterfaceType11`
/// (MagSafe) descend from `AppleHPMInterface`, so a single class match picks
/// up every port the HPM driver owns. Non-HPM ports (HDMI, SD) are not
/// matched and are deliberately out of scope: they carry no PD.
public enum PortEnumerator {

    public static func enumerate() -> [PortInfo] {
        guard let matching = IOServiceMatching("AppleHPMInterface") else { return [] }

        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS
        else { return [] }
        defer { IOObjectRelease(iterator) }

        var ports: [PortInfo] = []
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            if let port = makePort(from: service) { ports.append(port) }
        }

        return ports.sorted { lhs, rhs in
            // USB-C ports first in port order, MagSafe last: matches the
            // physical left-to-right reading of the machine well enough, and
            // keeps the list stable across replugs.
            if lhs.kind == rhs.kind { return lhs.portNumber < rhs.portNumber }
            return lhs.kind == .usbC
        }
    }

    private static func makePort(from service: io_service_t) -> PortInfo? {
        guard let props = properties(of: service) else { return nil }

        // Port nodes carry a PortDescription; their LDCM / "Power In" children
        // do not, which is how we filter the children back out.
        guard let name = props["PortDescription"] as? String else { return nil }

        var entryID: UInt64 = 0
        IORegistryEntryGetRegistryEntryID(service, &entryID)

        return PortInfo(
            registryEntryID: entryID,
            name: name,
            kind: PortKind(portTypeDescription: props["PortTypeDescription"] as? String),
            portNumber: props["PortNumber"] as? Int ?? 0,
            builtIn: props["BuiltIn"] as? Bool ?? false,
            rid: searchParents(service, for: "RID") as? Int,
            connected: props["ConnectionActive"] as? Bool ?? false,
            activeCable: props["ActiveCable"] as? Bool ?? false,
            opticalCable: props["OpticalCable"] as? Bool ?? false,
            orientation: PlugOrientation(rawValue: props["PlugOrientation"] as? Int ?? 0) ?? .unknown,
            hpdAsserted: props["HPDAsserted"] as? Bool ?? false,
            transportsSupported: props["TransportsSupported"] as? [String] ?? [],
            transportsActive: props["TransportsActive"] as? [String] ?? [],
            pinConfiguration: props["Pin Configuration"] as? [String: Int] ?? [:],
            plugEventCount: props["Plug Event Count"] as? Int ?? 0,
            overcurrentCount: props["Overcurrent Count"] as? Int ?? 0,
            connectionCount: props["ConnectionCount"] as? Int ?? 0,
            liquidDetected: props["LDCM_LiquidDetected"] as? Bool
        )
    }

    static func properties(of service: io_service_t) -> [String: Any]? {
        var unmanaged: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &unmanaged, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = unmanaged?.takeRetainedValue() as? [String: Any]
        else { return nil }
        return dict
    }

    /// The RID lives on the HPM device node above the port, not on the port
    /// itself, so we walk up rather than reading in place.
    private static func searchParents(_ service: io_service_t, for key: String) -> Any? {
        let value = IORegistryEntrySearchCFProperty(
            service,
            kIOServicePlane,
            key as CFString,
            kCFAllocatorDefault,
            IOOptionBits(kIORegistryIterateRecursively | kIORegistryIterateParents)
        )
        return value as Any?
    }
}
