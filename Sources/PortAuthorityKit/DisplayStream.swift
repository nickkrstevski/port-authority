import CoreGraphics
import Foundation

/// The video stream running over a port's DisplayPort lanes.
///
/// DisplayPort is not packet-switched and has no throughput counter to read.
/// The link transmits continuously at its negotiated rate whether the picture
/// is moving or frozen, so there is no varying "throughput" to sample. What
/// is exactly computable is the stream itself: pixels x refresh x depth. That
/// figure is real data crossing the cable, and it is constant until the
/// display mode changes.
public struct DisplayStream: Codable, Sendable, Equatable {
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let refreshHz: Double
    /// Assumed, not read: macOS does not expose the negotiated bit depth
    /// through a supported API, and 8 bits per component is the common case.
    public let bitsPerPixel: Int

    public init(pixelWidth: Int, pixelHeight: Int, refreshHz: Double, bitsPerPixel: Int = 24) {
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.refreshHz = refreshHz
        self.bitsPerPixel = bitsPerPixel
    }

    /// Active pixel data only. Real links also carry blanking intervals and
    /// line coding on top of this, so the wire rate is higher; this is the
    /// payload, which is the honest thing to call "data".
    public var bitsPerSecond: Double {
        Double(pixelWidth) * Double(pixelHeight) * refreshHz * Double(bitsPerPixel)
    }

    public var gigabitsPerSecond: Double { bitsPerSecond / 1_000_000_000 }

    public var modeLabel: String {
        "\(pixelWidth)x\(pixelHeight) @ \(Int(refreshHz.rounded()))Hz"
    }
}

public enum DisplayReader {

    /// External displays only; the built-in panel is not on a USB-C port.
    public static func externalStreams() -> [DisplayStream] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }

        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return [] }

        return ids.compactMap { id in
            guard CGDisplayIsBuiltin(id) == 0,
                  let mode = CGDisplayCopyDisplayMode(id)
            else { return nil }

            // Refresh comes back as 0 on links that do not report it; without
            // it there is no bandwidth to compute, so skip rather than invent
            // a rate.
            let refresh = mode.refreshRate
            guard refresh > 0 else { return nil }

            return DisplayStream(
                pixelWidth: mode.pixelWidth,
                pixelHeight: mode.pixelHeight,
                refreshHz: refresh
            )
        }
    }
}
