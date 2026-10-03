import Foundation
import UserNotifications
import WidgetKit

/// What stays on the device after a sign-out or an account deletion.
///
/// - Sign-out: the next person on this phone must not get the previous account's place reminders
///   (they carry its words and place names). Photos waiting in 「解析待ち」 stay — a photo that cannot be
///   retaken is never thrown away just for signing out.
/// - Account deletion (App Store Review Guideline 5.1.1(v)): the server erased the account; the copies on
///   this phone go too — waiting photos, reminders, widget words and thumbnails, diary drafts, cached images.
enum AccountCleanup {
    /// After any sign-out (button, expired login, account deleted).
    static func signedOut() async {
        let center = UNUserNotificationCenter.current()
        let place = ReminderService.placeIdentifierPrefix
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(place) })
        center.removeAllDeliveredNotifications()
        UserDefaults.standard.set(false, forKey: ReminderService.placeKey)
    }

    /// After `deleteMyAccount` succeeded. `userId` is the deleted account (read before signing out).
    static func accountDeleted(userId: String?) async {
        await signedOut()
        // The display language chosen by that account (the sign-out right after resets it too).
        L10n.resetToDevice()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UserDefaults.standard.set("off", forKey: ReminderService.modeKey)
        if let userId { PendingQueue.shared.removeAll(ownerId: userId) }

        // Diary drafts kept on this device for that account (DiaryStore `draftPrefix`).
        if let userId {
            let prefix = "diary-draft-\(userId)-"
            let defaults = UserDefaults.standard
            for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
                defaults.removeObject(forKey: key)
            }
        }

        // Widgets: the word of the day and its photo thumbnails.
        WidgetShared.defaults?.removeObject(forKey: WidgetShared.snapshotKey)
        if let thumbs = WidgetShared.thumbsURL {
            try? FileManager.default.removeItem(at: thumbs)
        }
        WidgetCenter.shared.reloadAllTimelines()

        // Photos fetched through signed URLs may sit in the shared HTTP cache.
        URLCache.shared.removeAllCachedResponses()
    }
}
