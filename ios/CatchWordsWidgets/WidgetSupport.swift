import WidgetKit
import SwiftUI
import UIKit

// MARK: - Look

enum WidgetStyle {
    /// The app's blue (#0A7AFF).
    static let accent = Color(red: 10 / 255, green: 122 / 255, blue: 255 / 255)
    static let ink = Color(red: 0.11, green: 0.12, blue: 0.14)
    static let subInk = Color(red: 0.42, green: 0.45, blue: 0.50)
    static let tile = Color(red: 0.94, green: 0.96, blue: 1.0)
}

// MARK: - Text (the widget follows the app's display language, written into the snapshot)

enum WidgetText {
    enum Key {
        case todayName, todayDesc, reviewName, reviewDesc, remaining, allDone, emptyWords, wordsCaught,
             streak, reviewing, correct, liveDone, dueLabel
    }

    /// The app's display language; before the app has written anything, the device's language.
    static var currentLang: String {
        if let l = WidgetShared.load()?.lang { return l }
        for id in Locale.preferredLanguages {
            let l = id.lowercased()
            if l.hasPrefix("ja") { return "ja" }
            if l.hasPrefix("zh") { return "zh-TW" }
            if l.hasPrefix("en") { return "en" }
        }
        return "ja"
    }

    static func t(_ key: Key, _ lang: String) -> String {
        let (ja, en, zh) = table(key)
        switch lang {
        case "en": return en
        case "zh-TW": return zh
        default: return ja
        }
    }

    /// `%d` replaced by `n`.
    static func t(_ key: Key, _ lang: String, _ n: Int) -> String {
        t(key, lang).replacingOccurrences(of: "%d", with: "\(n)")
    }

    private static func table(_ key: Key) -> (String, String, String) {
        switch key {
        case .todayName: ("今日の単語", "Word of the Day", "今日單字")
        case .todayDesc: ("図鑑から毎日ひとつ、単語を表示します。", "A word from your collection, every day.", "每天從圖鑑中顯示一個單字。")
        case .reviewName: ("復習", "Review", "複習")
        case .reviewDesc: ("復習するカードの枚数を表示します。", "Shows how many cards are due for review.", "顯示需要複習的卡片數量。")
        case .remaining: ("あと %d 枚", "%d left", "還有 %d 張")
        case .allDone: ("今日の復習は完了", "All caught up", "今天的複習完成了")
        case .emptyWords: ("写真を撮って単語を集めよう", "Take a photo to catch a word", "拍照收集單字吧")
        case .wordsCaught: ("%d 語", "%d words", "%d 個單字")
        case .streak: ("%d日連続", "%d-day streak", "連續 %d 天")
        case .reviewing: ("復習中", "Reviewing", "複習中")
        case .correct: ("正解 %d", "%d correct", "答對 %d")
        case .liveDone: ("復習おつかれさま", "Review complete", "複習完成")
        case .dueLabel: ("復習", "Due", "複習")
        }
    }
}

// MARK: - Timeline

struct CatchWordsEntry: TimelineEntry {
    let date: Date
    let lang: String
    let word: WidgetWord?
    let image: UIImage?
    let due: Int
    let totalWords: Int
    let streak: Int?
    /// The app has written a snapshot at least once.
    let hasData: Bool

    static func make(at date: Date, snapshot: WidgetSnapshot?) -> CatchWordsEntry {
        let word = snapshot?.word(for: date)
        let image = word?.thumbFile
            .flatMap { WidgetShared.thumbURL($0) }
            .flatMap { UIImage(contentsOfFile: $0.path) }
        return CatchWordsEntry(date: date, lang: snapshot?.lang ?? WidgetText.currentLang, word: word, image: image,
                               due: snapshot?.dueCount(at: date) ?? 0, totalWords: snapshot?.totalWords ?? 0,
                               streak: snapshot?.streak, hasData: snapshot != nil)
    }

    /// Widget gallery / placeholder.
    static func sample(lang: String) -> CatchWordsEntry {
        let word: WidgetWord = switch lang {
        case "en": WidgetWord(day: "", stickerId: "", headword: "umbrella", reading: nil, meaning: "umbrella", thumbFile: nil, isCutout: false)
        case "zh-TW": WidgetWord(day: "", stickerId: "", headword: "雨傘", reading: "ㄩˇ ㄙㄢˇ", meaning: "雨傘", thumbFile: nil, isCutout: false)
        default: WidgetWord(day: "", stickerId: "", headword: "雨傘", reading: "ㄩˇ ㄙㄢˇ", meaning: "かさ", thumbFile: nil, isCutout: false)
        }
        return CatchWordsEntry(date: Date(), lang: lang, word: word, image: nil, due: 3, totalWords: 42, streak: 5, hasData: true)
    }
}

struct CatchWordsProvider: TimelineProvider {
    func placeholder(in context: Context) -> CatchWordsEntry {
        .sample(lang: WidgetText.currentLang)
    }

    func getSnapshot(in context: Context, completion: @escaping (CatchWordsEntry) -> Void) {
        let snap = WidgetShared.load()
        if context.isPreview && (snap == nil || snap?.words.isEmpty == true) {
            completion(.sample(lang: snap?.lang ?? WidgetText.currentLang))
        } else {
            completion(.make(at: Date(), snapshot: snap))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CatchWordsEntry>) -> Void) {
        let now = Date()
        let snap = WidgetShared.load()
        let cal = Calendar.current
        let midnight = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)) ?? now.addingTimeInterval(86_400)
        // A new entry whenever a card comes due today (the count goes up on its own) and at midnight (new word).
        var dates: Set<Date> = [now, midnight]
        for d in (snap?.upcomingDue ?? []) where d > now && d < midnight {
            dates.insert(d)
            if dates.count >= 40 { break }
        }
        let entries = dates.sorted().map { CatchWordsEntry.make(at: $0, snapshot: snap) }
        completion(Timeline(entries: entries, policy: .after(midnight)))
    }
}

// MARK: - Pieces

/// The word's photo (cropped) or cut-out (drawn whole), on a soft tile when there is none.
struct WordThumb: View {
    let image: UIImage?
    let isCutout: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(isCutout || image == nil ? WidgetStyle.tile : .white)
            if let image {
                if isCutout {
                    Image(uiImage: image).resizable().scaledToFit().padding(6)
                } else {
                    Image(uiImage: image).resizable().scaledToFill()
                }
            } else {
                Image(systemName: "camera.macro").font(.system(size: 22, weight: .semibold)).foregroundStyle(WidgetStyle.accent.opacity(0.6))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// A blue progress ring (Live Activity / lock screen).
struct ProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 3

    var body: some View {
        ZStack {
            Circle().stroke(WidgetStyle.accent.opacity(0.25), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(WidgetStyle.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

enum DeepLink {
    static let review = URL(string: "catchwords://review")!
    static func word(_ id: String) -> URL {
        id.isEmpty ? review : (URL(string: "catchwords://word/\(id)") ?? review)
    }
}
