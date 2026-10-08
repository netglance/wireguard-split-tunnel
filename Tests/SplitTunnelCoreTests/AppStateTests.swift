import Foundation
import Testing
@testable import SplitTunnelCore

private func ip(_ s: String) -> IPNet { IPNet(s)! }

private func stateWith4pda() -> AppState {
    var s = AppState()
    s.load(config: WGConfig(allowedIPs: [ip("0.0.0.0/0")], endpoint: "vpn.example.com:51820"), fileName: "pl.conf")
    _ = s.addSite("4pda.to")
    return s
}

@Test func addSiteRejectsDuplicates() {
    var s = stateWith4pda()
    let dupe = s.addSite("4pda.to"); #expect(!dupe)
    let added = s.addSite("gosuslugi.ru"); #expect(added)
    s.removeSite("4pda.to")
    #expect(s.sites.map(\.domain) == ["gosuslugi.ru"])
}

@Test func mergeAccumulatesSeenWithoutDuplicates() {
    var s = stateWith4pda()
    s.merge(resolved: ["4pda.to": [ip("104.20.39.144"), ip("172.66.159.63")]])
    s.merge(resolved: ["4pda.to": [ip("172.66.159.63"), ip("172.67.12.80")]])
    s.merge(resolved: ["4pda.to": []])
    #expect(s.sites[0].seen == [ip("104.20.39.144"), ip("172.66.159.63"), ip("172.67.12.80")])
    #expect(s.sites[0].hasNewIPs)
    #expect(s.pendingChanges == 1)
}

@Test func markExportedClearsNewIPsAndWaitsForTunnel() {
    var s = stateWith4pda()
    s.merge(resolved: ["4pda.to": [ip("104.20.39.144")]])
    s.markExported()
    #expect(!s.sites[0].hasNewIPs)
    #expect(s.awaitingUpdate)
    #expect(!s.computedAllowedIPs.contains { $0.contains(ip("104.20.39.144")) })
}

@Test func loadingAlreadySplitConfigMarksExcludedIPsExported() {
    var s = stateWith4pda()
    s.merge(resolved: ["4pda.to": [ip("104.20.39.144")]])
    let generated = s.computedAllowedIPs
    s.load(config: WGConfig(allowedIPs: generated, endpoint: "vpn.example.com:51820"), fileName: "pl.conf")
    #expect(!s.sites[0].hasNewIPs)
    #expect(!s.needsUpdate)
    s.load(config: WGConfig(allowedIPs: [ip("0.0.0.0/0")], endpoint: "vpn.example.com:51820"), fileName: "pl.conf")
    #expect(s.sites[0].hasNewIPs)
}

@Test func applyClearsAwaitingOnlyWhenAllSitesGoDirect() {
    var s = stateWith4pda()
    s.merge(resolved: ["4pda.to": [ip("104.20.39.144")]])
    s.markExported()
    _ = s.apply([SiteProbe(domain: "4pda.to", route: .tunnel, reply: .ok)], tunnelUp: true, now: .now)
    #expect(s.awaitingUpdate)
    _ = s.apply([SiteProbe(domain: "4pda.to", route: .direct, reply: .ok)], tunnelUp: true, now: .now)
    #expect(!s.awaitingUpdate)
    #expect(s.confirmedOnce)
}

@Test func notifiesOncePerProblemAndAgainAfterRecovery() {
    var s = stateWith4pda()
    s.merge(resolved: ["4pda.to": [ip("104.20.39.144")]])
    s.markExported()
    let bad = [SiteProbe(domain: "4pda.to", route: .tunnel, reply: .captcha)]
    let good = [SiteProbe(domain: "4pda.to", route: .direct, reply: .ok)]
    #expect(s.apply(good, tunnelUp: true, now: .now).isEmpty) // seed: the first status of a site never notifies
    #expect(s.apply(bad, tunnelUp: true, now: .now).map(\.domain) == ["4pda.to"])
    #expect(s.apply(bad, tunnelUp: true, now: .now).isEmpty)
    #expect(s.apply(good, tunnelUp: true, now: .now).isEmpty)
    #expect(s.apply(bad, tunnelUp: true, now: .now).count == 1)
}

