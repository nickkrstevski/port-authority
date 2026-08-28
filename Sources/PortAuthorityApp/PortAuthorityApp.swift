import SwiftUI

@main
struct PortAuthorityApp: App {
    @StateObject private var model = AppModel()

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
