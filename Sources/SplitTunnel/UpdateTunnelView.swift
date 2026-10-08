import SwiftUI

struct UpdateTunnelView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        let nets = model.state.computedAllowedIPs
        let v4 = nets.filter { !$0.isV6 }.count, v6 = nets.count - v4
        VStack(alignment: .leading, spacing: 14) {
            Text("Update tunnel \(model.state.tunnelName ?? "")").font(.headline)
            Text("New AllowedIPs are ready: \(v4) IPv4 ranges, \(v6) IPv6. Choose a way.")
            HStack(alignment: .top, spacing: 12) {
                way(title: "Replace one line",
                    note: "Tunnel settings and On-Demand rules are kept",
                    steps: ["Click Copy.", "In WireGuard select the tunnel and click Edit.", "Replace the AllowedIPs line and click Save."],
                    recommended: true) {
                    Button { model.copyAllowedIPs(); copied = true } label: { copied ? Text("Copied") : Text("Copy AllowedIPs") }
                        .buttonStyle(.borderedProminent)
                }
                way(title: "Import a file",
                    note: "On-Demand rules have to be set up again",
                    steps: ["Save the .conf file.", "In WireGuard delete the old tunnel.", "Import the tunnel from the file and turn it on."],
                    recommended: false) {
                    Button("Save .conf…") { model.saveConf() }
                }
            }
            if let error = model.errorMessage { Text(error).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                Button("Open WireGuard") { model.openWireGuard() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 620)
        .onAppear { model.errorMessage = nil }
    }

    private func way(title: LocalizedStringKey, note: LocalizedStringKey, steps: [LocalizedStringKey],
                     recommended: Bool, @ViewBuilder action: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).bold()
            Text(note).font(.caption).foregroundStyle(.secondary)
            ForEach(steps.indices, id: \.self) { i in
                HStack(alignment: .top) { Text("\(i + 1).").monospacedDigit(); Text(steps[i]) }
            }
            action()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 9).strokeBorder(recommended ? Color.accentColor : .secondary.opacity(0.3)))
    }
}
