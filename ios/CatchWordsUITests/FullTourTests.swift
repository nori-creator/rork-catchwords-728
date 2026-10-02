import XCTest

/// Walks through every main screen of the real app against the offline demo backend (`-uiDemo`), once per
/// display language × learning language, taking a screenshot of each step and checking that no text on
/// screen is written in a language that is neither the display language nor the learning language.
///
/// Screenshots are kept as attachments (named `<display>_<learning>_<nn>_<step>`); CI exports them to the
/// ci-previews branch.
@MainActor
final class FullTourTests: XCTestCase {
    private var app: XCUIApplication!
    private var display = "ja"
    private var learning = "zh-TW"
    private var step = 0

    // The display language is the learner's native language, never the learning language.
    func test_1_ja_zh() { tour(display: "ja", learning: "zh-TW") }
    func test_2_ja_en() { tour(display: "ja", learning: "en") }
    func test_3_en_zh() { tour(display: "en", learning: "zh-TW") }
    func test_4_en_ja() { tour(display: "en", learning: "ja") }
    func test_5_zh_en() { tour(display: "zh-TW", learning: "en") }
    func test_6_zh_ja() { tour(display: "zh-TW", learning: "ja") }

    // MARK: - The tour

    private func tour(display: String, learning: String) {
        continueAfterFailure = true
        self.display = display
        self.learning = learning
        step = 0
        app = XCUIApplication()
        let appleLang = display == "zh-TW" ? "zh-Hant" : display
        app.launchArguments = [
            "-uiDemo", learning, "-uiDemoReset", "YES",
            "-ui.lang", display,
            "-onboarding.done", "YES", "-tour.pending", "NO",
            "-AppleLanguages", "(\(appleLang))", "-AppleLocale", display == "zh-TW" ? "zh_TW" : (display == "en" ? "en_US" : "ja_JP"),
        ]
        app.launch()

        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 30), "the tab bar did not appear")
        settle(2)
        snap("home")
        app.swipeUp()
        snap("home-scrolled")

        dexAndDetail()
        searchAndCatch()
        review()
        wordbooks()
        settings()
        signOutAndBackIn()
    }

    private func dexAndDetail() {
        tap("tab.dex")
        settle(2)
        snap("dex")
        let cell = app.buttons["dex.cell"].firstMatch
        guard cell.waitForExistence(timeout: 10) else {
            XCTFail("[\(display)/\(learning)] the dex shows no words")
            return
        }
        cell.tap()
        settle(2)
        snap("detail-top")
        for i in 1...5 {
            app.swipeUp()
            settle(0.5)
            snap("detail-\(i)")
        }
        if app.buttons["detail.sections"].exists {
            app.buttons["detail.sections"].tap()
            settle(1)
            snap("detail-sections")
            dismissPopover()
        }
        if app.buttons["detail.close"].exists {
            app.buttons["detail.close"].tap()
        } else {
            app.swipeDown(velocity: .fast)
        }
        settle(1)
    }

    private func searchAndCatch() {
        tap("tab.camera")
        settle(2)
        snap("camera")
        let search = app.buttons["camera.mode.search"]
        guard search.waitForExistence(timeout: 10) else {
            XCTFail("[\(display)/\(learning)] no search mode on the camera")
            return
        }
        search.tap()
        let field = app.textFields["search.field"]
        guard field.waitForExistence(timeout: 10) else {
            XCTFail("[\(display)/\(learning)] the search sheet did not open")
            return
        }
        snap("search")
        field.tap()
        field.typeText(sampleWord)
        tap("search.submit")
        let first = app.buttons["candidate.0"].firstMatch
        if first.waitForExistence(timeout: 20) {
            settle(1)
            snap("candidates")
            first.tap()
            if app.buttons["candidate.confirm"].waitForExistence(timeout: 3) {
                snap("candidate-others")
                app.buttons["candidate.confirm"].tap()
            }
        }
        let catchButton = app.buttons["card.catch"]
        guard catchButton.waitForExistence(timeout: 30) else {
            XCTFail("[\(display)/\(learning)] the word card did not open after searching")
            snap("search-failed")
            return
        }
        settle(2)
        snap("card")
        catchButton.tap()
        settle(4)
        snap("after-catch")
        settle(4)
        snap("dex-after-catch")
    }

    private func review() {
        tap("tab.review")
        settle(2)
        snap("review")
        for i in 1...6 {
            let correct = app.buttons["quiz.choice.correct"].firstMatch
            let wrong = app.buttons["quiz.choice"].firstMatch
            // Answer wrong once to see the "try again" side too.
            let pick = (i == 2 && wrong.exists) ? wrong : correct
            guard pick.waitForExistence(timeout: 8) else { break }
            pick.tap()
            settle(1.2)
            snap("answer-\(i)")
            let next = app.buttons["answer.next"]
            guard next.waitForExistence(timeout: 5) else { break }
            next.tap()
            settle(1)
        }
        snap("review-end")
    }

    private func wordbooks() {
        let open = app.buttons["review.wordbooks"]
        guard open.waitForExistence(timeout: 5) else { return }
        open.tap()
        settle(2)
        snap("wordbooks")
        // Close it (a full-screen cover with its own close button in the top bar).
        let close = app.buttons.matching(NSPredicate(format: "identifier == 'wordbook.close' OR label IN %@", closeLabels)).firstMatch
        if close.exists { close.tap() } else { app.swipeDown(velocity: .fast) }
        settle(1)
    }

    private func settings() {
        tap("tab.settings")
        settle(2)
        snap("settings")
        for wheel in ["settings.wheel.native", "settings.wheel.target", "settings.wheel.current", "settings.wheel.goal"] {
            let row = app.buttons[wheel]
            guard row.waitForExistence(timeout: 4) else {
                XCTFail("[\(display)/\(learning)] \(wheel) missing")
                continue
            }
            row.tap()
            settle(1)
            snap(wheel.replacingOccurrences(of: "settings.", with: ""))
            // Close without changing anything (each wheel saves only when closed, and only a change).
            if app.buttons["wheel.close"].waitForExistence(timeout: 3) { app.buttons["wheel.close"].tap() }
            settle(0.8)
        }
        for i in 1...5 {
            app.swipeUp()
            settle(0.6)
            snap("settings-\(i)")
        }
    }

    private func signOutAndBackIn() {
        let out = app.buttons["settings.signOut"]
        guard out.waitForExistence(timeout: 5) else { return }
        out.tap()
        let confirm = app.buttons["settings.signOut.confirm"]
        if confirm.waitForExistence(timeout: 3) { confirm.tap() }
        let mail = app.buttons["auth.mail"]
        guard mail.waitForExistence(timeout: 10) else {
            XCTFail("[\(display)/\(learning)] the sign-in screen did not appear after signing out")
            return
        }
        settle(1)
        snap("auth")
        mail.tap()
        settle(1)
        // A wrong password first: the error must be in the display language.
        fill("auth.email", "demo@catchwords.test")
        fill("auth.password", "wrong")
        tap("auth.submit")
        settle(2)
        snap("auth-error")
        let password = app.secureTextFields["auth.password"]
        password.tap()
        // A secure field empties itself when typing starts again; the deletes cover the other case.
        password.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 10) + "demo-pass-1234")
        tap("auth.submit")
        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 20), "[\(display)/\(learning)] signing in again failed")
        settle(1)
        snap("signed-in-again")
    }

    // MARK: - Helpers

    private var sampleWord: String {
        switch learning {
        case "en": "mango"
        case "ja": "傘"
        default: "芒果"
        }
    }

    private var closeLabels: [String] { ["閉じる", "Close", "關閉"] }

    private func tap(_ id: String) {
        let e = app.buttons[id]
        if e.waitForExistence(timeout: 10) {
            e.tap()
        } else {
            XCTFail("[\(display)/\(learning)] \(id) not found")
        }
    }

    private func fill(_ id: String, _ text: String) {
        let field = id == "auth.password" ? app.secureTextFields[id] : app.textFields[id]
        guard field.waitForExistence(timeout: 5) else {
            XCTFail("[\(display)/\(learning)] \(id) not found")
            return
        }
        field.tap()
        field.typeText(text)
    }

    private func dismissPopover() {
        // Tap outside the popover, near the top-left corner.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.12)).tap()
        settle(0.6)
    }

    private func settle(_ seconds: Double) {
        Thread.sleep(forTimeInterval: seconds)
    }

    /// Screenshot + the language check of everything readable on screen.
    private func snap(_ name: String) {
        step += 1
        let shot = XCTAttachment(screenshot: app.screenshot())
        let tag = display == "zh-TW" ? "zh" : display
        let learn = learning == "zh-TW" ? "zh" : learning
        shot.name = String(format: "%@_%@_%02d_%@", tag, learn, step, name)
        shot.lifetime = .keepAlways
        add(shot)
        checkLanguage(at: name)
    }

    /// One snapshot of the whole screen (a single round trip), then every label and value in it.
    private func checkLanguage(at screen: String) {
        guard let root = try? app.snapshot() else { return }
        var labels: Set<String> = []
        var stack: [XCUIElementSnapshot] = [root]
        while let e = stack.popLast() {
            let l = e.label.trimmingCharacters(in: .whitespacesAndNewlines)
            if !l.isEmpty { labels.insert(l) }
            if let v = e.value as? String {
                let t = v.trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty { labels.insert(t) }
            }
            stack.append(contentsOf: e.children)
        }
        for text in labels {
            if let problem = LanguageCheck.problem(text, display: display, learning: learning) {
                XCTFail("[\(display)/\(learning)] \(screen): \(problem) — 「\(text.prefix(80))」")
            }
        }
    }
}

