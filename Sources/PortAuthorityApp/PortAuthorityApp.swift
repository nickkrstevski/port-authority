import SwiftUI

@main
struct PortAuthorityApp: App {
    @StateObject private var model = AppModel()

    init() {
        // Offline render mode for development: draw the panel to PNGs and
        // exit without ever showing a menu bar item.
        let arguments = CommandLine.arguments
        if let index = arguments.firstIndex(of: "--render"), index + 1 < arguments.count {
            PreviewRenderer.run(outputDirectory: arguments[index + 1])
            exit(0)
        }
    }

    var body: some Scene {
        MenuBarExtra {
            ContentView(model: model)
        } label: {
            HStack(spacing: 3) {
                Image(systemName: model.menuBarLabel.isEmpty ? "bolt.slash" : "bolt.fill")
                if !model.menuBarLabel.isEmpty {
                    Text(model.menuBarLabel)
                }
            }
            .onAppear { model.start() }
        }
        .menuBarExtraStyle(.window)
    }
}
