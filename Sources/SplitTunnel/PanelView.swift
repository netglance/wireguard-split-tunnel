import AppKit
import SplitTunnelCore
import SwiftUI

struct PanelView: View {
    @Environment(AppModel.self) private var model
    @State private var login = LoginItem.isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Split Tunnel").font(.headline)
                Spacer()
                if model.state.hasConfig, let up = model.tunnelUp {
                    (up ? Text("Tunnel on") : Text("Tunnel off")).font(.caption).foregroundStyle(.secondary)
                }
            }
            if model.state.hasConfig {
                banner
                if model.showCoffee { coffee }
                ForEach(model.sortedSites) { site in
                    HStack {
                        Circle().fill(color(site.status?.level)).frame(width: 8, height: 8)
                        Text(site.domain)
                        Spacer()
                        Text(siteSummary(site)).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Divider()
                footer
            } else {
                Text("Load a WireGuard config to start.").foregroundStyle(.secondary)
                Button("Load Config…") { model.openMainWindow() }.buttonStyle(.borderedProminent)
            }
        }
        .padding(12)
        .frame(width: 340)
        .onAppear { login = LoginItem.isEnabled } // the user may have changed it in System Settings
    }

    @ViewBuilder private var banner: some View {
        switch model.banner {
        case .noNetwork:
            box(.secondary, "No network", "The check will run when the connection is back.")
        case .problem(let site) where site.status?.reply == .notFound:
            box(.red, "\(site.domain): \(replyText(.notFound))", "The address does not resolve. Check the spelling.")
        case .problem(let site):
            box(.red, "\(site.domain): \(replyText(site.status?.reply ?? .noResponse))",
                site.status?.route == .tunnel ? "The site goes through the VPN and blocks it. Update AllowedIPs in WireGuard."
                    : "The site blocks this connection even without the VPN; the tunnel is not the cause.",
                action: site.status?.route == .tunnel ? "Update in WireGuard…" : nil)
        case .awaiting:
            box(.orange, "Waiting for you to update the tunnel", "WireGuard still uses the old AllowedIPs.", action: "Show Steps")
        case .newIP(let site):
            box(.orange, "\(site.domain) has a new IP", "It goes through the VPN for now. Update AllowedIPs in WireGuard.", action: "Update in WireGuard…")
        case .outdated:
            box(.orange, "AllowedIPs in WireGuard are out of date", "Update AllowedIPs in WireGuard.", action: "Update in WireGuard…")
        case .viaVPN(let site):
            box(.orange, "\(site.domain) goes through the VPN", "Update AllowedIPs in WireGuard.", action: "Update in WireGuard…")
        case .tunnelOff:
            box(.secondary, "The WireGuard tunnel is off", "All traffic bypasses the VPN. The route is checked when the tunnel is on.")
        case .allGood(let count):
            box(.green, "Sites bypassing the VPN: \(count)", nil)
        case .noSites:
            box(.secondary, "No sites yet", "Add a site in the window.", action: "Open Window", perform: { model.openMainWindow() })
        }
    }

    /// Banner with one optional action; by default the action opens the "Update in WireGuard" sheet.
    private func box(_ tint: Color, _ title: LocalizedStringKey, _ text: LocalizedStringKey?,
                     action: LocalizedStringKey? = nil, perform: (() -> Void)? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).bold()
            if let text { Text(text) }
            if let action {
                Button(action) { (perform ?? model.requestUpdate)() }.buttonStyle(.borderedProminent)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 9))
    }

    private var coffee: some View {
        HStack {
            Text("Was the app useful?")
            Link("☕ Buy the author a coffee", destination: coffeeURL)
            Spacer()
            Button("Hide forever", systemImage: "xmark") { model.state.coffeeDismissed = true }.labelStyle(.iconOnly).buttonStyle(.plain)
        }
        .font(.caption)
    }

    private var footer: some View {
        HStack {
            if let last = model.state.lastCheck {
                Text("Checked at \(last.formatted(date: .omitted, time: .shortened))").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Check Now", systemImage: "arrow.clockwise") { Task { await model.checkNow() } }
                .labelStyle(.iconOnly).disabled(model.checking)
            Button("Open Window", systemImage: "macwindow") { model.openMainWindow() }.labelStyle(.iconOnly)
            Menu {
                // A Binding, not .onChange: a failed register() must not re-fire the setter and trigger a spurious unregister().
                Toggle("Open at Login", isOn: Binding(get: { login }, set: { LoginItem.set($0); login = LoginItem.isEnabled }))
                Link("Support the Author…", destination: coffeeURL)
                Divider()
                Button("Quit") { NSApp.terminate(nil) }
            } label: { Label("More", systemImage: "ellipsis").labelStyle(.iconOnly) }
                .menuStyle(.borderlessButton).fixedSize()
        }
        .buttonStyle(.borderless)
    }
}
