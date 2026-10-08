import Testing
@testable import SplitTunnelCore

@Test func levelFollowsSpecMatrix() {
    func level(_ r: Route, _ p: Reply, new: Bool = false) -> Level { SiteStatus(route: r, reply: p, hasNewIPs: new).level }
    #expect(level(.direct, .ok) == .good)
    #expect(level(.tunnel, .ok) == .warn)
    #expect(level(.tunnelOff, .ok) == .idle)
    #expect(level(.direct, .ok, new: true) == .warn)
    #expect(level(.tunnelOff, .ok, new: true) == .warn)
    for route in [Route.direct, .tunnel, .tunnelOff, .unknown] {
        for reply in [Reply.rateLimited, .forbidden, .captcha, .noResponse, .notFound] {
            #expect(level(route, reply) == .bad)
        }
    }
    #expect(Level.bad > Level.warn && Level.warn > Level.idle && Level.idle > Level.good)
}

@Test func classifiesHTTPReplies() {
    #expect(classify(status: 200, cfMitigated: nil) == .ok)
    #expect(classify(status: 301, cfMitigated: nil) == .ok)
    #expect(classify(status: 404, cfMitigated: nil) == .ok)
    #expect(classify(status: 429, cfMitigated: nil) == .rateLimited)
    #expect(classify(status: 403, cfMitigated: nil) == .forbidden)
    #expect(classify(status: 403, cfMitigated: "challenge") == .captcha)
    #expect(classify(status: 503, cfMitigated: nil) == .noResponse)
}

@Test func parsesRouteOutput() {
    let out = """
       route to: 104.20.39.144
    destination: default
           mask: default
        gateway: 192.168.50.1
      interface: en0
          flags: <UP,GATEWAY,DONE,STATIC,PRCLONING,GLOBAL>
    """
    #expect(parseRouteInterface(out) == "en0")
    #expect(parseRouteInterface("route: writing to routing socket: not in table") == nil)
    #expect(parseRouteInterface("  interface: \n") == nil)
}

@Test func aggregatesRoutes() {
    #expect(aggregateRoute(interfaces: ["en0", "en0"], tunnelUp: true) == .direct)
    #expect(aggregateRoute(interfaces: ["en0", "utun4"], tunnelUp: true) == .tunnel)
    #expect(aggregateRoute(interfaces: ["utun4"], tunnelUp: false) == .tunnelOff)
    #expect(aggregateRoute(interfaces: [], tunnelUp: true) == .unknown)
    #expect(aggregateRoute(interfaces: [nil], tunnelUp: true) == .unknown)
    #expect(aggregateRoute(interfaces: [nil, "utun4"], tunnelUp: true) == .tunnel)
    #expect(aggregateRoute(interfaces: [nil, "en0"], tunnelUp: true) == .unknown)
    #expect(aggregateRoute(interfaces: ["none", "en0"], tunnelUp: true) == .direct)
}
