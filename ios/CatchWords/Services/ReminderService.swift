import Foundation
import UserNotifications
import CoreLocation

/// Local notifications for 「復習の通知」 (off / auto / custom times) and 「場所でリマインド」.
enum ReminderService {
    static let modeKey = "reminder.mode"
    static let timesKey = "reminder.times"
    static let placeKey = "place.remind"
    private static let reviewPrefix = "review-"
    private static let placePrefix = "place-"

    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        case .denied: return false
        default: return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        }
    }

    static func parseTimes(_ raw: String) -> [String] {
        let list = raw.split(separator: ",").map(String.init).filter { $0.count == 5 }
        return list.isEmpty ? ["20:00"] : list
    }

    /// Replaces every pending review reminder. "ai" = one daily nudge in the evening.
    static func applyReview(mode: String, times: [String]) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(reviewPrefix) })
        let slots: [String]
        switch mode {
        case "ai": slots = ["20:00"]
        case "custom": slots = times
        default: return
        }
        for (i, t) in slots.enumerated() {
            let parts = t.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2 else { continue }
            let content = UNMutableNotificationContent()
            content.title = "CatchWords"
            content.body = "今日の復習が待っています。1枚だけでも思い出してみよう"
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: parts[0], minute: parts[1]), repeats: true)
            try? await center.add(UNNotificationRequest(identifier: "\(reviewPrefix)\(i)", content: content, trigger: trigger))
        }
    }

    /// One arrival notification per recent catch location (max 20, 150 m radius).
    static func applyPlaces(enabled: Bool, stickers: [Sticker]) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(placePrefix) })
        guard enabled else { return }
        LocationService.shared.requestPermissionIfNeeded()
        var used: [CLLocation] = []
        for s in stickers {
            guard used.count < 20, let la = s.lat, let lo = s.lng, let head = s.word?.headword else { continue }
            let here = CLLocation(latitude: la, longitude: lo)
            if used.contains(where: { $0.distance(from: here) < 200 }) { continue }
            used.append(here)
            let region = CLCircularRegion(center: here.coordinate, radius: 150, identifier: "\(placePrefix)\(s.id)")
            region.notifyOnEntry = true
            region.notifyOnExit = false
            let content = UNMutableNotificationContent()
            content.title = "ここで覚えた単語"
            content.body = "\(s.locationName ?? "この場所")で「\(head)」をキャッチしました。覚えていますか？"
            content.sound = .default
            let trigger = UNLocationNotificationTrigger(region: region, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: region.identifier, content: content, trigger: trigger))
        }
    }
}
