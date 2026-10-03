import Foundation
import Observation

/// Consent to send the learner's photos, words and text to third-party AI (App Store Review Guideline
/// 5.1.2(i): "clearly disclose where personal data will be shared with third parties, including with
/// third-party AI, and obtain explicit permission before doing so"; privacy policy chapter 4).
///
/// - Asked once per account (`AIConsentView`, over the app right after sign-in / onboarding), before the
///   first AI feature and before the camera opens.
/// - The one gate: `NativeAPI.call` refuses every function in `aiFunctions` with
///   `APIError.aiConsentRequired` until this account has agreed, before anything leaves the phone. The
///   screens only decide what to show instead (the camera tab's `AIConsentGateView`, the consent sheet).
/// - Kept on this device per account (`aiConsent.<userId>`: status, version, date). Withdrawn in 設定.
///   The server should keep its own record too (docs/self-managing-ios.md, web W1).
@Observable
final class AIConsent {
    static let shared = AIConsent()

    /// Raise when what is sent, or to whom, changes: a consent given to an older version is asked again
    /// (privacy policy 14: a new third party needs a new consent).
    static let currentVersion = 1

    /// Server functions that send the learner's photos, words or text on to an AI provider.
    /// Reads of what was already written (meanings, explanations), saving, review grading and speech are
    /// not here: they do not hand personal data to an AI.
    static let aiFunctions: Set<String> = [
        "suggestWords",           // photo → candidates
        "detectScan",             // scan frame → words
        "rankScanCandidates",     // the words a scan found
        "suggestWordCandidates",  // typed or spoken word → names
        "generateCard",           // word → card, notes, example sentences
        "regenerateCardSection",  // word → one section written again
        "reportAndFixSection",    // the learner's note on a wrong item
        "getJournalPrompts",      // today's catches → diary prompts
        "correctMyJournal",       // diary text → correction
    ]

    enum Status: Equatable {
        case undecided
        case granted(Date)
        case declined(Date)
    }

    private(set) var status: Status = .undecided
    /// Read for the signed-in account (false while signed out).
    private(set) var isLoaded = false
    /// The account `status` belongs to.
    private var userId: String?

    var isGranted: Bool {
        if case .granted = status { return true }
        return false
    }

    var isUndecided: Bool { status == .undecided }

    // MARK: - Reading and saving

    private static let keyPrefix = "aiConsent"

    private static func key(for userId: String?) -> String {
        guard let userId else { return keyPrefix }   // no account: the device's own answer
        return keyPrefix + "." + userId
    }

    /// After sign-in: this account's answer on this device.
    func load(userId: String?) {
        self.userId = userId
        isLoaded = true
        guard let record = UserDefaults.standard.dictionary(forKey: Self.key(for: userId)),
              let state = record["status"] as? String else {
            status = .undecided
            return
        }
        let version = record["version"] as? Int ?? 0
        let date = Date(timeIntervalSince1970: record["date"] as? Double ?? 0)
        switch state {
        case "granted" where version >= Self.currentVersion: status = .granted(date)
        case "declined": status = .declined(date)
        default: status = .undecided   // agreed to an older version: asked again
        }
    }

    /// Signed out: nothing is known until the next account's answer is read.
    func reset() {
        userId = nil
        isLoaded = false
        status = .undecided
    }

    /// 「同意して始める」.
    func grant() {
        save("granted")
        // Photos left in 「解析待ち」 can be analyzed now.
        PendingRetry.shared.kick()
    }

    /// 「同意しない」, or withdrawing it in 設定: the AI features are blocked again.
    func decline() {
        save("declined")
    }

    private func save(_ state: String) {
        let now = Date()
        UserDefaults.standard.set([
            "status": state,
            "version": Self.currentVersion,
            "date": now.timeIntervalSince1970,
        ] as [String: Any], forKey: Self.key(for: userId))
        status = state == "granted" ? .granted(now) : .declined(now)
    }

    /// The gate (`NativeAPI.call`): whether an AI request may go out now, for the account signed in now.
    func allowsSending() -> Bool {
        let current = SupabaseClient.shared.userId
        if !isLoaded || current != userId { load(userId: current) }
        return isGranted
    }

    /// Account deleted: its answer goes with it.
    static func removeRecord(userId: String?) {
        UserDefaults.standard.removeObject(forKey: key(for: userId))
    }
}