@Test func doesNotNotifyOnFirstStatusOfANewSite() {
    var s = stateWith4pda()
    let bad = [SiteProbe(domain: "4pda.to", route: .tunnel, reply: .captcha)]
    #expect(s.apply(bad, tunnelUp: true, now: .now).isEmpty)
    #expect(s.sites[0].status?.level == .bad)
}

@Test func ipsOutsideOriginalAllowedIPsAreNeverNew() {
    var s = stateWith4pda()
    s.load(config: WGConfig(allowedIPs: [ip("0.0.0.0/0")], endpoint: "a:1"), fileName: nil)
    s.merge(resolved: ["4pda.to": [ip("2606:4700::1"), ip("192.168.1.10")]])
    #expect(!s.sites[0].hasNewIPs)
    s.load(config: WGConfig(allowedIPs: [ip("0.0.0.0/0")], endpoint: "a:1"), fileName: nil) // reloading keeps it that way
    #expect(!s.sites[0].hasNewIPs)
    s.merge(resolved: ["4pda.to": [ip("104.20.39.144")]])
    #expect(s.sites[0].hasNewIPs)
    #expect(s.sites[0].newIPs == [ip("104.20.39.144")])
}

@Test func awaitingUpdateIgnoresSitesThatDoNotResolve() {
    var s = stateWith4pda()
    _ = s.addSite("typo.example")
    s.markExported()
    let probes = [SiteProbe(domain: "4pda.to", route: .direct, reply: .ok),
                  SiteProbe(domain: "typo.example", route: .unknown, reply: .notFound)]
    _ = s.apply(probes, tunnelUp: true, now: .now)
    #expect(!s.awaitingUpdate)
    #expect(s.confirmedOnce)
    var only = stateWith4pda()
    only.markExported()
    _ = only.apply([SiteProbe(domain: "4pda.to", route: .unknown, reply: .notFound)], tunnelUp: true, now: .now)
    #expect(only.awaitingUpdate)
    #expect(!only.confirmedOnce)
}

@Test func notifiesAboutNewIPButNotWhileTunnelIsOff() {
    var s = stateWith4pda()
    s.merge(resolved: ["4pda.to": [ip("104.20.39.144")]])
    let probe = [SiteProbe(domain: "4pda.to", route: .tunnelOff, reply: .ok)]
    #expect(s.apply(probe, tunnelUp: false, now: .now).isEmpty)
    let up = [SiteProbe(domain: "4pda.to", route: .tunnel, reply: .ok)]
    let notices = s.apply(up, tunnelUp: true, now: .now)
    #expect(notices.count == 1 && notices[0].status.hasNewIPs)
}

@Test func applyIgnoresSitesRemovedDuringCheck() {
    var s = stateWith4pda()
    #expect(s.apply([SiteProbe(domain: "gone.example", route: .direct, reply: .ok)], tunnelUp: true, now: .now).isEmpty)
}

@Test func tunnelProbePrefersWellKnownPublicAddress() {
    var s = stateWith4pda()
    #expect(s.tunnelProbeAddress == ip("1.1.1.1"))
    s.merge(resolved: ["4pda.to": [ip("1.1.1.1")]])
    #expect(s.tunnelProbeAddress == ip("8.8.8.8"))
    var narrow = AppState()
    narrow.load(config: WGConfig(allowedIPs: [ip("100.64.0.0/10")], endpoint: "a:1"), fileName: nil)
    #expect(narrow.tunnelProbeAddress == ip("100.64.0.1"))
}

