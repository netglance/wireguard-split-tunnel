import Foundation
import Testing
@testable import SplitTunnelCore

private let expected4pdaV4 = "0.0.0.0/5, 8.0.0.0/7, 11.0.0.0/8, 12.0.0.0/6, 16.0.0.0/4, 32.0.0.0/3, 64.0.0.0/3, 96.0.0.0/5, 104.0.0.0/12, 104.16.0.0/14, 104.20.0.0/19, 104.20.32.0/22, 104.20.36.0/23, 104.20.38.0/24, 104.20.39.0/25, 104.20.39.128/28, 104.20.39.145/32, 104.20.39.146/31, 104.20.39.148/30, 104.20.39.152/29, 104.20.39.160/27, 104.20.39.192/26, 104.20.40.0/21, 104.20.48.0/20, 104.20.64.0/18, 104.20.128.0/17, 104.21.0.0/16, 104.22.0.0/15, 104.24.0.0/13, 104.32.0.0/11, 104.64.0.0/10, 104.128.0.0/9, 105.0.0.0/8, 106.0.0.0/7, 108.0.0.0/6, 112.0.0.0/4, 128.0.0.0/3, 160.0.0.0/5, 168.0.0.0/8, 169.0.0.0/9, 169.128.0.0/10, 169.192.0.0/11, 169.224.0.0/12, 169.240.0.0/13, 169.248.0.0/14, 169.252.0.0/15, 169.255.0.0/16, 170.0.0.0/7, 172.0.0.0/12, 172.32.0.0/11, 172.64.0.0/15, 172.66.0.0/17, 172.66.128.0/20, 172.66.144.0/21, 172.66.152.0/22, 172.66.156.0/23, 172.66.158.0/24, 172.66.159.0/27, 172.66.159.32/28, 172.66.159.48/29, 172.66.159.56/30, 172.66.159.60/31, 172.66.159.62/32, 172.66.159.64/26, 172.66.159.128/25, 172.66.160.0/19, 172.66.192.0/18, 172.67.0.0/16, 172.68.0.0/14, 172.72.0.0/13, 172.80.0.0/12, 172.96.0.0/11, 172.128.0.0/9, 173.0.0.0/8, 174.0.0.0/7, 176.0.0.0/4, 192.0.0.0/9, 192.128.0.0/11, 192.160.0.0/13, 192.169.0.0/16, 192.170.0.0/15, 192.172.0.0/14, 192.176.0.0/12, 192.192.0.0/10, 193.0.0.0/8, 194.0.0.0/7, 196.0.0.0/6, 200.0.0.0/5, 208.0.0.0/4, 240.0.0.0/4"

private func nets(_ s: String...) -> [IPNet] { s.map { IPNet($0)! } }

@Test func parsesAndMasksCIDR() {
    #expect(IPNet("10.0.0.1/24")?.description == "10.0.0.0/24")
    #expect(IPNet(" 1.2.3.4 ")?.description == "1.2.3.4/32")
    #expect(IPNet("2606:4700:10::6814:2790")?.description == "2606:4700:10::6814:2790/128")
    #expect(IPNet("::/0")?.description == "::/0")
    #expect(IPNet("1.2.3.4")?.addressString == "1.2.3.4")
    #expect(IPNet("1.2.3.4/33") == nil)
    #expect(IPNet("1.2.3.4/x") == nil)
    #expect(IPNet("1.2.3.4/+24") == nil)
    #expect(IPNet("0.0.0.0/-0") == nil)
    #expect(IPNet("1.2.3.4/") == nil)
    #expect(IPNet("example.com") == nil)
    #expect(IPNet("") == nil)
}

@Test func containsRespectsFamilyAndPrefix() {
    #expect(IPNet("10.0.0.0/8")!.contains(IPNet("10.1.2.3")!))
    #expect(!IPNet("10.0.0.0/8")!.contains(IPNet("11.0.0.1")!))
    #expect(!IPNet("10.1.0.0/16")!.contains(IPNet("10.0.0.0/8")!))
    #expect(!IPNet("0.0.0.0/0")!.contains(IPNet("::1")!))
}

@Test func codableRoundTrip() throws {
    let data = try JSONEncoder().encode(nets("1.2.3.0/24", "fe80::/10"))
    #expect(String(decoding: data, as: UTF8.self) == #"["1.2.3.0\/24","fe80::\/10"]"#)
    #expect(try JSONDecoder().decode([IPNet].self, from: data) == nets("1.2.3.0/24", "fe80::/10"))
}

