/// Networks that must never go into the tunnel (LAN, link-local, multicast).
public let localNetworks: [IPNet] = [
    "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "169.254.0.0/16", "224.0.0.0/4",
    "fc00::/7", "fe80::/10", "ff00::/8",
].map { IPNet($0)! }

/// `base` minus every network in `excluded`, as a sorted list of CIDRs (same as Python's address_exclude).
public func exclude(_ base: [IPNet], _ excluded: [IPNet]) -> [IPNet] {
    var nets = base
    for e in excluded { nets = nets.flatMap { subtract($0, e) } }
    return nets.sorted()
}

private func subtract(_ net: IPNet, _ e: IPNet) -> [IPNet] {
    if e.contains(net) { return [] }
    guard net.contains(e) else { return [net] }
    let (low, high) = net.halves()
    return subtract(low, e) + subtract(high, e)
}

/// What a full tunnel for this config would route: 0.0.0.0/0 and/or ::/0, by the families the config uses.
func fullTunnel(for nets: [IPNet]) -> [IPNet] {
    (nets.contains { !$0.isV6 } ? [IPNet("0.0.0.0/0")!] : []) + (nets.contains(where: \.isV6) ? [IPNet("::/0")!] : [])
}

/// The AllowedIPs to put into the config. The config's own exclusions are always preserved; local networks are
/// kept out only when `bypassLocal`; the tunnel's Address subnets and DNS servers (`keepInTunnel`) are never kept
/// out by those two rules; site IPs are kept out too, except inside `keepInTunnel`: they come from DNS, which must
/// never be able to pull the tunnel's own DNS out of the VPN.
public func computeAllowedIPs(original: [IPNet], excluding sites: [IPNet],
                              bypassLocal: Bool = true, keepInTunnel: [IPNet] = []) -> [IPNet] {
    let full = fullTunnel(for: original)
    var holes = exclude(full, original)
    holes = bypassLocal ? holes + localNetworks : exclude(holes, localNetworks)
    return exclude(full, exclude(holes + sites, keepInTunnel))
}

/// True when both lists cover exactly the same addresses, however they are split into CIDRs.
public func sameCoverage(_ a: [IPNet], _ b: [IPNet]) -> Bool {
    let all = [IPNet("0.0.0.0/0")!, IPNet("::/0")!]
    return exclude(all, a) == exclude(all, b)
}