private func tempDir() -> URL { FileManager.default.temporaryDirectory.appending(path: UUID().uuidString) }
private func brokenCount(in dir: URL) -> Int {
    ((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []).filter { $0.hasSuffix(".broken") }.count
}

@Test func savesAndLoadsAndKeepsBrokenFile() throws {
    let dir = tempDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    let url = dir.appending(path: "state.json")
    var s = stateWith4pda()
    s.lastCheck = Date(timeIntervalSince1970: 1_800_000_000)
    try s.save(to: url)
    let loaded = AppState.load(from: url)
    #expect(loaded.state == s && loaded.canSave)
    try Data("{broken".utf8).write(to: url)
    let fresh = AppState.load(from: url)
    #expect(fresh.state == AppState() && fresh.canSave)
    #expect(brokenCount(in: dir) == 1)
    #expect(!FileManager.default.fileExists(atPath: url.path))
    let missing = AppState.load(from: dir.appending(path: "missing.json"))
    #expect(missing.state == AppState() && missing.canSave)
}

@Test func keepsOnlyThreeNewestBrokenFiles() throws {
    let dir = tempDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    let url = dir.appending(path: "state.json")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    for i in 1...5 {
        try Data("{broken \(i)".utf8).write(to: url)
        #expect(AppState.load(from: url).canSave)
    }
    #expect(brokenCount(in: dir) == 3)
}

@Test func oldFormatBrokenFilesDoNotPushOutTheNewlyMovedFile() throws {
    let dir = tempDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    // Old-format names with uppercase UUIDs: sorted by name they would sort after the new timestamp-named file.
    var seeded: Set<String> = []
    for i in 0..<3 {
        let name = "state.json.FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFF\(i).broken"
        seeded.insert(name)
        let file = dir.appending(path: name)
        try Data("{old \(i)".utf8).write(to: file)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1_000_000)], ofItemAtPath: file.path)
    }
    let url = dir.appending(path: "state.json")
    try Data("{broken".utf8).write(to: url)
    try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1_000_000)], ofItemAtPath: url.path)
    #expect(AppState.load(from: url).canSave)
    let remaining = Set(try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.hasSuffix(".broken") })
    #expect(remaining.count == 3)
    #expect(!remaining.isSubset(of: seeded)) // the file just moved aside is among the kept ones
}

@Test func cannotSaveWhenBrokenFileCannotBeMovedAside() throws {
    let dir = tempDir()
    let url = dir.appending(path: "state.json")
    defer {
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
        try? FileManager.default.removeItem(at: dir)
    }
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try Data("{broken".utf8).write(to: url)
    try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: dir.path) // no rename inside
    let loaded = AppState.load(from: url)
    #expect(loaded.state == AppState() && !loaded.canSave)
}

@Test func importedFullTunnelNeedsUpdateUntilExported() {
    var s = AppState()
    s.load(config: WGConfig(allowedIPs: [ip("0.0.0.0/0")], endpoint: "a:1"), fileName: nil)
    #expect(s.needsUpdate) // local networks are not yet excluded in WireGuard
    #expect(s.pendingChanges == 1)
    s.markExported()
    #expect(!s.needsUpdate && s.pendingChanges == 0)
    #expect(!s.awaitingUpdate) // no sites: nothing could ever confirm the update
    s.bypassLocal = false
    #expect(s.needsUpdate)
    s.bypassLocal = true
    #expect(!s.needsUpdate)
}

@Test func removingAnExportedSiteNeedsUpdate() {
    var s = stateWith4pda()
    s.merge(resolved: ["4pda.to": [ip("104.20.39.144")]])
    s.markExported()
    #expect(!s.needsUpdate)
    s.removeSite("4pda.to")
    #expect(s.needsUpdate && s.pendingChanges == 1)
    s.markExported()
    #expect(!s.needsUpdate)
}

@Test func removingASiteNeverExportedDoesNotAsk() {
    var s = stateWith4pda()
    s.markExported()
    s.removeSite("4pda.to")
    #expect(!s.needsUpdate && s.pendingChanges == 0)
    var t = stateWith4pda()
    t.markExported()
    t.merge(resolved: ["4pda.to": [ip("104.20.39.144")]]) // new IPs, not exported yet
    t.removeSite("4pda.to")
    #expect(!t.needsUpdate && t.pendingChanges == 0)
}

