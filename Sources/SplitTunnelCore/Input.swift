import Foundation

/// Turns whatever the user pasted (domain or full URL) into a lowercase host name.
/// Unicode domains stay readable (`президент.рф`); getaddrinfo and URL handle IDN themselves.
public func normalizeDomain(_ input: String) -> String? {
    let t = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard var s = URLComponents(string: t.contains("://") ? t : "https://" + t)?.host else { return nil }
    if s.hasSuffix(".") { s.removeLast() }
    let labels = s.split(separator: ".", omittingEmptySubsequences: false)
    guard labels.count > 1, !labels.contains(where: \.isEmpty), s.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "." }), IPNet(s) == nil else { return nil }
    return s
}

/// Hosts to resolve for a site: the domain itself plus its www variant.
public func lookupHosts(for domain: String) -> [String] {
    domain.hasPrefix("www.") ? [domain] : [domain, "www." + domain]
}

/// Compares dotted versions, ignoring a leading "v". A "-suffix" (pre-release) makes a version older than the same
/// numbers without it; two suffixed versions with equal numbers are not ordered (ponytail: no semver suffix precedence).
public func isNewer(_ remote: String, than local: String) -> Bool {
    func parse(_ v: String) -> (nums: [Int], pre: Bool) {
        let parts = v.trimmingCharacters(in: CharacterSet(charactersIn: "vV")).split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        return (parts[0].split(separator: ".").map { Int($0) ?? 0 }, parts.count > 1)
    }
    let r = parse(remote), l = parse(local)
    for i in 0..<max(r.nums.count, l.nums.count) {
        let a = i < r.nums.count ? r.nums[i] : 0, b = i < l.nums.count ? l.nums[i] : 0
        if a != b { return a > b }
    }
    return l.pre && !r.pre
}
