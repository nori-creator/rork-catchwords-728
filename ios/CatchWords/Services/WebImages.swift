import Foundation
import UIKit

/// One picture the web's image search offers for a word (images.functions.ts `ImageCandidate`):
/// an Unsplash / Wikimedia photo, or an AI illustration sent inline as a `data:` URL.
nonisolated struct WebImageCandidate: Decodable, Sendable, Hashable, Identifiable {
    struct Credit: Decodable, Sendable, Hashable {
        let name: String?
        let link: String?
    }

    let url: String
    let thumb: String?
    let source: String
    let credit: Credit?

    var id: String { url }
    /// The small version for tiles (AI pictures have only the one).
    var previewURL: URL? { URL(string: thumb ?? url) }
    /// What is saved with the word (`stickers.placeholder_credit`).
    var creditPayload: [String: Any] {
        var out: [String: Any] = ["source": source]
        if let n = credit?.name { out["name"] = n }
        if let l = credit?.link { out["link"] = l }
        return out
    }
}

/// Pictures from the internet for a word (web use-web-images.ts / use-auto-hero.ts). The search words
/// come from `LanguageRules.heroSearchQuery` only, the same rule the web uses, so the picture a word
/// gets on the iPhone is the one it gets on the web.
@MainActor
enum WebImages {
    private static var cache: [String: [WebImageCandidate]] = [:]

    /// The same hosts the web's `fetchImageAsDataUrl` accepts; anything else is never downloaded.
    private static let allowedHosts: Set<String> = ["images.unsplash.com", "plus.unsplash.com", "upload.wikimedia.org"]

    /// Search candidates. `round` > 0 is 「別の画像」: the web searches again with the headword added.
    static func search(headword: String, meaning: String?, round: Int = 0) async throws -> [WebImageCandidate] {
        let base = LanguageRules.heroSearchQuery(headword: headword, meaning: meaning)
        // Never send an empty search (a word with no headword and no meaning simply has no picture).
        guard !base.isEmpty else { return [] }
        let query = round == 0 ? base : "\(base) \(headword)"
        if let hit = cache[query] { return hit }
        struct Res: Decodable { let candidates: [WebImageCandidate] }
        let r = try await NativeAPI.call("searchImageCandidates", ["query": query], as: Res.self, timeout: 60)
        cache[query] = r.candidates
        return r.candidates
    }

    /// Previews only: what a search for this word returns, without the network.
    static func seed(headword: String, meaning: String?, candidates: [WebImageCandidate]) {
        cache[LanguageRules.heroSearchQuery(headword: headword, meaning: meaning)] = candidates
    }

    private static var inline: [String: UIImage] = [:]

    /// An AI picture sent inline (`data:` URL), decoded once; nil for pictures on the web.
    static func inlineImage(_ candidate: WebImageCandidate) -> UIImage? {
        guard candidate.url.hasPrefix("data:") else { return nil }
        if let hit = inline[candidate.url] { return hit }
        guard let comma = candidate.url.firstIndex(of: ","),
              let data = Data(base64Encoded: String(candidate.url[candidate.url.index(after: comma)...])),
              let img = UIImage(data: data) else { return nil }
        inline[candidate.url] = img
        return img
    }

    /// The candidate's full picture: decoded from a `data:` URL, or downloaded from an allowed https host.
    static func image(for candidate: WebImageCandidate) async throws -> UIImage {
        if candidate.url.hasPrefix("data:") {
            guard let img = inlineImage(candidate) else { throw APIError.decoding }
            return img
        }
        guard let url = URL(string: candidate.url), url.scheme == "https",
              let host = url.host?.lowercased(), allowedHosts.contains(host) else { throw APIError.decoding }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200, let img = UIImage(data: data) else { throw APIError.decoding }
        return img
    }
}
