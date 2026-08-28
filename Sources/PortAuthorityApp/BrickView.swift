import PortAuthorityKit
import SwiftUI

/// The thing on the other end of the cable, with everything it told us.
struct BrickView: View {
    let contract: PDContract?
    let adapter: AdapterState
    let liveWatts: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            if let capabilities = contract?.sourceCapabilities, !capabilities.isEmpty {
                Divider().opacity(0.35)
                capabilityList(capabilities)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .frame(width: 168, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.black.opacity(0.26))
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(Theme.metal.opacity(0.3), lineWidth: 1)
                )
        )
        .overlay(alignment: .leading) { cableEntry.offset(x: -4) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary)
            if let rated = adapter.ratedWatts {
                Text("\(Int(rated))W rated")
                    .readout(10)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var title: String {
        if let description = adapter.description, !description.isEmpty {
            return description.capitalized
        }
        return contract == nil ? "Source" : "PD Source"
    }

    private func capabilityList(_ capabilities: [PowerDataObject]) -> some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 6, alignment: .leading),
                      GridItem(.flexible(), spacing: 6, alignment: .leading)],
            alignment: .leading, spacing: 3
        ) {
            ForEach(Array(capabilities.enumerated()), id: \.offset) { index, pdo in
                let selected = contract?.request?.objectPosition == index + 1
                HStack(spacing: 4) {
                    Circle()
                        .fill(selected ? Theme.live : Theme.idle)
                        .frame(width: 4, height: 4)
                    Text(pdo.label)
                        .readout(9.5, weight: selected ? .semibold : .regular)
                        .foregroundStyle(selected ? .primary : .secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    /// Strain relief where the cable enters the housing.
    private var cableEntry: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(Theme.metal.opacity(0.4))
            .frame(width: 9, height: 14)
    }
}

/// Shown when a port is occupied but nothing announced itself as a source:
/// a display, a dock's upstream link, a plain data cable.
struct PassiveEndView: View {
    let transports: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No PD source")
                .font(.system(size: 11, weight: .semibold))
            Text(transports.isEmpty ? "Data only" : transports.joined(separator: " · "))
                .readout(10)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .frame(width: 168, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(
                    Theme.idle,
                    style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                )
        )
    }
}

/// The far end of an empty port. Keeps the diagram's footprint so switching
/// between ports does not resize the panel.
struct EmptyEndView: View {
    let portName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Nothing connected")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("\(portName) is idle")
                .readout(10)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .frame(width: 168, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Theme.idle, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        )
    }
}
