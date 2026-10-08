import Foundation
import ServiceManagement
import SplitTunnelCore

enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Split Tunnel: login item change failed: \(error)")
        }
    }
}

let coffeeURL = URL(string: "https://buymeacoffee.com/vpotar")!
let wireGuardBundleID = "com.wireguard.macos"
private let releasesURL = URL(string: "https://api.github.com/repos/netglance/wireguard-split-tunnel/releases/latest")!

/// IPv4 and IPv6 addresses for a host via the system resolver — the same answers the browser gets. May repeat; callers dedup.
func resolve(_ host: String) async -> [IPNet] {
    await Task.detached {
        var hints = addrinfo()
        hints.ai_socktype = SOCK_STREAM
        var list: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, nil, &hints, &list) == 0, let first = list else { return [] }
        defer { freeaddrinfo(first) }
        return sequence(first: first, next: { $0.pointee.ai_next }).compactMap { info in
            var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(info.pointee.ai_addr, info.pointee.ai_addrlen, &buffer, socklen_t(buffer.count),
                              nil, 0, NI_NUMERICHOST) == 0 else { return nil }
            // Scoped link-local addresses ("fe80::1%en0") fail to parse and are skipped on purpose.
            return IPNet(buffer.withUnsafeBufferPointer { String(cString: $0.baseAddress!) })
        }
    }.value
}

/// Interface the system would use to reach `ip`, from `route -n get`.
/// nil only when the command could not run; "none" when it ran but found no route.
func routeInterface(_ ip: IPNet) async -> String? {
    await Task.detached {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/route")
        process.arguments = ["-n", "get"] + (ip.isV6 ? ["-inet6"] : []) + [ip.addressString]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        // ponytail: fixed 5 s watchdog; a killed route closes the pipe, which ends the read below. Not configurable.
        // terminate() sends SIGTERM only, so a route stuck in uninterruptible kernel sleep would still block the read;
        // add SIGKILL (kill(process.processIdentifier, SIGKILL)) if that is ever seen.
        DispatchQueue.global().asyncAfter(deadline: .now() + 5) { if process.isRunning { process.terminate() } }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationReason == .exit else { return nil } // killed by the watchdog: route could not run
        // No route at all (e.g. no IPv6 route): certainly not via the tunnel.
        return parseRouteInterface(String(decoding: data, as: UTF8.self)) ?? "none"
    }.value
}

private let probeSession: URLSession = {
    let config = URLSessionConfiguration.ephemeral
    config.timeoutIntervalForRequest = 10
    config.timeoutIntervalForResource = 10
    return URLSession(configuration: config)
}()

/// Safari's user agent: CFNetwork's default one gets bot challenges even without a VPN.
private let browserUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"

func probeHTTP(_ domain: String) async -> Reply {
    guard let url = URL(string: "https://\(domain)/") else { return .noResponse }
    var request = URLRequest(url: url)
    request.setValue(browserUserAgent, forHTTPHeaderField: "User-Agent")
    guard let (_, response) = try? await probeSession.data(for: request),
          let http = response as? HTTPURLResponse else { return .noResponse }
    return classify(status: http.statusCode, cfMitigated: http.value(forHTTPHeaderField: "cf-mitigated"))
}

struct Release: Decodable { let tag_name: String; let html_url: URL }

func latestRelease() async -> Release? {
    guard let (data, _) = try? await probeSession.data(from: releasesURL) else { return nil }
    return try? JSONDecoder().decode(Release.self, from: data)
}