@Test func excludes4pdaIPv4LikePythonReference() {
    let result = computeAllowedIPs(original: nets("0.0.0.0/0"), excluding: nets("104.20.39.144", "172.66.159.63"))
    #expect(result.count == 90)
    #expect(result.map(\.description).joined(separator: ", ") == expected4pdaV4)
}

@Test func excludes4pdaIPv6LikePythonReference() {
    let site = nets("2606:4700:10::6814:2790", "2606:4700:10::ac42:9f3f")
    let result = computeAllowedIPs(original: nets("::/0"), excluding: site)
    #expect(result.count == 164)
    #expect(result.first?.description == "::/3")
    #expect(result.last?.description == "fec0::/10")
    #expect(result.map(\.description).contains("2606:4700:10::6814:2791/128"))
    #expect(!result.contains { $0.contains(site[0]) || $0.contains(site[1]) })
}

@Test func v4OnlyConfigStaysV4() {
    let result = computeAllowedIPs(original: nets("0.0.0.0/0"), excluding: nets("2606:4700:10::6814:2790", "104.20.39.144"))
    #expect(result.allSatisfy { !$0.isV6 })
}

@Test func excludingNothingKeepsOriginalMinusLocalNets() {
    let result = computeAllowedIPs(original: nets("8.8.8.0/24"), excluding: [])
    #expect(result == nets("8.8.8.0/24"))
}

@Test func fullIPv6ConfigNeverOverlapsLocalNetworks() {
    let result = computeAllowedIPs(original: nets("::/0"), excluding: [])
    for local in nets("fc00::/7", "fe80::/10", "ff00::/8") {
        #expect(!result.contains { $0.contains(local) || local.contains($0) })
    }
}

@Test func toggleOffPutsLocalNetworksBackInTheTunnel() {
    let site = nets("104.20.39.144")
    let result = computeAllowedIPs(original: nets("0.0.0.0/0"), excluding: site, bypassLocal: false)
    #expect(result.contains { $0.contains(ip("192.168.1.1")) })
    #expect(!result.contains { $0.contains(site[0]) })
    // Even when the imported config had excluded them.
    let split = computeAllowedIPs(original: nets("0.0.0.0/0"), excluding: [])
    #expect(computeAllowedIPs(original: split, excluding: [], bypassLocal: false).contains { $0.contains(ip("192.168.1.1")) })
}

@Test func configsOwnExclusionsSurviveInBothToggleStates() {
    let original = exclude(nets("0.0.0.0/0"), nets("203.0.113.0/24"))
    for bypass in [true, false] {
        let result = computeAllowedIPs(original: original, excluding: [], bypassLocal: bypass)
        #expect(!result.contains { $0.contains(ip("203.0.113.7")) })
        #expect(result.contains { $0.contains(ip("8.8.8.8")) })
    }
}

@Test func keepInTunnelWinsOverSiteIPs() {
    let keep = nets("10.14.0.0/16", "162.252.172.57/32")
    let result = computeAllowedIPs(original: nets("0.0.0.0/0"), excluding: [], keepInTunnel: keep)
    #expect(result.contains { $0.contains(ip("10.14.0.5")) })
    #expect(result.contains { $0.contains(ip("162.252.172.57")) })
    #expect(!result.contains { $0.contains(ip("10.20.0.1")) })
    let withSite = computeAllowedIPs(original: nets("0.0.0.0/0"), excluding: nets("10.14.0.5", "162.252.172.57", "104.20.39.144"), keepInTunnel: keep)
    #expect(withSite.contains { $0.contains(ip("10.14.0.5")) })
    #expect(withSite.contains { $0.contains(ip("162.252.172.57")) })
    #expect(!withSite.contains { $0.contains(ip("104.20.39.144")) })
}

@Test func sameCoverageIgnoresHowTheSetIsSplit() {
    #expect(sameCoverage(nets("0.0.0.0/1", "128.0.0.0/1"), nets("0.0.0.0/0")))
    #expect(!sameCoverage(nets("0.0.0.0/1"), nets("0.0.0.0/0")))
}

private func ip(_ s: String) -> IPNet { IPNet(s)! }
