import Foundation
import IOKit

/// Reads live input power from the SMC.
///
/// Why this exists: `AppleSmartBattery`'s `AdapterPower` is the correct number
/// but IOKit refreshes it on the battery gas gauge's own slow schedule --
/// measured here holding the same value for ten seconds straight. The SMC's
/// `PDTR` sensor moves every second, which is what a live wattage readout
/// needs.
///
/// Deliberately reads exactly one key. Interleaving reads of different keys on
/// this connection was observed returning the previous key's value, so
/// `PSTR`/`PPBR` are not used and the system/battery split stays on IOKit.
/// If that quirk is ever pinned down, more sensors can be added here.
public enum SMCReader {

    /// DC input total power, in watts: what the charger is delivering.
    public static func adapterInputWatts() -> Double? {
        guard let connection = shared else { return nil }
        guard let value = readFloat(key: "PDTR", connection: connection) else { return nil }
        // Reject nonsense rather than rendering it: no adapter exceeds a few
        // hundred watts, and a failed read can surface as NaN.
        guard value.isFinite, value >= 0, value < 400 else { return nil }
        return value
    }

    // MARK: connection

    private static let shared: io_connect_t? = {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        var connection: io_connect_t = 0
        guard IOServiceOpen(service, mach_task_self_, 0, &connection) == kIOReturnSuccess else { return nil }
        return connection
    }()

    // MARK: SMC protocol

    private struct Version {
        var major: UInt8 = 0, minor: UInt8 = 0, build: UInt8 = 0, reserved: UInt8 = 0
        var release: UInt16 = 0
    }

    private struct PLimitData {
        var version: UInt16 = 0, length: UInt16 = 0
        var cpuPLimit: UInt32 = 0, gpuPLimit: UInt32 = 0, memPLimit: UInt32 = 0
    }

    private struct KeyInfo {
        var dataSize: UInt32 = 0, dataType: UInt32 = 0
        var dataAttributes: UInt8 = 0
    }

    /// Layout must match the kernel's SMCParamStruct exactly, including the
    /// padding field; a mismatch reads plausible-looking garbage.
    private struct Param {
        var key: UInt32 = 0
        var vers = Version()
        var pLimitData = PLimitData()
        var keyInfo = KeyInfo()
        var padding: UInt16 = 0
        var result: UInt8 = 0
        var status: UInt8 = 0
        var data8: UInt8 = 0
        var data32: UInt32 = 0
        var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) =
            (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
             0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    }

    private static let readKeyCommand: UInt8 = 5
    private static let getKeyInfoCommand: UInt8 = 9
    private static let handleEventSelector: UInt32 = 2

    private static func fourCharCode(_ text: String) -> UInt32 {
        text.utf8.reduce(UInt32(0)) { ($0 << 8) + UInt32($1) }
    }

    private static func call(_ input: inout Param, _ output: inout Param, _ connection: io_connect_t) -> Bool {
        var outputSize = MemoryLayout<Param>.stride
        let status = IOConnectCallStructMethod(
            connection, handleEventSelector,
            &input, MemoryLayout<Param>.stride,
            &output, &outputSize
        )
        return status == kIOReturnSuccess && output.result == 0
    }

    private static func readFloat(key: String, connection: io_connect_t) -> Double? {
        var input = Param()
        var output = Param()

        input.key = fourCharCode(key)
        input.data8 = getKeyInfoCommand
        guard call(&input, &output, connection) else { return nil }

        let info = output.keyInfo
        guard info.dataSize == 4 else { return nil }

        // Only float sensors are handled; a different encoding here would mean
        // the key is not what we expect, so bail rather than guess.
        let type = withUnsafeBytes(of: info.dataType.bigEndian) {
            String(bytes: $0, encoding: .ascii)
        }
        guard type?.hasPrefix("flt") == true else { return nil }

        input = Param()
        input.key = fourCharCode(key)
        input.keyInfo = info
        input.data8 = readKeyCommand
        output = Param()
        guard call(&input, &output, connection) else { return nil }

        let raw = withUnsafeBytes(of: output.bytes) { buffer in
            UInt32(buffer[0]) | UInt32(buffer[1]) << 8
                | UInt32(buffer[2]) << 16 | UInt32(buffer[3]) << 24
        }
        return Double(Float(bitPattern: raw))
    }
}
