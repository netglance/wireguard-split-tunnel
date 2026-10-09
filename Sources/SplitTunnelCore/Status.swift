import Foundation

public enum Route: String, Codable, Sendable { case direct, tunnel, tunnelOff, unknown }
public enum Reply: String, Codable, Sendable { case ok, rateLimited, forbidden, captcha, noResponse, notFound }

public enum Level: Comparable, Sendable { case good, idle, warn, bad }

public struct SiteStatus: Codable, Equatable, Sendable {
    public var route: Route
    public var reply: Reply
    public var hasNewIPs: Bool

    /// Route × reply: any failed reply is red; new IPs or tunnel routing is orange.
    public var level: Level {
        guard reply == .ok else { return .bad }
        if hasNewIPs || route == .tunnel { return .warn }
        return route == .direct ? .good : .idle
    }
}

public func classify(status: Int, cfMitigated: String?) -> Reply {
    if cfMitigated?.lowercased() == "challenge" { return .captcha }
    switch status {
    case 429: return .rateLimited
    case 403: return .forbidden
    case 500...: return .noResponse
    default: return .ok
    }
}

/// The `interface:` value from `route -n get` output.
public func parseRouteInterface(_ output: String) -> String? {
    output.firstMatch(of: #/interface: *(\S+)/#).map { String($0.1) }
}

/// A site goes through the tunnel if any of its IPs is routed via a utun interface;
/// if any lookup failed and none is via utun, the route is unknown.
public func aggregateRoute(interfaces: [String?], tunnelUp: Bool) -> Route {
    guard tunnelUp else { return .tunnelOff }
    guard !interfaces.isEmpty else { return .unknown }
    if interfaces.contains(where: { $0?.hasPrefix("utun") == true }) { return .tunnel }
    return interfaces.contains(nil) ? .unknown : .direct
}
