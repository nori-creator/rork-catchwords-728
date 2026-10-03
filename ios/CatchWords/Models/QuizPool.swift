import Foundation

// The level-matched words that pad the review quiz when the learner's own dex cannot give three distractors
// (owner 2026-10-03: 「データベースの中からレベルが同じくらいの単語。レベルが違いすぎるとおかしい」).
//
// Where the levels come from:
// * The card's level is `words.level`, the exam level the server writes on every card (`generateCard` resolves it
//   against its dictionary): TOCFL-1…6 for 台湾華語, A1…C2 (CEFR) for English, JLPT-N5…N1+ for Japanese, or a 級外
//   value (TOCFL-0 / CEFR-0 / JLPT-0) for a word on no list. `step(_:)` reads every form onto the shared 6-step
//   ladder the same way as the web's level-scale.ts `parseLevelStep`. A card with no readable level (old rows,
//   級外) is matched against step 1, the pool's beginner words.
// * The pool's levels are assigned here by hand, approximating the official lists (TOCFL 華語八千詞, the English
//   Vocabulary Profile's CEFR levels, the old JLPT lists). They are not official data. Steps 1–4 only: the quiz
//   pads with things people meet every day, and a step 5–6 card is padded with the nearest (step 4) words.
//   The server has no word-list endpoint (docs, scripts/check_native_contract.py), so the pool ships in the app.
// * Every word is a concrete everyday noun with one of the app's 54 category keys (Models/Category.swift), so a
//   distractor of the same kind (same key, then same room) is preferred after the level.
// * One list per learning language, never mixed (R3 「4択が学習言語英語なのに台湾華語の単語が混ざってる」).
//   The reading is what the quiz draws with the word: zhuyin (one syllable per character) for 台湾華語, hiragana
//   for a Japanese word with kanji, none for kana-only Japanese words and English.
// The headword strings are learning-language data, not UI text.

nonisolated struct QuizPoolWord: Sendable, Hashable {
    let headword: String
    /// Zhuyin (台湾華語) or hiragana (日本語); nil for English and kana-only words.
    let reading: String?
    /// 1 (beginner) … 4 on the shared 6-step ladder (TOCFL 1–4 / CEFR A1–B2 / JLPT N5–N2).
    let step: Int
    /// One of the 54 category keys.
    let categoryKey: String
}

