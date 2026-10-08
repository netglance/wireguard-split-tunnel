import Foundation
import UserNotifications

/// Posts system notifications; `onTap` runs when the user clicks one.
@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    var onTap: () -> Void = {}

    /// `swift run` has no bundle, and UNUserNotificationCenter crashes without one.
    private var center: UNUserNotificationCenter? {
        Bundle.main.bundleIdentifier == nil ? nil : UNUserNotificationCenter.current()
    }

    override init() {
        super.init()
        center?.delegate = self
    }

    func requestPermission() {
        center?.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func post(id: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = "Split Tunnel"
        content.body = body
        center?.add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        await MainActor.run { onTap() }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
