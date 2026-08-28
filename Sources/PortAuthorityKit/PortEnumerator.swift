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

        let kind = PortKind(portTypeDescription: props["PortTypeDescription"] as? String)

        return PortInfo(
            registryEntryID: entryID,
            name: name,
            kind: kind,
            portNumber: props["PortNumber"] as? Int ?? 0,
            builtIn: props["BuiltIn"] as? Bool ?? false,
            location: portLocation(of: service, kind: kind),
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

    /// `port-location` lives on the hpmN device tree node above the port, as
    /// a null-terminated string in a data blob.
    private static func portLocation(of service: io_service_t, kind: PortKind) -> PortLocation {
        if let raw = searchParents(service, for: "port-location") {
            var text: String?
            if let data = raw as? Data {
                text = String(decoding: data.prefix(while: { $0 != 0 }), as: UTF8.self)
            } else if let string = raw as? String {
                text = string
            }
            if let text, let location = PortLocation(rawValue: text) { return location }
        }
        // MagSafe carries no port-location. On every Mac that has one it is
        // the rearmost port on the left side, so that is the only assumption
        // made here -- and only for MagSafe.
        return kind == .magSafe ? .left : .unknown
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
