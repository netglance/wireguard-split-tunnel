import Foundation
import SplitTunnelCore

func replyText(_ reply: Reply) -> String {
    switch reply {
    case .ok: String(localized: "OK")
    case .rateLimited: String(localized: "429 Too Many Requests")
    case .forbidden: String(localized: "403 Forbidden")
    case .captcha: String(localized: "captcha")
    case .noResponse: String(localized: "no response")
    case .notFound: String(localized: "not found")
    }
}

func routeText(_ route: Route) -> String {
    switch route {
    case .direct: String(localized: "bypasses VPN")
    case .tunnel: String(localized: "through VPN")
    case .tunnelOff, .unknown: String(localized: "route not checked")
    }
}

/// One-line status for the panel, e.g. "bypasses VPN · OK".
func siteSummary(_ site: Site) -> String {
    guard let status = site.status else { return String(localized: "not checked yet") }
    if site.hasNewIPs { return String(localized: "new IP · \(replyText(status.reply))") }
    return "\(routeText(status.route)) · \(replyText(status.reply))"
}

func noticeText(_ notice: Notice) -> String {
    if notice.status.level == .bad {
        if notice.status.reply == .notFound { return String(localized: "\(notice.domain): the address does not resolve. Check the spelling.") }
        if notice.status.route == .tunnel {
            return String(localized: "\(notice.domain) is not working: \(replyText(notice.status.reply)). Update AllowedIPs in WireGuard.")
        }
        return String(localized: "\(notice.domain) is not working: \(replyText(notice.status.reply)). The site blocks this connection even without the VPN.")
    }
    return String(localized: "\(notice.domain) has a new IP. Update AllowedIPs in WireGuard, or the site will go through the VPN.")
}

func configErrorText(_ error: ConfigError) -> String {
    switch error {
    case .noPeer: String(localized: "The config has no [Peer] section.")
    case .multiplePeers: String(localized: "The config has several [Peer] sections. Only one is supported.")
    case .noAllowedIPs: String(localized: "The [Peer] section has no AllowedIPs line.")
    case .noEndpoint: String(localized: "The [Peer] section has no Endpoint line.")
    case .badAddress(let text): String(localized: "AllowedIPs has an invalid address: \(text)")
    }
}
