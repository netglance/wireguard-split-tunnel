import AppKit
import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var dropTargeted = false
    /// Set when shown over an existing config (Replace…): called after a successful load and by Cancel.
    var onFinish: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 8) {
                Image(systemName: "square.and.arrow.down").font(.largeTitle).foregroundStyle(.secondary)
                Text("Drop a .conf file here").font(.headline)
                HStack {
                    Button("Choose File…") {
                        if let picked = model.pickConfText(message: nil),
                           model.loadConfig(text: picked.text, fileName: picked.url.lastPathComponent) { onFinish?() }
                    }
                    Button("Paste from Clipboard") {
                        if model.loadConfig(text: NSPasteboard.general.string(forType: .string) ?? "", fileName: nil) { onFinish?() }
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 160)
            .background(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                .foregroundStyle(dropTargeted ? Color.accentColor : .secondary.opacity(0.5)))
            .dropDestination(for: URL.self) { urls, _ in
                guard let url = urls.first, url.isFileURL, let text = try? String(contentsOf: url, encoding: .utf8) else {
                    model.errorMessage = String(localized: "Could not read the file.")
                    return false
                }
                let ok = model.loadConfig(text: text, fileName: url.lastPathComponent)
                if ok { onFinish?() }
                return ok
            } isTargeted: { dropTargeted = $0 }

            if let error = model.errorMessage { Text(error).foregroundStyle(.red) }
            Text("No file? In WireGuard select the tunnel, click Edit and copy all the text. Or use Export Tunnels to Zip.")
                .font(.caption).foregroundStyle(.secondary)
            Text("The private key is not stored and never leaves this Mac.")
                .font(.caption).foregroundStyle(.secondary)
            if let onFinish {
                HStack { Spacer(); Button("Cancel", action: onFinish) }
            }
        }
        .padding(20)
        .frame(width: 440)
    }
}
