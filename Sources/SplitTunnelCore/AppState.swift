import Foundation

public struct Site: Codable, Equatable, Identifiable, Sendable {
    public var domain: String
    /// Every IP ever resolved for the site. Only grows, so the status does not flap
    /// when Cloudflare rotates addresses. ponytail: unbounded; add "reset site IPs" if lists get long.
    public var seen: [IPNet] = []
    /// IPs that were excluded in the AllowedIPs the user last copied or saved.
    public var exported: [IPNet] = []
    public var status: SiteStatus?

    public var id: String { domain }
    public var newIPs: Set<IPNet> { Set(seen).subtracting(exported) }
    public var hasNewIPs: Bool { !newIPs.isEmpty }
}

public struct SiteProbe: Sendable {
    public var domain: String
    public var route: Route
    public var reply: Reply

    public init(domain: String, route: Route, reply: Reply) {
        self.domain = domain
        self.route = route
        self.reply = reply
    }
}

public struct Notice: Equatable, Sendable {
    public var domain: String
    public var status: SiteStatus
}

/// Everything the app remembers. Never contains the private key.
/// Adding a field later: make it optional, or old state files fail to decode and get moved aside.
public struct AppState: Codable, Equatable, Sendable {
    public var tunnelName: String?
    public var endpoint: String?
    public var originalAllowedIPs: [IPNet] = []
    public var sites: [Site] = []
    public var awaitingUpdate = false
    public var confirmedOnce = false
    public var coffeeDismissed = false
    public var lastCheck: Date?
    /// Local networks stay out of the tunnel. Nil means yes (state files from before the toggle).
    public var bypassLocal: Bool?
    /// The tunnel's own Address subnets and DNS IPs from the config: never kept out of the tunnel.
    public var keepInTunnel: [IPNet]?
    /// What WireGuard has now: the imported AllowedIPs, or what the user last copied or saved.
    public var exportedAllowedIPs: [IPNet]?

    public init() {}

    public var hasConfig: Bool { endpoint != nil }
    public var bypassesLocal: Bool { bypassLocal ?? true }

    /// WireGuard's AllowedIPs differ from the ones the app would produce now.
    public var needsUpdate: Bool { exportedAllowedIPs.map { !sameCoverage(computedAllowedIPs, $0) } ?? false }

    public var pendingChanges: Int {
        let withNew = sites.filter(\.hasNewIPs).count
        return withNew > 0 ? withNew : (needsUpdate ? 1 : 0)
    }

    public var computedAllowedIPs: [IPNet] {
        computeAllowedIPs(original: originalAllowedIPs, excluding: sites.flatMap(\.seen),
                          bypassLocal: bypassesLocal, keepInTunnel: keepInTunnel ?? [])
    }

    /// The config's own exclusions that are not explained by local networks or by sites.
    public var configExclusions: [IPNet] {
        exclude(exclude(fullTunnel(for: originalAllowedIPs), originalAllowedIPs), localNetworks + sites.flatMap(\.seen))
    }

    /// Where a site IP would have to be cut out of the tunnel: routed today, and not the tunnel's own Address/DNS (those are never cut out).
    private var routedWithoutSites: [IPNet] {
        exclude(computeAllowedIPs(original: originalAllowedIPs, excluding: [], bypassLocal: bypassesLocal, keepInTunnel: keepInTunnel ?? []), keepInTunnel ?? [])
    }

    /// An address that is inside AllowedIPs in both the old and the new config,
    /// so its route tells whether the tunnel is up.
    public var tunnelProbeAddress: IPNet? {
        let nets = computedAllowedIPs
        for candidate in ["1.1.1.1", "8.8.8.8", "9.9.9.9"] {
            let ip = IPNet(candidate)!
            if nets.contains(where: { $0.contains(ip) }) { return ip }
        }
        guard let first = nets.first else { return nil }
        if first.prefix == first.bits { return first }
        return IPNet(isV6: first.isV6, address: first.address + 1, prefix: first.bits)
    }

    public mutating func load(config: WGConfig, fileName: String?) {
        tunnelName = makeTunnelName(fileName: fileName, endpoint: config.endpoint)
        endpoint = config.endpoint
        originalAllowedIPs = config.allowedIPs
        keepInTunnel = config.keepInTunnel
        exportedAllowedIPs = config.allowedIPs
        awaitingUpdate = false
        // IPs the loaded config already keeps out of the tunnel count as exported (e.g. after a reinstall).
        let routed = routedWithoutSites
        for i in sites.indices {
            sites[i].exported = sites[i].seen.filter { ip in
                !config.allowedIPs.contains { $0.contains(ip) } || !routed.contains { $0.contains(ip) }
            }
        }
    }

