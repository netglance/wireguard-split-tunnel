import AppKit
import SplitTunnelCore

enum Banner {
    case noNetwork, problem(Site), awaiting, newIP(Site), outdated, viaVPN(Site), tunnelOff, allGood(Int), noSites
}

@MainActor @Observable
final class AppModel {
    var state: AppState { didSet { save() } }
    var networkDown = false
    /// nil until the first route probe of this session, so the panel does not flash "tunnel off" at launch.
    var tunnelUp: Bool?
    var checking = false
    var showUpdateSheet = false
    var availableUpdate: Release?
    var errorMessage: String?
    /// Set by the menu bar label, the one view that always exists and has `openWindow`.
    @ObservationIgnored var openMainWindow: () -> Void = {}
    @ObservationIgnored let notifier = Notifier()
    @ObservationIgnored var lastUpdateCheck: Date?
    @ObservationIgnored var recheckRequested = false
    /// False when the settings file is unusable and could not be moved aside: saving would destroy it.
    @ObservationIgnored let canSave: Bool

    static let stateURL = URL.applicationSupportDirectory.appending(path: "SplitTunnel/state.json")

    init() {
        let loaded = AppState.load(from: Self.stateURL)
        state = loaded.state
        canSave = loaded.canSave
        if !canSave { errorMessage = String(localized: "Settings file is unreadable and could not be moved aside; changes will not be saved.") }
        notifier.onTap = { [weak self] in self?.requestUpdate() }
        Task { await loop() }
    }

    // MARK: Derived state for views

    var sortedSites: [Site] {
        state.sites.sorted { ($0.status?.level ?? .idle) > ($1.status?.level ?? .idle) }
    }

    /// Dot color on the menu bar icon: nil, .warn or .bad.
    var iconDot: Level? {
        let worst = state.sites.compactMap { $0.status?.level }.max() ?? .good
        if worst == .bad { return .bad }
        return worst == .warn || state.awaitingUpdate || state.pendingChanges > 0 ? .warn : nil
    }

    var banner: Banner {
        if networkDown { return .noNetwork }
        let sites = sortedSites
        let outdated = state.needsUpdate
        guard let worst = sites.first else { return outdated ? .outdated : .noSites }
        if worst.status?.level == .bad { return .problem(worst) }
        if let site = sites.first(where: \.hasNewIPs) { return .newIP(site) }
        if outdated { return .outdated }
        if state.awaitingUpdate { return .awaiting }
        if let site = sites.first(where: { $0.status?.route == .tunnel }) { return .viaVPN(site) }
        if tunnelUp == false { return .tunnelOff }
        return .allGood(sites.count)
    }

    var showCoffee: Bool { state.confirmedOnce && !state.coffeeDismissed && iconDot == nil }
}
