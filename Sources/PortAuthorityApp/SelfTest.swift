import AppKit
import SwiftUI

/// Reproduction harness for layout crashes.
///
/// The menu bar panel is a window that sizes itself to its content, so a view
/// reporting an invalid size takes the app down inside AppKit's constraint
/// pass rather than at the call site -- which is why the crash report points
/// at NSView and not at any of our code. This hosts the same view in a
/// window that also sizes to content and drives the same state the toggle
/// drives, so the exception surfaces on stderr where it can be read.
@MainActor
enum SelfTest {
    static var isActive: Bool { CommandLine.arguments.contains("--selftest") }

    static func run() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let model = AppModel()
        model.start()

        let hosting = NSHostingView(rootView: ContentView(model: model))
        // Match the panel: it propagates the view's size extrema onto the
        // window, which is the code path named in the crash report
        // (minSizeRoundedRespectingSizingOptions ->
        // updateWindowContentSizeExtremaIfNecessary).
        hosting.sizingOptions = [.minSize, .maxSize, .intrinsicContentSize]

        // MenuBarExtra(.window) hosts its content in a borderless,
        // non-activating floating panel, so the harness uses one too.
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 500),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        window.level = .popUpMenu
        window.isFloatingPanel = true
        window.hidesOnDeactivate = false
        window.contentView = hosting
        window.orderFront(nil)

        var flips = 0
        let timer = Timer(timeInterval: 0.5, repeats: true) { t in
            Task { @MainActor in
                flips += 1
                let next = !model.showChart
                FileHandle.standardError.write(Data("flip \(flips): chart=\(next)\n".utf8))
                withAnimation(.snappy(duration: 0.28)) { model.showChart = next }
                if flips >= 8 {
                    t.invalidate()
                    FileHandle.standardError.write(Data("SELFTEST SURVIVED\n".utf8))
                    exit(0)
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        app.run()
    }
}