nonisolated enum QuizPool {
    /// The pool for a learning language ("zh-TW", "en", "ja"; anything else is 台湾華語 like the rest of the app).
    static func words(for target: String) -> [QuizPoolWord] {
        switch target {
        case "en": en
        case "ja": ja
        default: zhTW
        }
    }

    /// The pool ordered for one card: closest level first, then the same category key, then the same room;
    /// ties in random order (the caller caches the drawn choices per card, so they stay put).
    static func ranked(for target: String, level: String?, categoryKey: String?) -> [QuizPoolWord] {
        let want = step(level) ?? 1
        let room = Category.room(for: categoryKey)
        return words(for: target)
            .map { w -> (word: QuizPoolWord, near: Int, kin: Int, tie: Double) in
                let kin = w.categoryKey == categoryKey ? 0 : (Category.room(for: w.categoryKey) == room ? 1 : 2)
                return (w, abs(w.step - want), kin, Double.random(in: 0..<1))
            }
            .sorted { a, b in (a.near, a.kin, a.tie) < (b.near, b.kin, b.tie) }
            .map { $0.word }
    }

    /// level-scale.ts `parseLevelStep`: the step 1–6 of a stored level in any of the three forms, or nil when it
    /// cannot be read or is 級外 (0, 7 or more). JLPT is read first because its numbers run the other way
    /// (N5 = 1 … N1 = 5, N1+ = 6); CEFR before plain digits because "A1" also holds a digit.
    static func step(_ raw: String?) -> Int? {
        guard let s = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        let up = s.uppercased()
        if let g = groups("(?:^|[^A-Z])N([1-5])(\\+?)(?![0-9])", in: up), let n = Int(g[1]) {
            return n == 1 && g[2] == "+" ? 6 : 6 - n
        }
        if let g = groups("\\b([ABC])([12])\\b", in: up), let band = ["A", "B", "C"].firstIndex(of: g[1]), let n = Int(g[2]) {
            return band * 2 + n
        }
        if let g = groups("[0-9]+", in: s), let n = Int(g[0]) {
            return (1...6).contains(n) ? n : nil
        }
        return nil
    }

    /// The first match's groups (index 0 = the whole match; a group that took no part is "").
    private static func groups(_ pattern: String, in s: String) -> [String]? {
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) else { return nil }
        return (0..<m.numberOfRanges).map { i in
            guard let r = Range(m.range(at: i), in: s) else { return "" }
            return String(s[r])
        }
    }

    private static func w(_ headword: String, _ reading: String?, _ step: Int, _ key: String) -> QuizPoolWord {
        QuizPoolWord(headword: headword, reading: reading, step: step, categoryKey: key)
    }

    /// 台湾華語 (TOCFL levels).
    private static let zhTW: [QuizPoolWord] = [
        // TOCFL 1
        w("蘋果", "ㄆㄧㄥˊ ㄍㄨㄛˇ", 1, "fruit"),  // l10n-ignore (target words)
        w("水果", "ㄕㄨㄟˇ ㄍㄨㄛˇ", 1, "fruit"),  // l10n-ignore (target words)
        w("公車", "ㄍㄨㄥ ㄔㄜ", 1, "vehicle"),  // l10n-ignore (target words)
        w("汽車", "ㄑㄧˋ ㄔㄜ", 1, "vehicle"),  // l10n-ignore (target words)
        w("火車", "ㄏㄨㄛˇ ㄔㄜ", 1, "transport"),  // l10n-ignore (target words)
        w("雨傘", "ㄩˇ ㄙㄢˇ", 1, "accessory"),  // l10n-ignore (target words)
        w("便當", "ㄅㄧㄢˋ ㄉㄤ", 1, "food"),  // l10n-ignore (target words)
        w("雞蛋", "ㄐㄧ ㄉㄢˋ", 1, "food"),  // l10n-ignore (target words)
        w("麵包", "ㄇㄧㄢˋ ㄅㄠ", 1, "dessert"),  // l10n-ignore (target words)
        w("咖啡", "ㄎㄚ ㄈㄟ", 1, "drink"),  // l10n-ignore (target words)
        w("牛奶", "ㄋㄧㄡˊ ㄋㄞˇ", 1, "drink"),  // l10n-ignore (target words)
        w("茶", "ㄔㄚˊ", 1, "drink"),  // l10n-ignore (target words)
        w("手機", "ㄕㄡˇ ㄐㄧ", 1, "tech"),  // l10n-ignore (target words)
        w("電腦", "ㄉㄧㄢˋ ㄋㄠˇ", 1, "tech"),  // l10n-ignore (target words)
        w("電視", "ㄉㄧㄢˋ ㄕˋ", 1, "appliance"),  // l10n-ignore (target words)
        w("書包", "ㄕㄨ ㄅㄠ", 1, "bag"),  // l10n-ignore (target words)
        w("老師", "ㄌㄠˇ ㄕ", 1, "job"),  // l10n-ignore (target words)
        w("學校", "ㄒㄩㄝˊ ㄒㄧㄠˋ", 1, "building"),  // l10n-ignore (target words)
        w("醫院", "ㄧ ㄩㄢˋ", 1, "building"),  // l10n-ignore (target words)
        w("飯店", "ㄈㄢˋ ㄉㄧㄢˋ", 1, "building"),  // l10n-ignore (target words)
        w("貓", "ㄇㄠ", 1, "animal"),  // l10n-ignore (target words)
        w("狗", "ㄍㄡˇ", 1, "animal"),  // l10n-ignore (target words)
        w("花", "ㄏㄨㄚ", 1, "flower"),  // l10n-ignore (target words)
        w("書", "ㄕㄨ", 1, "book"),  // l10n-ignore (target words)
        // TOCFL 2
        w("冰箱", "ㄅㄧㄥ ㄒㄧㄤ", 2, "appliance"),  // l10n-ignore (target words)
        w("冷氣", "ㄌㄥˇ ㄑㄧˋ", 2, "appliance"),  // l10n-ignore (target words)
        w("捷運", "ㄐㄧㄝˊ ㄩㄣˋ", 2, "transport"),  // l10n-ignore (target words)
        w("機車", "ㄐㄧ ㄔㄜ", 2, "vehicle"),  // l10n-ignore (target words)
        w("腳踏車", "ㄐㄧㄠˇ ㄊㄚˋ ㄔㄜ", 2, "vehicle"),  // l10n-ignore (target words)
        w("超市", "ㄔㄠ ㄕˋ", 2, "shop"),  // l10n-ignore (target words)
        w("銀行", "ㄧㄣˊ ㄏㄤˊ", 2, "building"),  // l10n-ignore (target words)
        w("郵局", "ㄧㄡˊ ㄐㄩˊ", 2, "building"),  // l10n-ignore (target words)
        w("公園", "ㄍㄨㄥ ㄩㄢˊ", 2, "street"),  // l10n-ignore (target words)
        w("鉛筆", "ㄑㄧㄢ ㄅㄧˇ", 2, "stationery"),  // l10n-ignore (target words)
        w("手錶", "ㄕㄡˇ ㄅㄧㄠˇ", 2, "accessory"),  // l10n-ignore (target words)
        w("眼鏡", "ㄧㄢˇ ㄐㄧㄥˋ", 2, "accessory"),  // l10n-ignore (target words)
        w("襯衫", "ㄔㄣˋ ㄕㄢ", 2, "clothes"),  // l10n-ignore (target words)
        w("牙刷", "ㄧㄚˊ ㄕㄨㄚ", 2, "tool"),  // l10n-ignore (target words)
        w("毛巾", "ㄇㄠˊ ㄐㄧㄣ", 2, "home"),  // l10n-ignore (target words)
        w("香蕉", "ㄒㄧㄤ ㄐㄧㄠ", 2, "fruit"),  // l10n-ignore (target words)
        w("西瓜", "ㄒㄧ ㄍㄨㄚ", 2, "fruit"),  // l10n-ignore (target words)
        w("果汁", "ㄍㄨㄛˇ ㄓ", 2, "drink"),  // l10n-ignore (target words)
        w("蛋糕", "ㄉㄢˋ ㄍㄠ", 2, "dessert"),  // l10n-ignore (target words)
        w("沙發", "ㄕㄚ ㄈㄚ", 2, "furniture"),  // l10n-ignore (target words)
        w("鳥", "ㄋㄧㄠˇ", 2, "animal"),  // l10n-ignore (target words)
        w("樹", "ㄕㄨˋ", 2, "plant"),  // l10n-ignore (target words)
        w("醫生", "ㄧ ㄕㄥ", 2, "job"),  // l10n-ignore (target words)
        // TOCFL 3
        w("吸管", "ㄒㄧ ㄍㄨㄢˇ", 3, "kitchenware"),  // l10n-ignore (target words)
        w("紅綠燈", "ㄏㄨㄥˊ ㄌㄩˋ ㄉㄥ", 3, "sign"),  // l10n-ignore (target words)
        w("斑馬線", "ㄅㄢ ㄇㄚˇ ㄒㄧㄢˋ", 3, "street"),  // l10n-ignore (target words)
        w("停車場", "ㄊㄧㄥˊ ㄔㄜ ㄔㄤˇ", 3, "street"),  // l10n-ignore (target words)
        w("加油站", "ㄐㄧㄚ ㄧㄡˊ ㄓㄢˋ", 3, "building"),  // l10n-ignore (target words)
        w("藥局", "ㄧㄠˋ ㄐㄩˊ", 3, "shop"),  // l10n-ignore (target words)
        w("行李箱", "ㄒㄧㄥˊ ㄌㄧˇ ㄒㄧㄤ", 3, "bag"),  // l10n-ignore (target words)
        w("吹風機", "ㄔㄨㄟ ㄈㄥ ㄐㄧ", 3, "appliance"),  // l10n-ignore (target words)
        w("洗衣機", "ㄒㄧˇ ㄧ ㄐㄧ", 3, "appliance"),  // l10n-ignore (target words)
        w("鍵盤", "ㄐㄧㄢˋ ㄆㄢˊ", 3, "gadget"),  // l10n-ignore (target words)
        w("耳機", "ㄦˇ ㄐㄧ", 3, "gadget"),  // l10n-ignore (target words)
        w("筆記本", "ㄅㄧˇ ㄐㄧˋ ㄅㄣˇ", 3, "stationery"),  // l10n-ignore (target words)
        w("外套", "ㄨㄞˋ ㄊㄠˋ", 3, "clothes"),  // l10n-ignore (target words)
        w("圍巾", "ㄨㄟˊ ㄐㄧㄣ", 3, "accessory"),  // l10n-ignore (target words)
        w("鳳梨", "ㄈㄥˋ ㄌㄧˊ", 3, "fruit"),  // l10n-ignore (target words)
        w("芒果", "ㄇㄤˊ ㄍㄨㄛˇ", 3, "fruit"),  // l10n-ignore (target words)
        w("蝴蝶", "ㄏㄨˊ ㄉㄧㄝˊ", 3, "animal"),  // l10n-ignore (target words)
        w("颱風", "ㄊㄞˊ ㄈㄥ", 3, "weather"),  // l10n-ignore (target words)
        w("微波爐", "ㄨㄟ ㄅㄛ ㄌㄨˊ", 3, "appliance"),  // l10n-ignore (target words)
        w("餐巾紙", "ㄘㄢ ㄐㄧㄣ ㄓˇ", 3, "kitchenware"),  // l10n-ignore (target words)
        // TOCFL 4
        w("電扇", "ㄉㄧㄢˋ ㄕㄢˋ", 4, "appliance"),  // l10n-ignore (target words)
        w("插頭", "ㄔㄚ ㄊㄡˊ", 4, "appliance"),  // l10n-ignore (target words)
        w("延長線", "ㄧㄢˊ ㄔㄤˊ ㄒㄧㄢˋ", 4, "appliance"),  // l10n-ignore (target words)
        w("遙控器", "ㄧㄠˊ ㄎㄨㄥˋ ㄑㄧˋ", 4, "gadget"),  // l10n-ignore (target words)
        w("保溫瓶", "ㄅㄠˇ ㄨㄣ ㄆㄧㄥˊ", 4, "kitchenware"),  // l10n-ignore (target words)
        w("砧板", "ㄓㄣ ㄅㄢˇ", 4, "kitchenware"),  // l10n-ignore (target words)
        w("釘書機", "ㄉㄧㄥ ㄕㄨ ㄐㄧ", 4, "stationery"),  // l10n-ignore (target words)
        w("口罩", "ㄎㄡˇ ㄓㄠˋ", 4, "medicine"),  // l10n-ignore (target words)
        w("雨衣", "ㄩˇ ㄧ", 4, "clothes"),  // l10n-ignore (target words)
        w("安全帽", "ㄢ ㄑㄩㄢˊ ㄇㄠˋ", 4, "accessory"),  // l10n-ignore (target words)
        w("人行道", "ㄖㄣˊ ㄒㄧㄥˊ ㄉㄠˋ", 4, "street"),  // l10n-ignore (target words)
        w("天橋", "ㄊㄧㄢ ㄑㄧㄠˊ", 4, "street"),  // l10n-ignore (target words)
        w("招牌", "ㄓㄠ ㄆㄞˊ", 4, "sign"),  // l10n-ignore (target words)
        w("消防車", "ㄒㄧㄠ ㄈㄤˊ ㄔㄜ", 4, "vehicle"),  // l10n-ignore (target words)
        w("救護車", "ㄐㄧㄡˋ ㄏㄨˋ ㄔㄜ", 4, "vehicle"),  // l10n-ignore (target words)
        w("蓮霧", "ㄌㄧㄢˊ ㄨˋ", 4, "fruit"),  // l10n-ignore (target words)
        w("芭樂", "ㄅㄚ ㄌㄜˋ", 4, "fruit"),  // l10n-ignore (target words)
        w("松鼠", "ㄙㄨㄥ ㄕㄨˇ", 4, "animal"),  // l10n-ignore (target words)
        w("仙人掌", "ㄒㄧㄢ ㄖㄣˊ ㄓㄤˇ", 4, "plant"),  // l10n-ignore (target words)
        w("水龍頭", "ㄕㄨㄟˇ ㄌㄨㄥˊ ㄊㄡˊ", 4, "home"),  // l10n-ignore (target words)
    ]

    /// English (CEFR levels).
    private static let en: [QuizPoolWord] = [
        // A1
        w("apple", nil, 1, "fruit"),
        w("banana", nil, 1, "fruit"),
        w("bus", nil, 1, "vehicle"),
        w("car", nil, 1, "vehicle"),
        w("train", nil, 1, "transport"),
        w("umbrella", nil, 1, "accessory"),
        w("egg", nil, 1, "food"),
        w("bread", nil, 1, "food"),
        w("coffee", nil, 1, "drink"),
        w("milk", nil, 1, "drink"),
        w("tea", nil, 1, "drink"),
        w("phone", nil, 1, "tech"),
        w("computer", nil, 1, "tech"),
        w("television", nil, 1, "appliance"),
        w("bag", nil, 1, "bag"),
        w("teacher", nil, 1, "job"),
        w("school", nil, 1, "building"),
        w("hospital", nil, 1, "building"),
        w("hotel", nil, 1, "building"),
        w("cat", nil, 1, "animal"),
        w("dog", nil, 1, "animal"),
        w("flower", nil, 1, "flower"),
        w("book", nil, 1, "book"),
        w("chair", nil, 1, "furniture"),
        w("table", nil, 1, "furniture"),
        w("shirt", nil, 1, "clothes"),
        // A2
        w("fridge", nil, 2, "appliance"),
        w("bicycle", nil, 2, "vehicle"),
        w("taxi", nil, 2, "vehicle"),
        w("supermarket", nil, 2, "shop"),
        w("bank", nil, 2, "building"),
        w("post office", nil, 2, "building"),
        w("park", nil, 2, "street"),
        w("pencil", nil, 2, "stationery"),
        w("watch", nil, 2, "accessory"),
        w("glasses", nil, 2, "accessory"),
        w("jacket", nil, 2, "clothes"),
        w("toothbrush", nil, 2, "tool"),
        w("towel", nil, 2, "home"),
        w("watermelon", nil, 2, "fruit"),
        w("juice", nil, 2, "drink"),
        w("cake", nil, 2, "dessert"),
        w("sandwich", nil, 2, "food"),
        w("sofa", nil, 2, "furniture"),
        w("lamp", nil, 2, "furniture"),
        w("bird", nil, 2, "animal"),
        w("tree", nil, 2, "plant"),
        w("doctor", nil, 2, "job"),
        // B1
        w("straw", nil, 3, "kitchenware"),
        w("traffic light", nil, 3, "sign"),
        w("crosswalk", nil, 3, "street"),
        w("parking lot", nil, 3, "street"),
        w("gas station", nil, 3, "building"),
        w("pharmacy", nil, 3, "shop"),
        w("suitcase", nil, 3, "bag"),
        w("hair dryer", nil, 3, "appliance"),
        w("washing machine", nil, 3, "appliance"),
        w("microwave", nil, 3, "appliance"),
        w("keyboard", nil, 3, "gadget"),
        w("headphones", nil, 3, "gadget"),
        w("notebook", nil, 3, "stationery"),
        w("scarf", nil, 3, "accessory"),
        w("pineapple", nil, 3, "fruit"),
        w("mango", nil, 3, "fruit"),
        w("butterfly", nil, 3, "animal"),
        w("napkin", nil, 3, "kitchenware"),
        w("helmet", nil, 3, "accessory"),
        w("coat", nil, 3, "clothes"),
        // B2
        w("electric fan", nil, 4, "appliance"),
        w("plug", nil, 4, "appliance"),
        w("extension cord", nil, 4, "appliance"),
        w("remote control", nil, 4, "gadget"),
        w("thermos", nil, 4, "kitchenware"),
        w("chopping board", nil, 4, "kitchenware"),
        w("stapler", nil, 4, "stationery"),
        w("face mask", nil, 4, "medicine"),
        w("raincoat", nil, 4, "clothes"),
        w("sidewalk", nil, 4, "street"),
        w("footbridge", nil, 4, "street"),
        w("signboard", nil, 4, "sign"),
        w("fire engine", nil, 4, "vehicle"),
        w("ambulance", nil, 4, "vehicle"),
        w("guava", nil, 4, "fruit"),
        w("squirrel", nil, 4, "animal"),
        w("cactus", nil, 4, "plant"),
        w("faucet", nil, 4, "home"),
        w("typhoon", nil, 4, "weather"),
    ]

    /// 日本語 (JLPT levels).
    private static let ja: [QuizPoolWord] = [
        // N5
        w("りんご", nil, 1, "fruit"),  // l10n-ignore (target words)
        w("果物", "くだもの", 1, "fruit"),  // l10n-ignore (target words)
        w("バス", nil, 1, "vehicle"),  // l10n-ignore (target words)
        w("車", "くるま", 1, "vehicle"),  // l10n-ignore (target words)
        w("電車", "でんしゃ", 1, "transport"),  // l10n-ignore (target words)
        w("傘", "かさ", 1, "accessory"),  // l10n-ignore (target words)
        w("卵", "たまご", 1, "food"),  // l10n-ignore (target words)
        w("パン", nil, 1, "food"),  // l10n-ignore (target words)
        w("コーヒー", nil, 1, "drink"),  // l10n-ignore (target words)
        w("牛乳", "ぎゅうにゅう", 1, "drink"),  // l10n-ignore (target words)
        w("お茶", "おちゃ", 1, "drink"),  // l10n-ignore (target words)
        w("電話", "でんわ", 1, "tech"),  // l10n-ignore (target words)
        w("テレビ", nil, 1, "appliance"),  // l10n-ignore (target words)
        w("かばん", nil, 1, "bag"),  // l10n-ignore (target words)
        w("先生", "せんせい", 1, "job"),  // l10n-ignore (target words)
        w("学校", "がっこう", 1, "building"),  // l10n-ignore (target words)
        w("病院", "びょういん", 1, "building"),  // l10n-ignore (target words)
        w("猫", "ねこ", 1, "animal"),  // l10n-ignore (target words)
        w("犬", "いぬ", 1, "animal"),  // l10n-ignore (target words)
        w("花", "はな", 1, "flower"),  // l10n-ignore (target words)
        w("本", "ほん", 1, "book"),  // l10n-ignore (target words)
        w("机", "つくえ", 1, "furniture"),  // l10n-ignore (target words)
        w("椅子", "いす", 1, "furniture"),  // l10n-ignore (target words)
        w("時計", "とけい", 1, "accessory"),  // l10n-ignore (target words)
        w("鉛筆", "えんぴつ", 1, "stationery"),  // l10n-ignore (target words)
        w("自転車", "じてんしゃ", 1, "vehicle"),  // l10n-ignore (target words)
        // N4
        w("お弁当", "おべんとう", 2, "food"),  // l10n-ignore (target words)
        w("空港", "くうこう", 2, "building"),  // l10n-ignore (target words)
        w("地下鉄", "ちかてつ", 2, "transport"),  // l10n-ignore (target words)
        w("美術館", "びじゅつかん", 2, "building"),  // l10n-ignore (target words)
        w("工場", "こうじょう", 2, "building"),  // l10n-ignore (target words)
        w("手袋", "てぶくろ", 2, "accessory"),  // l10n-ignore (target words)
        w("下着", "したぎ", 2, "clothes"),  // l10n-ignore (target words)
        w("着物", "きもの", 2, "clothes"),  // l10n-ignore (target words)
        w("鏡", "かがみ", 2, "furniture"),  // l10n-ignore (target words)
        w("棚", "たな", 2, "furniture"),  // l10n-ignore (target words)
        w("布団", "ふとん", 2, "home"),  // l10n-ignore (target words)
        w("人形", "にんぎょう", 2, "toy"),  // l10n-ignore (target words)
        w("指輪", "ゆびわ", 2, "jewelry"),  // l10n-ignore (target words)
        w("虫", "むし", 2, "animal"),  // l10n-ignore (target words)
        w("島", "しま", 2, "nature"),  // l10n-ignore (target words)
        w("歯医者", "はいしゃ", 2, "job"),  // l10n-ignore (target words)
        w("ケーキ", nil, 2, "dessert"),  // l10n-ignore (target words)
        w("ジュース", nil, 2, "drink"),  // l10n-ignore (target words)
        w("スーパー", nil, 2, "shop"),  // l10n-ignore (target words)
        w("パソコン", nil, 2, "tech"),  // l10n-ignore (target words)
        // N3
        w("冷蔵庫", "れいぞうこ", 3, "appliance"),  // l10n-ignore (target words)
        w("掃除機", "そうじき", 3, "appliance"),  // l10n-ignore (target words)
        w("洗濯機", "せんたくき", 3, "appliance"),  // l10n-ignore (target words)
        w("信号", "しんごう", 3, "sign"),  // l10n-ignore (target words)
        w("横断歩道", "おうだんほどう", 3, "street"),  // l10n-ignore (target words)
        w("駐車場", "ちゅうしゃじょう", 3, "street"),  // l10n-ignore (target words)
        w("薬局", "やっきょく", 3, "shop"),  // l10n-ignore (target words)
        w("財布", "さいふ", 3, "accessory"),  // l10n-ignore (target words)
        w("毛布", "もうふ", 3, "home"),  // l10n-ignore (target words)
        w("枕", "まくら", 3, "home"),  // l10n-ignore (target words)
        w("台風", "たいふう", 3, "weather"),  // l10n-ignore (target words)
        w("蝶", "ちょう", 3, "animal"),  // l10n-ignore (target words)
        w("ストロー", nil, 3, "kitchenware"),  // l10n-ignore (target words)
        w("イヤホン", nil, 3, "gadget"),  // l10n-ignore (target words)
        w("スーツケース", nil, 3, "bag"),  // l10n-ignore (target words)
        w("ドライヤー", nil, 3, "appliance"),  // l10n-ignore (target words)
        w("マフラー", nil, 3, "accessory"),  // l10n-ignore (target words)
        w("パイナップル", nil, 3, "fruit"),  // l10n-ignore (target words)
        // N2
        w("扇風機", "せんぷうき", 4, "appliance"),  // l10n-ignore (target words)
        w("炊飯器", "すいはんき", 4, "appliance"),  // l10n-ignore (target words)
        w("電卓", "でんたく", 4, "gadget"),  // l10n-ignore (target words)
        w("消防車", "しょうぼうしゃ", 4, "vehicle"),  // l10n-ignore (target words)
        w("救急車", "きゅうきゅうしゃ", 4, "vehicle"),  // l10n-ignore (target words)
        w("看板", "かんばん", 4, "sign"),  // l10n-ignore (target words)
        w("歩道橋", "ほどうきょう", 4, "street"),  // l10n-ignore (target words)
        w("魔法瓶", "まほうびん", 4, "kitchenware"),  // l10n-ignore (target words)
        w("まな板", "まないた", 4, "kitchenware"),  // l10n-ignore (target words)
        w("蛇口", "じゃぐち", 4, "home"),  // l10n-ignore (target words)
        w("画鋲", "がびょう", 4, "stationery"),  // l10n-ignore (target words)
        w("灯台", "とうだい", 4, "building"),  // l10n-ignore (target words)
        w("雨具", "あまぐ", 4, "clothes"),  // l10n-ignore (target words)
        w("りす", nil, 4, "animal"),  // l10n-ignore (target words)
        w("サボテン", nil, 4, "plant"),  // l10n-ignore (target words)
        w("ホッチキス", nil, 4, "stationery"),  // l10n-ignore (target words)
        w("リモコン", nil, 4, "gadget"),  // l10n-ignore (target words)
        w("マスク", nil, 4, "medicine"),  // l10n-ignore (target words)
    ]
}