@Test func loadingKeepsTheTunnelsOwnAddressAndDNSRouted() {
    var s = AppState()
    s.load(config: WGConfig(allowedIPs: [ip("0.0.0.0/0")], endpoint: "a:1", keepInTunnel: [ip("10.14.0.0/16"), ip("162.252.172.57")]), fileName: nil)
    #expect(s.computedAllowedIPs.contains { $0.contains(ip("10.14.0.5")) })
    #expect(!s.computedAllowedIPs.contains { $0.contains(ip("10.20.0.1")) })
    _ = s.addSite("a.example")
    s.merge(resolved: ["a.example": [ip("10.14.0.9")]]) // inside the tunnel's own subnet: never cut out, so never new
    #expect(!s.sites[0].hasNewIPs)
}

@Test func toggleOffMakesLocalIPsRoutedSoTheyCountAsNew() {
    var s = stateWith4pda()
    s.bypassLocal = false
    s.merge(resolved: ["4pda.to": [ip("192.168.1.10")]])
    #expect(s.sites[0].hasNewIPs)
}

@Test func configExclusionsShowManualHolesOnly() {
    var s = AppState()
    let own = exclude([ip("0.0.0.0/0")], [ip("203.0.113.0/24")])
    s.load(config: WGConfig(allowedIPs: own, endpoint: "a:1"), fileName: nil)
    #expect(s.configExclusions == [ip("203.0.113.0/24")])
    var plain = stateWith4pda()
    plain.merge(resolved: ["4pda.to": [ip("104.20.39.144")]])
    #expect(plain.configExclusions.isEmpty)
    s.load(config: WGConfig(allowedIPs: exclude([ip("0.0.0.0/0")], localNetworks + [ip("104.20.39.144")]), endpoint: "a:1"), fileName: nil)
    _ = s.addSite("4pda.to")
    s.merge(resolved: ["4pda.to": [ip("104.20.39.144")]])
    #expect(s.configExclusions.isEmpty) // local networks and site IPs are not "manual"
}

@Test func oldStateFileWithoutTheToggleFieldsStillDecodes() throws {
    var s = stateWith4pda()
    s.bypassLocal = false
    s.keepInTunnel = [ip("10.14.0.0/16")]
    var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(s)) as? [String: Any])
    for key in ["bypassLocal", "keepInTunnel", "exportedAllowedIPs"] { json[key] = nil }
    json["removedSinceExport"] = true // a real file from the previous version has it; it is ignored now
    let old = try JSONDecoder().decode(AppState.self, from: JSONSerialization.data(withJSONObject: json))
    #expect(old.bypassesLocal && old.keepInTunnel == nil && !old.needsUpdate)
}

@Test func reloadingAGeneratedConfigNeverMakesSiteIPsNew() {
    for (bypass, siteIP) in [(true, "10.14.0.9"), (false, "192.168.1.10")] {
        var s = AppState()
        let keep = [ip("10.14.0.0/16")]
        s.load(config: WGConfig(allowedIPs: [ip("0.0.0.0/0")], endpoint: "a:1", keepInTunnel: keep), fileName: nil)
        s.bypassLocal = bypass
        _ = s.addSite("a.example")
        s.merge(resolved: ["a.example": [ip(siteIP)]])
        s.load(config: WGConfig(allowedIPs: s.computedAllowedIPs, endpoint: "a:1", keepInTunnel: keep), fileName: nil)
        #expect(!s.sites[0].hasNewIPs && !s.needsUpdate)
    }
}

@Test func flippingTheToggleBackDoesNotLeaveLocalIPsNew() {
    var s = stateWith4pda()
    s.setBypassLocal(false)
    s.merge(resolved: ["4pda.to": [ip("192.168.1.10")]])
    #expect(s.sites[0].hasNewIPs)
    s.setBypassLocal(true)
    #expect(!s.sites[0].hasNewIPs)
}
