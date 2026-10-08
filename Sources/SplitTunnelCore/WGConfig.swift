import Foundation

public struct WGConfig: Equatable, Sendable {
    public var allowedIPs: [IPNet]
    public var endpoint: String
    /// The tunnel's own `[Interface]` Address subnets and DNS server IPs: they must stay in the tunnel.
    public var keepInTunnel: [IPNet] = []
}

public enum ConfigError: Error, Equatable, Sendable {
    case noPeer, multiplePeers, noAllowedIPs, noEndpoint, badAddress(String)
}

/// Lines split on the "\n" scalar. Swift folds "\r\n" into one Character, so a Character split would
/// never break CRLF configs; this keeps the "\r" on each line, where the replacement needs it.
private func lines(_ text: String) -> [Substring] {
    text.unicodeScalars.split(separator: "\n", omittingEmptySubsequences: false).map { Substring($0) }
}

/// Splits a config line into (lowercased key, value), ignoring comments. Nil for headers, blanks and junk.
private func keyValue(_ raw: Substring) -> (key: String, value: String)? {
    let line = raw.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)[0]
    guard let eq = line.firstIndex(of: "=") else { return nil }
    let key = line[..<eq].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return (key, line[line.index(after: eq)...].trimmingCharacters(in: .whitespacesAndNewlines))
}

/// Section header in lowercase (`[peer]`) if the line is one; a trailing `# comment` is ignored.
private func section(_ raw: Substring) -> String? {
    let line = raw.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)[0]
        .trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return line.hasPrefix("[") ? line : nil
}

/// Reads what the app needs from a WireGuard config. The private key is deliberately ignored.
public func parseConfig(_ text: String) throws(ConfigError) -> WGConfig {
    var peers = 0, inPeer = false, inInterface = false
    var allowed: [IPNet] = [], endpoint = "", addresses: [IPNet] = [], dns: [IPNet] = []
    for raw in lines(text) {
        if let name = section(raw) {
            inPeer = name == "[peer]"
            inInterface = name == "[interface]"
            if inPeer { peers += 1 }
            continue
        }
        guard let (key, value) = keyValue(raw) else { continue }
        if inInterface {
            let items = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            // Address keeps its subnet; DNS takes bare IPs only (hostnames and search domains do not parse).
            if key == "address" { addresses += items.compactMap { IPNet($0) } }
            else if key == "dns" { dns += items.filter { !$0.contains("/") }.compactMap { IPNet($0) } }
            continue
        }
        guard inPeer else { continue }
        if key == "allowedips" {
            for item in value.split(separator: ",") {
                let text = item.trimmingCharacters(in: .whitespaces)
                if text.isEmpty { continue }
                guard let net = IPNet(text) else { throw ConfigError.badAddress(text) }
                allowed.append(net)
            }
        } else if key == "endpoint" {
            endpoint = value
        }
    }
    guard peers > 0 else { throw ConfigError.noPeer }
    guard peers == 1 else { throw ConfigError.multiplePeers }
    guard !allowed.isEmpty else { throw ConfigError.noAllowedIPs }
    guard !endpoint.isEmpty else { throw ConfigError.noEndpoint }
    return WGConfig(allowedIPs: allowed, endpoint: endpoint, keepInTunnel: addresses + dns)
}

public func allowedIPsLine(_ nets: [IPNet]) -> String {
    "AllowedIPs = " + nets.map(\.description).joined(separator: ", ")
}

/// Puts one AllowedIPs line where the first one was; every other line is kept as is.
public func replacingAllowedIPs(in text: String, with nets: [IPNet]) -> String {
    var inPeer = false, replaced = false
    var out: [String] = []
    for raw in lines(text) {
        if let name = section(raw) { inPeer = name == "[peer]" }
        if inPeer, keyValue(raw)?.key == "allowedips" {
            if !replaced { out.append(allowedIPsLine(nets) + (raw.hasSuffix("\r") ? "\r" : "")) }
            replaced = true
            continue
        }
        out.append(String(raw))
    }
    return out.joined(separator: "\n")
}

/// The tunnel's name in WireGuard: the file name, or the endpoint host for a pasted config.
public func makeTunnelName(fileName: String?, endpoint: String) -> String {
    if let fileName, !fileName.isEmpty { return ((fileName as NSString).lastPathComponent as NSString).deletingPathExtension }
    guard let host = URL(string: "wg://" + endpoint)?.host(percentEncoded: false), !host.isEmpty else { return endpoint }
    return host
}
