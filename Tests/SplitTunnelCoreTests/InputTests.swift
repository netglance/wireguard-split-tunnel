import Testing
@testable import SplitTunnelCore

@Test(arguments: [
    ("4pda.to", "4pda.to"),
    ("  4PDA.to  ", "4pda.to"),
    ("https://4pda.to/forum/index.php?showtopic=1", "4pda.to"),
    ("http://user@4pda.to:8080/x", "4pda.to"),
    ("www.4pda.to", "www.4pda.to"),
    ("4pda.to.", "4pda.to"),
    ("https://президент.рф/путь", "президент.рф"),
    ("https://x.com/a%20b?q=%D1%84", "x.com"),
])
func normalizesSiteInput(input: String, expected: String) {
    #expect(normalizeDomain(input) == expected)
}

@Test(arguments: ["", "   ", "localhost", "1.2.3.4", "https://1.2.3.4/", "two words.com", ".com", "https://", "a..b", "x..", ".a", "a.b..", "a%2fb.com", "a%00b.com"])
func rejectsNonDomains(input: String) {
    #expect(normalizeDomain(input) == nil)
}

@Test func addsWwwVariant() {
    #expect(lookupHosts(for: "4pda.to") == ["4pda.to", "www.4pda.to"])
    #expect(lookupHosts(for: "www.4pda.to") == ["www.4pda.to"])
}

@Test func comparesVersions() {
    #expect(isNewer("v1.2.0", than: "1.1.9"))
    #expect(isNewer("1.10", than: "1.9"))
    #expect(!isNewer("1.2", than: "1.2.0"))
    #expect(!isNewer("1.0.0", than: "1.0.1"))
}

@Test func comparesPreReleaseVersions() {
    #expect(isNewer("1.3.0", than: "1.3.0-beta"))
    #expect(!isNewer("1.3.0-beta", than: "1.3.0"))
    #expect(!isNewer("1.3.0-beta.2", than: "1.3.0-beta.1"))
    #expect(isNewer("1.3.0-beta.1", than: "1.2.0"))
    #expect(isNewer("1.3-beta", than: "1.2.0"))
    #expect(!isNewer("1.2.0-rc.1", than: "1.2.0"))
}
