import Foundation

/// One HPM (Hardware Power Manager) controller's register file.
public struct HPMController: Sendable {
    public let rid: Int
    public let route: UInt64
    public let address: UInt8
    /// Register number -> raw bytes, byte 0 first (as printed by hpmdiagnose).
    public let registers: [UInt8: [UInt8]]

    public func register(_ number: UInt8) -> [UInt8]? {
        guard let bytes = registers[number], !bytes.isEmpty else { return nil }
        return bytes
    }
}

/// Wraps `/usr/bin/hpmdiagnose`, Apple's PD-controller register dumper.
///
/// This is an undocumented tool and everything downstream of it is
/// best-effort: it can change or vanish in any macOS update. The registry
/// layer (`PortEnumerator`) is the supported floor; this is the enrichment.
///
/// It is Apple-signed with `com.apple.USBCEntitlement`, which is why it can
/// open `AppleHPMUserClient` and we cannot. Shelling out is the only path.
public enum HPMDiagnose {

    public static let toolPath = "/usr/bin/hpmdiagnose"

    public static var isAvailable: Bool {
        FileManager.default.isExecutableFile(atPath: toolPath)
    }

    public enum Failure: Error, CustomStringConvertible {
        case unavailable
        case timedOut
        case launchFailed(String)
        case exitStatus(Int32, String)

        public var description: String {
            switch self {
            case .unavailable:
                return "\(HPMDiagnose.toolPath) is not present on this system"
            case .timedOut:
                return "hpmdiagnose timed out"
            case .launchFailed(let m):
                return "could not launch hpmdiagnose: \(m)"
            case .exitStatus(let code, let err):
                return "hpmdiagnose exited \(code): \(err)"
            }
        }
    }

    /// A full dump takes roughly 1.1s on an M4 Pro: it is reading ~128
    /// registers over I2C/SPMI from every controller. Callers must not poll
    /// this in a tight loop.
    public static func dump(timeout: TimeInterval = 10) throws -> [Int: HPMController] {
        guard isAvailable else { throw Failure.unavailable }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: toolPath)
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do { try process.run() } catch { throw Failure.launchFailed("\(error)") }

        // Read before waiting, so a large dump cannot fill the pipe buffer and
        // deadlock us against a process that will never exit.
        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            usleep(20_000)
        }
        if process.isRunning {
            process.terminate()
            throw Failure.timedOut
        }

        guard process.terminationStatus == 0 else {
            let err = String(data: errData, encoding: .utf8) ?? ""
            throw Failure.exitStatus(process.terminationStatus, err.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return parse(String(data: outData, encoding: .utf8) ?? "")
    }

    /// Parses the dump format:
    ///
    ///     HPM at RID 0x0 Route 0x0 Address 0x0c :
    ///
    ///     0x00\t0x04\t0x28000000
    ///     0x06\t0x00
    ///
    /// Columns are register number, byte length, and the register contents.
    /// The hex payload is byte 0 first (verified: register 0x03 reads
    /// 0x41505020 == "APP ", matching the registry's mode property).
    /// Zero-length registers carry no payload column.
    public static func parse(_ output: String) -> [Int: HPMController] {
        var controllers: [Int: HPMController] = [:]

        var rid: Int?
        var route: UInt64 = 0
        var address: UInt8 = 0
        var registers: [UInt8: [UInt8]] = [:]

        func flush() {
            guard let current = rid else { return }
            controllers[current] = HPMController(
                rid: current, route: route, address: address, registers: registers
            )
            registers = [:]
        }

        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            if line.hasPrefix("HPM at RID") {
                flush()
                let fields = scanHeader(line)
                rid = fields.rid
                route = fields.route
                address = fields.address
                continue
            }

            let columns = line.split(separator: "\t").map { $0.trimmingCharacters(in: .whitespaces) }
            guard columns.count >= 2,
                  let number = hexValue(columns[0]).map({ UInt8(truncatingIfNeeded: $0) })
            else { continue }

            registers[number] = columns.count >= 3 ? hexBytes(columns[2]) : []
        }
        flush()

        return controllers
    }

    private static func scanHeader(_ line: String) -> (rid: Int, route: UInt64, address: UInt8) {
        var rid = 0, route: UInt64 = 0, address: UInt8 = 0
        let words = line.split(separator: " ").map(String.init)
        for (index, word) in words.enumerated() where index + 1 < words.count {
            let next = words[index + 1]
            switch word {
            case "RID": rid = Int(hexValue(next) ?? 0)
            case "Route": route = hexValue(next) ?? 0
            case "Address": address = UInt8(truncatingIfNeeded: hexValue(next) ?? 0)
            default: break
            }
        }
        return (rid, route, address)
    }

    private static func hexValue(_ token: String) -> UInt64? {
        var text = token
        if text.hasPrefix("0x") || text.hasPrefix("0X") { text = String(text.dropFirst(2)) }
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: ": "))
        return UInt64(text, radix: 16)
    }

    private static func hexBytes(_ token: String) -> [UInt8] {
        var text = token
        if text.hasPrefix("0x") || text.hasPrefix("0X") { text = String(text.dropFirst(2)) }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(text.count / 2)
        var index = text.startIndex
        while index < text.endIndex, let next = text.index(index, offsetBy: 2, limitedBy: text.endIndex) {
            guard let byte = UInt8(text[index..<next], radix: 16) else { break }
            bytes.append(byte)
            index = next
        }
        return bytes
    }
}