/// Which scripts may appear: those of the display language and of the learning language only.
enum LanguageCheck {
    /// Latin words allowed on any screen (names, exam scales, units).
    static let latinAllowed: Set<String> = [
        "catchwords", "pro", "tocfl", "cefr", "jlpt", "ipa", "toefl", "ielts", "band", "level", "apple", "google",
        "app", "store", "ai", "gre", "cet", "iphone", "ipad", "ok", "lv", "unsplash", "wikimedia", "youtube",
        "youglish", "dcard", "threads", "reddit", "instagram", "merriam", "webster", "weblio", "kotobank", "jisho",
        "chiebukuro", "moe", "abc", "zhuyin", "pinyin", "demo", "catchwords.test",
    ]

    static func problem(_ text: String, display: String, learning: String) -> String? {
        var kana = 0, han = 0, hangul = 0, bopomofo = 0
        for u in text.unicodeScalars {
            let v = u.value
            if (0x3041...0x30FF).contains(v) || (0x31F0...0x31FF).contains(v) { kana += 1 }
            if (0x4E00...0x9FFF).contains(v) || (0x3400...0x4DBF).contains(v) { han += 1 }
            if (0xAC00...0xD7AF).contains(v) { hangul += 1 }
            if (0x3100...0x312F).contains(v) || (0x31A0...0x31BF).contains(v) { bopomofo += 1 }
        }
        let uses = Set([display, learning])
        if hangul > 0 { return "Korean text" }
        if kana > 0 && !uses.contains("ja") { return "Japanese kana on a screen without Japanese" }
        if bopomofo > 0 && learning != "zh-TW" { return "zhuyin while not learning Mandarin" }
        if han > 0 && !uses.contains("ja") && !uses.contains("zh-TW") { return "Chinese characters on an English-only screen" }
        if !uses.contains("en") {
            // Latin words (not pinyin, romaji or names) on a Japanese / Chinese screen.
            let words = text.split { !$0.isLetter && $0 != "'" }.map(String.init)
            for w in words where w.count >= 3 {
                let plainAscii = w.unicodeScalars.allSatisfy { $0.isASCII && CharacterSet.letters.contains($0) }
                guard plainAscii else { continue }  // pinyin with tone marks, romaji with macrons
                if latinAllowed.contains(w.lowercased()) { continue }
                if learning == "ja" || learning == "zh-TW" {
                    // Romaji / toneless pinyin may appear as readings: only flag Capitalised English-looking words.
                    guard w.first?.isUppercase == true, w.count >= 4 else { continue }
                }
                return "English word \"\(w)\" on a screen without English"
            }
        }
        return nil
    }
}