    /// IPs that fall outside the routed set under the new setting never need a WireGuard update.
    public mutating func setBypassLocal(_ on: Bool) {
        bypassLocal = on
        exportUnrouted()
    }

    /// What the generated AllowedIPs never route (local networks while bypassed, the config's holes, e.g. IPv6 on a
    /// v4-only tunnel) counts as outside the tunnel: such IPs never need a WireGuard update.
    private mutating func exportUnrouted() {
        let routed = routedWithoutSites
        for i in sites.indices {
            for ip in sites[i].seen where !sites[i].exported.contains(ip) && !routed.contains(where: { $0.contains(ip) }) {
                sites[i].exported.append(ip)
            }
        }
    }

    public mutating func addSite(_ domain: String) -> Bool {
        guard !sites.contains(where: { $0.domain == domain }) else { return false }
        sites.append(Site(domain: domain))
        return true
    }

    public mutating func removeSite(_ domain: String) {
        sites.removeAll { $0.domain == domain }
    }

    /// Check step 1: remember newly resolved IPs.
    public mutating func merge(resolved: [String: [IPNet]]) {
        for i in sites.indices {
            for ip in resolved[sites[i].domain] ?? [] where !sites[i].seen.contains(ip) { sites[i].seen.append(ip) }
        }
        exportUnrouted()
    }

    /// Check step 2: store statuses; returns what to notify about.
    /// Notifies once per problem (red, or new IPs), only while the tunnel is up.
    public mutating func apply(_ probes: [SiteProbe], tunnelUp: Bool, now: Date) -> [Notice] {
        var notices: [Notice] = []
        for probe in probes {
            guard let i = sites.firstIndex(where: { $0.domain == probe.domain }) else { continue }
            let new = SiteStatus(route: probe.route, reply: probe.reply, hasNewIPs: sites[i].hasNewIPs)
            let old = sites[i].status
            let isProblem = new.level == .bad || new.hasNewIPs
            // A status recorded while the tunnel was off was never notified about.
            let changed = old?.level != new.level || old?.hasNewIPs != new.hasNewIPs || old?.route == .tunnelOff
            // The first status of a new site is shown in the open window, not notified.
            if tunnelUp, old != nil, isProblem, changed { notices.append(Notice(domain: probe.domain, status: new)) }
            sites[i].status = new
        }
        // Sites that do not resolve say nothing about the route.
        let routed = sites.filter { $0.status?.reply != .notFound }
        if tunnelUp, !routed.isEmpty, routed.allSatisfy({ $0.status?.route == .direct }) {
            awaitingUpdate = false
            if routed.allSatisfy({ $0.status?.level == .good }) { confirmedOnce = true }
        }
        lastCheck = now
        return notices
    }

    /// Call after the user copied AllowedIPs or saved a .conf.
    public mutating func markExported() {
        for i in sites.indices { sites[i].exported = sites[i].seen }
        awaitingUpdate = !sites.isEmpty // with no sites nothing can confirm the update
        exportedAllowedIPs = computedAllowedIPs
    }

    /// `canSave` is false only when the file exists, is unusable and could not be moved aside:
    /// saving would then overwrite the user's data.
    public static func load(from url: URL) -> (state: AppState, canSave: Bool) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return (AppState(), true) }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let data = try? Data(contentsOf: url), let state = try? decoder.decode(AppState.self, from: data) { return (state, true) }
        // Unreadable file: move it aside instead of silently overwriting the user's data.
        // The name only has to be unique; which files to keep is decided by modification date below.
        let dir = url.deletingLastPathComponent()
        let name = "\(url.lastPathComponent).\(Int(Date().timeIntervalSince1970 * 1000)).\(UUID().uuidString).broken"
        let moved = dir.appending(path: name)
        do { try fm.moveItem(at: url, to: moved) } catch { return (AppState(), false) }
        // moveItem keeps the file's old modification date; refresh it so the file just moved is never the first one rotated out.
        try? fm.setAttributes([.modificationDate: Date.now], ofItemAtPath: moved.path)
        let prefix = url.lastPathComponent + "."
        let broken = ((try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey])) ?? [])
            .filter { $0.lastPathComponent.hasPrefix(prefix) && $0.lastPathComponent.hasSuffix(".broken") }
            .sorted { modified($0) > modified($1) }
        for old in broken.dropFirst(3) { try? fm.removeItem(at: old) }
        return (AppState(), true)
    }

    private static func modified(_ file: URL) -> Date {
        (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    public func save(to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(self).write(to: url, options: .atomic)
    }
}
