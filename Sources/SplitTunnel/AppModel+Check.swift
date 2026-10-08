import Foundation
import SplitTunnelCore

extension AppModel {
    func loop() async {
        while !Task.isCancelled {
            await checkNow()
            if lastUpdateCheck.map({ Date.now.timeIntervalSince($0) > 24 * 3600 }) ?? true {
                if let release = await latestRelease() {
                    lastUpdateCheck = .now
                    if isNewer(release.tag_name, than: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0") {
                        availableUpdate = release
                    }
                }
            }
            try? await Task.sleep(for: .seconds(30 * 60))
        }
    }

    func checkNow() async {
        guard state.hasConfig else { return }
        guard !checking else { recheckRequested = true; return }
        checking = true
        defer { checking = false }
        repeat {
            recheckRequested = false
            await runCheck()
        } while recheckRequested
    }

    private func runCheck() async {
        // A mistyped site must not look like a dead network, so ask about a host that always exists.
        networkDown = await resolve("apple.com").isEmpty
        guard !networkDown else { return }

        var resolved: [String: [IPNet]] = [:]
        for site in state.sites {
            var ips: [IPNet] = []
            for host in lookupHosts(for: site.domain) { ips += await resolve(host) }
            resolved[site.domain] = Array(Set(ips)).sorted()
        }
        state.merge(resolved: resolved)

        var up = false
        if let probe = state.tunnelProbeAddress { up = await routeInterface(probe)?.hasPrefix("utun") == true }

        // ponytail: sites are probed one by one (10 s timeout each); use a task group if lists grow past ~20.
        // Before parallelising, move the blocking Task.detached calls (getaddrinfo, route) off the cooperative
        // pool onto a DispatchQueue: a handful of stuck lookups would otherwise exhaust its threads.
        var probes: [SiteProbe] = []
        for site in state.sites {
            guard let ips = resolved[site.domain] else { continue }
            guard !ips.isEmpty else {
                probes.append(SiteProbe(domain: site.domain, route: .unknown, reply: .notFound))
                continue
            }
            var interfaces: [String?] = []
            if up { for ip in ips { interfaces.append(await routeInterface(ip)) } }
            let route = aggregateRoute(interfaces: interfaces, tunnelUp: up)
            probes.append(SiteProbe(domain: site.domain, route: route, reply: await probeHTTP(site.domain)))
        }
        let notices = state.apply(probes, tunnelUp: up, now: .now)
        tunnelUp = up // together with the statuses, so the panel never shows them out of step
        for notice in notices {
            notifier.post(id: notice.domain, body: noticeText(notice))
        }
    }
}
