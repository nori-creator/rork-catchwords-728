import SwiftUI
import UserNotifications

/// Where a tapped notification leads (web: review reminder → /review, place reminder → that word).
enum NotificationRoute: Equatable {
    case review
    /// The milestone album (web /home?memorial=N): home, where its entry sits on the page.
    case home
    case sticker(String)
    /// 「解析が終わりました」 (PendingRetry): the 「解析待ち」 list on the camera, to pick the word.
    case pendingPhotos
}

/// Receives taps on the app's notifications and hands the destination to the tab shell.
@Observable
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationRouter()
    /// The destination waiting to be opened (cleared by the tab shell once it has navigated).
    var pending: NotificationRoute?

    func install() {
        UNUserNotificationCenter.current().delegate = self
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let id = response.notification.request.identifier
        await MainActor.run {
            if id.hasPrefix(ReminderService.placeIdentifierPrefix) {
                pending = .sticker(String(id.dropFirst(ReminderService.placeIdentifierPrefix.count)))
            } else if id == Milestone.notificationId {
                pending = .home
            } else if id.hasPrefix(ReminderService.reviewIdentifierPrefix) {
                pending = .review
            } else if id.hasPrefix(PendingRetry.notificationPrefix) {
                pending = .pendingPhotos
            }
        }
    }

    /// A reminder that fires while the app is open still shows as a banner.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
