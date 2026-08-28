import Foundation
import PortAuthorityKit

let arguments = Array(CommandLine.arguments.dropFirst())
let command = arguments.first ?? "status"

func watts(_ value: Double?) -> String {
    value.map { String(format: "%.1f W", $0) } ?? "--"
}

switch command {
case "status":
    let snapshot = PortAuthority.snapshot()
    let adapter = snapshot.adapter

    if adapter.isConnected {
        print("Adapter  \(adapter.description ?? "unknown")  rated \(watts(adapter.ratedWatts))")
        print("  drawing \(watts(adapter.adapterWatts))   system \(watts(adapter.systemWatts))   battery \(watts(adapter.batteryWatts))")
    } else {
        print("Adapter  none")
    }
    print("")

    for entry in snapshot.ports {
        let port = entry.port
        let state = port.connected ? "connected" : "empty"
        print("\(port.name)  [\(state)]  location: \(port.location.label) (\(port.location.rawValue))")
        guard port.connected else { continue }

        print("    orientation  \(port.orientation)   cable  \(port.activeCable ? "active" : "passive")\(port.opticalCable ? ", optical" : "")")
        if !port.transportsActive.isEmpty {
            print("    transports   \(port.transportsActive.joined(separator: ", "))")
        }

        guard let contract = entry.contract else {
            print("    (no PD detail)")
            continue
        }
        if let contractWatts = contract.contractWatts {
            print("    contract     \(watts(contractWatts)) ceiling")
        }
        if !contract.sourceCapabilities.isEmpty {
            print("    source caps:")
            for (index, pdo) in contract.sourceCapabilities.enumerated() {
                let selected = contract.request?.objectPosition == index + 1 ? " <-- selected" : ""
                print("      \(index + 1). \(pdo.label)\(selected)")
            }
        }
    }

    if let error = snapshot.registerError {
        print("\nregister layer unavailable: \(error)")
    }

case "dump":
    let controllers = try HPMDiagnose.dump()
    for rid in controllers.keys.sorted() {
        let controller = controllers[rid]!
        print("RID \(rid)  address 0x\(String(controller.address, radix: 16))  \(controller.registers.count) registers")
    }

case "json":
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(PortAuthority.snapshot())
    print(String(data: data, encoding: .utf8) ?? "{}")

case "decode":
    // Offline decode of a saved hpmdiagnose capture, for testing without
    // hardware attached.
    guard arguments.count > 1 else {
        print("usage: portauth decode <hpmdiagnose-capture.txt>")
        exit(2)
    }
    let text = try String(contentsOfFile: arguments[1], encoding: .utf8)
    let controllers = HPMDiagnose.parse(text)
    for rid in controllers.keys.sorted() {
        guard let contract = PDRegisters.contract(from: controllers[rid]!) else { continue }
        print("RID \(rid):")
        for (index, pdo) in contract.sourceCapabilities.enumerated() {
            let selected = contract.request?.objectPosition == index + 1 ? " <-- selected" : ""
            print("   \(index + 1). \(pdo.label)\(selected)")
        }
        if let contractWatts = contract.contractWatts {
            print("   contract ceiling \(watts(contractWatts))")
        }
    }

default:
    print("usage: portauth [status|dump|json|decode <file>]")
    exit(2)
}
