import Charts
import PortAuthorityKit
import SwiftUI

/// Power, voltage and current on one chart, for the whole time the cable has
/// been in.
///
/// The three quantities share an axis but not a unit -- 100W, 20V and 5A on a
/// common scale would flatten voltage and current into the floor. Each series
/// is therefore drawn against its own full scale, taken from what the source
/// advertises, and the legend carries the real values. The axis is labelled
/// as relative so the normalisation is not passed off as absolute.
struct PowerChart: View {
    let trace: PowerTrace
    let contract: PDContract?

    private struct Point: Identifiable {
        let id: Int
        let elapsed: TimeInterval
        let value: Double
        let series: String
    }

    private enum Series {
        static let power = "Power"
        static let voltage = "Voltage"
        static let current = "Current"
        static let data = "Data"
        static let order = [power, voltage, current, data]
        static let colors: [String: Color] = [
            power: .green, voltage: .red, current: .blue, data: .purple,
        ]
    }

    // Full scales come from the negotiated contract where possible, so the
    // trace is shown against what this source can actually deliver.
    private var wattsScale: Double {
        max(contract?.contractWatts ?? 0, trace.peak(\.watts), 1)
    }
    private var voltsScale: Double {
        max(contract?.sourceCapabilities.compactMap(maxVolts).max() ?? 0, trace.peak(\.volts), 1)
    }
    private var hasData: Bool { trace.peak(\.dataGbps) > 0 }

    private var dataScale: Double { max(trace.peak(\.dataGbps), 1) }

    private var ampsScale: Double {
        max(contract?.sourceCapabilities.compactMap(maxAmps).max() ?? 0, trace.peak(\.amps), 1)
    }

    private func maxVolts(_ pdo: PowerDataObject) -> Double? {
        switch pdo {
        case .fixed(let volts, _, _, _): return volts
        case .programmable(_, let hi, _), .adjustable(_, let hi, _),
             .variable(_, let hi, _), .battery(_, let hi, _): return hi
        }
    }

    private func maxAmps(_ pdo: PowerDataObject) -> Double? {
        switch pdo {
        case .fixed(_, let amps, _, _), .variable(_, _, let amps),
             .programmable(_, _, let amps): return amps
        case .battery, .adjustable: return nil
        }
    }

    private var points: [Point] {
        var result: [Point] = []
        result.reserveCapacity(trace.samples.count * 3)
        for (index, sample) in trace.samples.enumerated() {
            result.append(Point(id: index * 3, elapsed: sample.elapsed,
                                value: sample.watts / wattsScale, series: Series.power))
            result.append(Point(id: index * 3 + 1, elapsed: sample.elapsed,
                                value: sample.volts / voltsScale, series: Series.voltage))
            result.append(Point(id: index * 3 + 2, elapsed: sample.elapsed,
                                value: sample.amps / ampsScale, series: Series.current))
            if hasData {
                result.append(Point(id: index * 3 + 100_000, elapsed: sample.elapsed,
                                    value: sample.dataGbps / dataScale, series: Series.data))
            }
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            legend
            if trace.samples.count < 2 {
                waiting
            } else {
                chart
            }
            footnote
        }
    }

    private var chart: some View {
        Chart(points) { point in
            LineMark(
                x: .value("Elapsed", point.elapsed),
                y: .value("Relative", point.value)
            )
            .foregroundStyle(by: .value("Series", point.series))
            .interpolationMethod(.monotone)
            .lineStyle(StrokeStyle(lineWidth: 1.6))
        }
        .chartForegroundStyleScale(domain: Series.order, range: Series.order.map { Series.colors[$0]! })
        .chartLegend(.hidden)
        .chartYScale(domain: 0...1.05)
        // End the axis where the data ends; the default domain padded past
        // the session and implied minutes that had not happened yet.
        .chartXScale(domain: 0...max(trace.duration, 1))
        .chartYAxis {
            AxisMarks(values: [0, 0.5, 1.0]) { value in
                AxisGridLine().foregroundStyle(Color.primary.opacity(0.10))
                AxisValueLabel {
                    if let fraction = value.as(Double.self) {
                        Text("\(Int(fraction * 100))%").font(.system(size: 8))
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(preset: .aligned) { value in
                AxisGridLine().foregroundStyle(Color.primary.opacity(0.08))
                AxisValueLabel {
                    if let seconds = value.as(Double.self) {
                        Text(Self.clock(seconds)).font(.system(size: 8))
                    }
                }
            }
        }
        .frame(height: 118)
    }

    private var waiting: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(Theme.idle, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            .frame(height: 118)
            .overlay(
                Text("Collecting…").readout(10).foregroundStyle(.secondary)
            )
    }

    private var legend: some View {
        HStack(spacing: 12) {
            legendItem(Series.power, .green, latest.map { "\(Watts.short($0.watts))W" }, wattsScale, "W")
            legendItem(Series.voltage, .red, latest.map { trimmed($0.volts) + "V" }, voltsScale, "V")
            legendItem(Series.current, .blue, latest.map { trimmed($0.amps) + "A" }, ampsScale, "A")
            if hasData {
                legendItem(
                    Series.data, .purple,
                    latest.map { String(format: "%.1f", $0.dataGbps) + "Gb/s" },
                    dataScale, "Gb/s"
                )
            }
            Spacer(minLength: 0)
        }
    }

    private var latest: PowerSample? { trace.samples.last }

    private func legendItem(
        _ name: String, _ color: Color, _ value: String?, _ scale: Double, _ unit: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 1).fill(color).frame(width: 9, height: 2.5)
                Text(value ?? "--").readout(11, weight: .semibold)
            }
            Text("of \(trimmed(scale))\(unit)")
                .font(.system(size: 8))
                .foregroundStyle(.tertiary)
        }
    }

    private var footnote: some View {
        Text(note)
            .font(.system(size: 8.5))
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var note: String {
        var text = "Each series scaled to its own maximum. Power is measured; "
        text += "voltage is the negotiated contract, so current, derived from both, "
        text += "tracks power until the contract changes."
        if hasData {
            text += " Data is the video stream (pixels x refresh x depth); "
            text += "DisplayPort has no throughput counter, so it is flat by nature."
        }
        if trace.interval > 1 {
            text += " Resolution \(Int(trace.interval))s."
        }
        return text
    }

    private func trimmed(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }

    static func clock(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        if total >= 3600 {
            return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
        }
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
