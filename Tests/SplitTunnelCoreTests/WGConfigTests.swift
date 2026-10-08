import Testing
@testable import SplitTunnelCore

private let sampleConfig = """
[Interface]
# Device: Mac
PrivateKey = aGVsbG8gd29ybGQgdGhpcyBpcyBub3QgYSByZWFsIGtleQ=
Address = 10.14.0.2/16
DNS = 162.252.172.57, 149.154.159.92

[Peer]
PublicKey = c3VyZnNoYXJrIHB1YmxpYyBrZXkgZXhhbXBsZSBvbmx5IQ=
AllowedIPs = 0.0.0.0/0
Endpoint = pl-waw.prod.surfshark.com:51820
"""

@Test func parsesSurfsharkConfig() throws {
    let config = try parseConfig(sampleConfig)
    let keep = ["10.14.0.0/16", "162.252.172.57/32", "149.154.159.92/32"].map { IPNet($0)! }
    #expect(config == WGConfig(allowedIPs: [IPNet("0.0.0.0/0")!], endpoint: "pl-waw.prod.surfshark.com:51820", keepInTunnel: keep))
}

@Test func keepInTunnelTakesOnlyInterfaceAddressAndIPDNS() throws {
    let text = "[Interface]\nAddress = 10.14.0.2/16, fd00::2/64, junk\nDNS = 10.64.0.1, example.lan, 10.1.0.0/24\n"
        + "[Peer]\nAddress = 9.9.9.9/32\nDNS = 9.9.9.9\nAllowedIPs = 0.0.0.0/0\nEndpoint = a:1\n"
    #expect(try parseConfig(text).keepInTunnel == ["10.14.0.0/16", "fd00::/64", "10.64.0.1/32"].map { IPNet($0)! })
}

@Test func parsesCRLFTabsLowercaseCommentsAndRepeatedKeys() throws {
    let text = "[interface]\r\nPrivateKey = x\r\n[peer]\r\nallowedips\t=\t0.0.0.0/0 # all v4\r\nAllowedIPs = ::/0\r\nendpoint = [2001:db8::1]:51820\r\n"
    let config = try parseConfig(text)
    #expect(config.allowedIPs == [IPNet("0.0.0.0/0")!, IPNet("::/0")!])
    #expect(config.endpoint == "[2001:db8::1]:51820")
}

@Test func reportsWhatIsMissing() {
    #expect(throws: ConfigError.noPeer) { try parseConfig("[Interface]\nPrivateKey = x\n") }
    #expect(throws: ConfigError.multiplePeers) { try parseConfig(sampleConfig + "\n[Peer]\nAllowedIPs = 1.0.0.0/8\nEndpoint = a:1\n") }
    #expect(throws: ConfigError.noAllowedIPs) { try parseConfig("[Peer]\nEndpoint = a:1\n") }
    #expect(throws: ConfigError.noEndpoint) { try parseConfig("[Peer]\nAllowedIPs = 0.0.0.0/0\n") }
    #expect(throws: ConfigError.badAddress("0.0.0.0/99")) { try parseConfig("[Peer]\nAllowedIPs = 0.0.0.0/99\nEndpoint = a:1\n") }
}

@Test func replacementKeepsEveryOtherLineByteForByte() {
    let nets = [IPNet("0.0.0.0/5")!, IPNet("8.0.0.0/7")!]
    let result = replacingAllowedIPs(in: sampleConfig, with: nets)
    let before = sampleConfig.split(separator: "\n", omittingEmptySubsequences: false)
    let after = result.split(separator: "\n", omittingEmptySubsequences: false)
    #expect(after.count == before.count)
    for (b, a) in zip(before, after) where !b.hasPrefix("AllowedIPs") { #expect(a == b) }
    #expect(after.contains("AllowedIPs = 0.0.0.0/5, 8.0.0.0/7"))
}

@Test func replacementMergesRepeatedKeysAndKeepsCRLF() {
    let text = "[Peer]\r\nAllowedIPs = 0.0.0.0/0\r\nAllowedIPs = ::/0\r\nEndpoint = a:1\r\n"
    #expect(replacingAllowedIPs(in: text, with: [IPNet("1.0.0.0/8")!]) == "[Peer]\r\nAllowedIPs = 1.0.0.0/8\r\nEndpoint = a:1\r\n")
}

@Test func tunnelNameFromFileOrEndpoint() {
    #expect(makeTunnelName(fileName: "surfshark-pl-waw.conf", endpoint: "x:1") == "surfshark-pl-waw")
    #expect(makeTunnelName(fileName: nil, endpoint: "pl-waw.prod.surfshark.com:51820") == "pl-waw.prod.surfshark.com")
    #expect(makeTunnelName(fileName: nil, endpoint: "[2001:db8::1]:51820") == "2001:db8::1")
}

@Test func sectionMustBeExactlyPeer() {
    #expect(throws: ConfigError.noPeer) { try parseConfig("[PeerX]\nAllowedIPs = 0.0.0.0/0\nEndpoint = a:1\n") }
    #expect(throws: ConfigError.noPeer) { try parseConfig("[Peer]x\nAllowedIPs = 0.0.0.0/0\nEndpoint = a:1\n") }
    let text = "[Peer] # main\nAllowedIPs = 0.0.0.0/0\nEndpoint = a:1\n"
    #expect((try? parseConfig(text))?.endpoint == "a:1")
    let other = "[PeerX]\nAllowedIPs = 0.0.0.0/0\n"
    #expect(replacingAllowedIPs(in: other, with: [IPNet("1.0.0.0/8")!]) == other)
}

@Test func commentedAndInterfaceAllowedIPsAreIgnored() throws {
    let text = "[Interface]\nAllowedIPs = 9.0.0.0/8\n[Peer]\n# AllowedIPs = 1.0.0.0/8\nAllowedIPs = 0.0.0.0/0\nEndpoint = a:1\n"
    #expect(try parseConfig(text).allowedIPs == [IPNet("0.0.0.0/0")!])
    let result = replacingAllowedIPs(in: text, with: [IPNet("2.0.0.0/8")!])
    #expect(result == "[Interface]\nAllowedIPs = 9.0.0.0/8\n[Peer]\n# AllowedIPs = 1.0.0.0/8\nAllowedIPs = 2.0.0.0/8\nEndpoint = a:1\n")
}

@Test func tunnelNameUsesLastPathComponentAndToleratesGarbage() {
    #expect(makeTunnelName(fileName: "/Users/me/vpn/pl.conf", endpoint: "x:1") == "pl")
    #expect(makeTunnelName(fileName: nil, endpoint: "[") == "[")
}
