import PortAuthorityKit
import SwiftUI

/// Physical geometry of the machine, in millimetres, drawn to scale.
///
/// Provenance matters here, so every number is tagged:
///
///   [APPLE]    published by Apple in the tech specs
///   [SPEC]     fixed by the connector standard
///   [DEVICE]   read from this machine's own device tree at runtime
///   [ESTIMATE] not published anywhere I could find; see the note below
///
/// Apple gives the body size and which ports are on which side, but not where
/// along an edge any port sits, and teardowns do not dimension them either.
/// The distances below are therefore estimates, isolated in one table so they
/// can be replaced with ruler measurements without touching anything else.
enum MachineGeometry {

    // MARK: body

    /// MacBook Pro 14-inch (Nov 2024): 31.26cm x 22.12cm x 1.55cm. [APPLE]
    /// The machine identifies itself as "MacBook Pro (14-inch, Nov 2024)" in
    /// the device tree; do not infer the size from the model identifier.
    static let bodyWidth: Double = 312.6
    static let bodyDepth: Double = 221.2
    /// [ESTIMATE] Apple does not publish the corner radius.
    static let cornerRadius: Double = 11.0

    // MARK: port openings

    /// USB Type-C receptacle opening. [SPEC]
    static let usbCWidth: Double = 8.34
    /// HDMI Type A receptacle opening. [SPEC]
    static let hdmiWidth: Double = 14.0
    /// SD card is 24mm across, so the slot is a little wider. [SPEC]
    static let sdWidth: Double = 24.5
    /// 3.5mm jack, with its bezel. [SPEC]
    static let audioWidth: Double = 4.0
    /// MagSafe 3 connector is 13.21mm wide. [VENDOR] -- published by cable
    /// manufacturers, not by Apple, so weaker than the [SPEC] figures above.
    static let magSafeWidth: Double = 13.21

    // MARK: layout

    enum Side { case left, right }

    enum Fixture {
        case magSafe
        case usbC(PortLocation)
        case hdmi
        case sdCard
        case audio

        /// Only the power ports are selectable; the rest are context.
        var interactive: Bool {
            switch self {
            case .magSafe, .usbC: return true
            case .hdmi, .sdCard, .audio: return false
            }
        }

        var width: Double {
            switch self {
            case .magSafe: return MachineGeometry.magSafeWidth
            case .usbC: return MachineGeometry.usbCWidth
            case .hdmi: return MachineGeometry.hdmiWidth
            case .sdCard: return MachineGeometry.sdWidth
            case .audio: return MachineGeometry.audioWidth
            }
        }

        var label: String {
            switch self {
            case .magSafe: return "MagSafe 3"
            case .usbC: return "Thunderbolt"
            case .hdmi: return "HDMI"
            case .sdCard: return "SDXC"
            case .audio: return "Headphones"
            }
        }
    }

    struct Placement {
        let fixture: Fixture
        let side: Side
        /// Centre of the opening, millimetres from the rear (hinge) edge.
        let fromRear: Double
    }

    /// Which ports are on which side is [APPLE]. The left-hand USB-C ordering
    /// is [DEVICE] -- the device tree labels them left-back and left-front,
    /// which is how we know which is which. Every `fromRear` value is
    /// [ESTIMATE].
    static let placements: [Placement] = [
        Placement(fixture: .magSafe, side: .left, fromRear: 42),
        Placement(fixture: .usbC(.leftBack), side: .left, fromRear: 68),
        Placement(fixture: .usbC(.leftFront), side: .left, fromRear: 92),
        Placement(fixture: .audio, side: .left, fromRear: 118),

        // Right side runs HDMI, Thunderbolt, SDXC from the rear. [PHOTO]
        // -- read off Apple's own labelled product shot of both sides.
        Placement(fixture: .hdmi, side: .right, fromRear: 42),
        Placement(fixture: .usbC(.right), side: .right, fromRear: 68),
        Placement(fixture: .sdCard, side: .right, fromRear: 100),
    ]

    // MARK: interior

    /// Keyboard well, trackpad and speaker grilles. All [ESTIMATE], scaled to
    /// look right against the body rather than measured.
    static let keyboardWidth: Double = 250
    static let keyboardDepth: Double = 96
    static let keyboardFromRear: Double = 52
    static let trackpadWidth: Double = 130
    static let trackpadDepth: Double = 82
    static let speakerWidth: Double = 26
}
