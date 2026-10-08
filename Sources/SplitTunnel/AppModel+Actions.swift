import AppKit
import SplitTunnelCore
import UniformTypeIdentifiers

extension AppModel {
    func loadConfig(text: String, fileName: String?) -> Bool {
        let config: WGConfig
        do { config = try parseConfig(text) } catch {
            errorMessage = configErrorText(error)
            return false
        }
        errorMessage = nil // before the mutation: its didSet may raise a save error that must stay
        state.load(config: config, fileName: fileName)
        Task { await checkNow() }
        return true
    }

    func addSite(_ input: String) -> Bool {
        guard let domain = normalizeDomain(input) else {
            errorMessage = String(localized: "Enter a site address, for example 4pda.to")
            return false
        }
        errorMessage = nil // before the mutation: its didSet may raise a save error that must stay
        guard state.addSite(domain) else {
            errorMessage = String(localized: "\(domain) is already in the list")
            return false
        }
        if state.sites.count == 1 { notifier.requestPermission() }
        Task { await checkNow() }
        return true
    }

    func copyAllowedIPs() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(allowedIPsLine(state.computedAllowedIPs), forType: .string)
        state.markExported()
    }

    /// Asks the user for a .conf file and reads it; nil if cancelled or unreadable (then `errorMessage` says why).
    func pickConfText(message: String?) -> (text: String, url: URL)? {
        NSApp.activate()
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "conf") ?? .plainText, .plainText]
        if let message { panel.message = message }
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            errorMessage = String(localized: "Could not read the file.")
            return nil
        }
        return (text, url)
    }

    /// Asks for the original .conf (the private key is read from it, never stored), then where to save the new one.
    func saveConf() {
        guard let (text, _) = pickConfText(message: String(localized: "Choose the original WireGuard config. The private key is read from it and not stored.")) else { return }
        let config: WGConfig
        do { config = try parseConfig(text) } catch {
            errorMessage = configErrorText(error)
            return
        }
        guard config.endpoint == state.endpoint else {
            errorMessage = String(localized: "This is a different config: its server does not match \(state.endpoint ?? "").")
            return
        }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(state.tunnelName ?? "tunnel").conf"
        guard panel.runModal() == .OK, let target = panel.url else { return }
        let data = Data(replacingAllowedIPs(in: text, with: state.computedAllowedIPs).utf8)
        // The file holds the private key. open(2) creates the temp file 0600 in one step (umask can only narrow it),
        // and rename(2) atomically swaps it in place of the target, so the key is never readable by others even
        // briefly, and a failure never destroys the existing file.
        let temp = target.deletingLastPathComponent().appending(path: ".\(target.lastPathComponent).\(UUID().uuidString).tmp")
        let fd = open(temp.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
        guard fd >= 0 else {
            errorMessage = String(localized: "Could not save the file.")
            return
        }
        // ponytail: one write() call; a config is a few KB, so a short write is treated as failure, not retried.
        let written = data.withUnsafeBytes { write(fd, $0.baseAddress, $0.count) }
        let closed = close(fd) == 0
        guard written == data.count, closed, rename(temp.path, target.path) == 0 else {
            unlink(temp.path)
            errorMessage = String(localized: "Could not save the file.")
            return
        }
        errorMessage = nil
        state.markExported()
    }

    func openWireGuard() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: wireGuardBundleID) else {
            errorMessage = String(localized: "WireGuard is not installed.")
            return
        }
        NSWorkspace.shared.openApplication(at: url, configuration: .init())
    }

    /// Opens the main window with the "Update in WireGuard" sheet.
    func requestUpdate() {
        showUpdateSheet = true
        openMainWindow()
    }

    func save() {
        guard canSave else {
            errorMessage = String(localized: "Settings file is unreadable and could not be moved aside; changes will not be saved.")
            return
        }
        do { try state.save(to: Self.stateURL) } catch { errorMessage = String(localized: "Could not save settings: \(error.localizedDescription)") }
    }
}
