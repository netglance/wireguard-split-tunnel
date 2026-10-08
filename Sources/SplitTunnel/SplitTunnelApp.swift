import AppKit
import SplitTunnelCore
import SwiftUI

@main
struct SplitTunnelApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            PanelView().environment(model)
        } label: {
            MenuBarLabel().environment(model)
        }
        .menuBarExtraStyle(.window)

        Window("Split Tunnel", id: "main") {
            MainWindowView().environment(model)
        }
        .defaultLaunchBehavior(.suppressed)
        .windowResizability(.contentMinSize)
    }
}

struct MenuBarLabel: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(nsImage: menuBarImage(dot: model.iconDot == .bad ? .systemRed : model.iconDot == .warn ? .systemOrange : nil))
            .task {
                model.openMainWindow = { openWindow(id: "main"); NSApp.activate() }
                if !model.state.hasConfig { model.openMainWindow() }
            }
    }
}
