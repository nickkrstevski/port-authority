import Foundation

/// One second of the power trace for a port.
///
/// Only `watts` is directly measured (the SMC's input-power sensor). `volts`
/// is the negotiated contract voltage, so it steps when the contract changes
/// rather than tracking VBUS continuously, and `amps` is derived from the two.
/// The chart labels them accordingly rather than implying three independent
/// probes.
public struct PowerSample: Sendable, Equatable {
    public let elapsed: TimeInterval
    public let watts: Double
    public let volts: Double
    public let amps: Double
    /// Video stream bandwidth on the port's DisplayPort lanes, in Gb/s.
    /// Zero when no display is attributable to this port.
    public let dataGbps: Double

    public init(elapsed: TimeInterval, watts: Double, volts: Double, dataGbps: Double = 0) {
        self.elapsed = elapsed
        self.watts = watts
        self.volts = volts
        self.amps = volts > 0 ? watts / volts : 0
        self.dataGbps = dataGbps
    }
}

/// The trace for one plug-in session, from the moment the cable went in.
public struct PowerTrace: Sendable {
    /// Halving beyond this keeps the full time span at lower resolution,
    /// rather than dropping the beginning of the session.
    static let maximumSamples = 2000

    public private(set) var samples: [PowerSample] = []
    /// Seconds between stored samples; doubles each time the trace is halved.
    public private(set) var interval: TimeInterval = 1

    public init() {}

    public var duration: TimeInterval { samples.last?.elapsed ?? 0 }

    public mutating func append(_ sample: PowerSample) {
        samples.append(sample)
        if samples.count > Self.maximumSamples {
            // Keep every other sample so the session still starts where it
            // started; trimming the head would silently redefine "since
            // plugged in".
            samples = samples.enumerated().compactMap { $0.offset.isMultiple(of: 2) ? $0.element : nil }
            interval *= 2
        }
    }

    public func peak(_ keyPath: KeyPath<PowerSample, Double>) -> Double {
        samples.map { $0[keyPath: keyPath] }.max() ?? 0
    }
}
