import SplitTunnelCore
import SwiftUI

struct MainWindowView: View {
    @Environment(AppModel.self) private var model
    @State private var input = ""
    @State private var replacing = false
    @State private var removing: [String] = []

    var body: some View {
        @Bindable var model = model
        Group {
            if model.state.hasConfig && !replacing {
                content
            } else {
                OnboardingView(onFinish: model.state.hasConfig ? { replacing = false } : nil)
            }
        }
        .sheet(isPresented: $model.showUpdateSheet) { UpdateTunnelView() }
    }

    private var content: some View {
        let state = model.state
        let nets = state.computedAllowedIPs
        let v4 = nets.filter { !$0.isV6 }.count
        return VStack(alignment: .leading, spacing: 12) {
            GroupBox {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(state.tunnelName ?? "").bold()
                            Text("Server \(state.endpoint ?? "") · AllowedIPs: \(v4) IPv4 ranges, \(nets.count - v4) IPv6")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Replace…") { model.errorMessage = nil; replacing = true }
                    }
                    Toggle("Local network bypasses the VPN", isOn: Binding(get: { state.bypassesLocal }, set: { model.state.setBypassLocal($0) }))
                    Text("Router, printers, AirPlay and other devices at home. The tunnel's own address and DNS always stay in the tunnel.")
                        .font(.caption).foregroundStyle(.secondary)
                    let manual = state.configExclusions
                    if !manual.isEmpty {
                        DisclosureGroup("Already excluded in the config: \(manual.count) ranges") {
                            Text(manual.map(\.description).joined(separator: ", "))
                                .font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                        }
                    }
                }
            }

            HStack {
                TextField("Site address: 4pda.to or https://4pda.to/forum/…", text: $input)
                    .onSubmit(add)
                Button("Add", action: add)
            }
            Text("If a site opens only partly, add the domains of its images and CDN.")
                .font(.caption).foregroundStyle(.secondary)
            if let error = model.errorMessage { Text(error).foregroundStyle(.red) }

            Table(model.sortedSites) {
                TableColumn("Site") { Text($0.domain).bold() }
                TableColumn("IP addresses") { site in
                    VStack(alignment: .leading) {
                        ForEach(site.seen, id: \.self) { ip in
                            Text(site.newIPs.contains(ip) ? "+ \(ip.addressString)" : ip.addressString)
                                .foregroundStyle(site.newIPs.contains(ip) ? .orange : .secondary)
                        }
                    }
                    .font(.system(.caption, design: .monospaced))
                }
                TableColumn("Route") { site in
                    if site.status?.reply == .notFound {
                        Text(verbatim: "—").foregroundStyle(.secondary)
                    } else {
                        Label(site.hasNewIPs ? String(localized: "new IP goes through VPN") : routeText(site.status?.route ?? .unknown),
                              systemImage: "circle.fill")
                            .foregroundStyle(color(site.status?.level))
                    }
                }
                TableColumn("Response") { Text($0.status.map { replyText($0.reply) } ?? "—") }
                TableColumn("") { site in
                    Button("Remove", systemImage: "trash") { removing = [site.domain] }.labelStyle(.iconOnly).buttonStyle(.borderless).help("Remove")
                }
                .width(30)
            }
            .contextMenu(forSelectionType: Site.ID.self) { ids in
                Button("Remove", systemImage: "trash") { removing = Array(ids) }
            }

            HStack {
                if let last = state.lastCheck {
                    Text("Checked at \(last.formatted(date: .omitted, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Check Now") { Task { await model.checkNow() } }.disabled(model.checking)
                Button {
                    model.showUpdateSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Text("Update in WireGuard…")
                        if state.pendingChanges > 0 {
                            Text(verbatim: "\(state.pendingChanges)").monospacedDigit().font(.caption.bold()).foregroundStyle(.white)
                                .padding(.horizontal, 6).background(.orange, in: Capsule())
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            Divider()
            HStack {
                Text("Split Tunnel \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev") · the config stays on this Mac")
                    .lineLimit(1)
                if let update = model.availableUpdate {
                    Link("Version \(update.tag_name) is available — download", destination: update.html_url)
                }
                Spacer()
                Link("☕ Buy the author a coffee", destination: coffeeURL).fixedSize()
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(minWidth: 680, minHeight: 440)
        .confirmationDialog(removalTitle,
                            isPresented: Binding(get: { !removing.isEmpty }, set: { if !$0 { removing = [] } }),
                            titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                removing.forEach { model.state.removeSite($0) }
                removing = []
            }
            Button("Cancel", role: .cancel) { removing = [] }
        }
    }

    private var removalTitle: Text {
        removing.count == 1 ? Text("Remove \(removing[0])?") : Text("Remove \(removing.count) sites?")
    }

    private func add() {
        if model.addSite(input) { input = "" }
    }
}

func color(_ level: Level?) -> Color {
    switch level {
    case .good: .green
    case .warn: .orange
    case .bad: .red
    case .idle, nil: .secondary
    }
}
