import Foundation
import PortAuthorityKit
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var snapshot: SystemSnapshot?
    @Published var selectedPortID: UInt64?

    /// Registry and battery reads are cheap, so wattage updates at 1Hz.
    private let fastInterval: TimeInterval = 1
    /// A full hpmdiagnose dump costs about a second of I2C traffic, so it
    /// runs only when the set of connected ports changes, plus a slow
    /// refresh to catch renegotiations (PPS, or a second device sharing).
    private let registerRefreshInterval: TimeInterval = 30

    private var timer: Timer?
    private var lastConnectionFingerprint: String = ""
    private var lastRegisterRefresh: Date = .distantPast

    var ports: [PortSnapshot] { snapshot?.ports ?? [] }
    var adapter: AdapterState { snapshot?.adapter ?? .disconnected }

    var selectedPort: PortSnapshot? {
        guard let id = selectedPortID else { return defaultPort }
        return ports.first { $0.id == id } ?? defaultPort
    }

    /// Prefer showing something live: the first connected port, else the first.
    private var defaultPort: PortSnapshot? {
        ports.first(where: \.port.connected) ?? ports.first
    }

    init() {}

    /// Seeds a fixed state for offline rendering; no timers, no hardware.
    init(preview: SystemSnapshot) {
        self.snapshot = preview
        self.selectedPortID = preview.ports.first(where: \.port.connected)?.id
            ?? preview.ports.first?.id
    }

    func start() {
        refresh(force: true)
        timer = Timer.scheduledTimer(withTimeInterval: fastInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh(force: false) }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh(force: Bool) {
        // Decide whether this cycle needs the expensive register read before
        // paying for it. The fingerprint captures which ports are occupied
        // and how many plug events they have seen, so a fast unplug/replug
        // still counts as a change.
        let ports = PortEnumerator.enumerate()
        let fingerprint = ports
            .map { "\($0.registryEntryID):\($0.connected):\($0.plugEventCount)" }
            .joined(separator: "|")

        let changed = fingerprint != lastConnectionFingerprint
        let stale = Date().timeIntervalSince(lastRegisterRefresh) > registerRefreshInterval
        let wantsRegisters = force || changed || stale

        lastConnectionFingerprint = fingerprint

        if wantsRegisters {
            lastRegisterRefresh = Date()
            let previous = snapshot
            Task.detached(priority: .userInitiated) {
                let fresh = PortAuthority.snapshot(includeRegisters: true)
                await MainActor.run { self.apply(fresh, previous: previous) }
            }
        } else {
            // Cheap path: refresh wattage and port state, keep the contracts
            // we already decoded rather than dropping them for two seconds.
            let adapter = AdapterReader.read()
            let existing = Dictionary(
                uniqueKeysWithValues: (snapshot?.ports ?? []).map { ($0.id, $0.contract) }
            )
            let merged = ports.map { port in
                PortSnapshot(
                    port: port,
                    contract: port.connected ? existing[port.registryEntryID] ?? nil : nil
                )
            }
            apply(
                SystemSnapshot(
                    ports: merged,
                    adapter: adapter,
                    registersAvailable: snapshot?.registersAvailable ?? HPMDiagnose.isAvailable,
                    registerError: snapshot?.registerError
                ),
                previous: snapshot
            )
        }
    }

    private func apply(_ fresh: SystemSnapshot, previous: SystemSnapshot?) {
        snapshot = fresh

        // Follow the action: if the selection is empty but something else got
        // plugged in, move to it rather than showing a blank panel.
        if let id = selectedPortID,
           let current = fresh.ports.first(where: { $0.id == id }),
           !current.port.connected,
           let live = fresh.ports.first(where: \.port.connected) {
            selectedPortID = live.id
        } else if selectedPortID == nil {
            selectedPortID = defaultPort?.id
        }
    }

    /// Menu bar title: live draw when charging, otherwise a compact idle mark.
    var menuBarLabel: String {
        guard let watts = adapter.adapterWatts, watts > 0.5 else { return "" }
        return String(format: "%.0fW", watts)
    }
}
