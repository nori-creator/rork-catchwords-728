// Language-mixing regression check (docs/language-rules.md).
// CI: swiftc ios/CatchWords/Utilities/LanguageRules.swift ios/LanguageRules/main.swift -o lr && ./lr ios/LanguageRules/cases.json
import Foundation

struct Case: Decodable {
    let id: String
    let rule: String
    let fn: String
    let text: String
    let reader: String?
    let target: String?
    let source: String?
    let hanOnlyOk: Bool?
    let expect: Bool
    let why: String
}

let path = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "ios/LanguageRules/cases.json"
guard let data = FileManager.default.contents(atPath: path),
      let cases = try? JSONDecoder().decode([Case].self, from: data) else {
    print("::error::cannot read \(path)")
    exit(2)
}

var failed = 0
var ids = Set<String>()
for c in cases {
    if !ids.insert(c.id).inserted { print("::error::duplicate case id \(c.id)"); failed += 1 }
    let got: Bool
    switch c.fn {
    case "looksWrong": got = LanguageRules.looksWrong(c.text, reader: c.reader ?? "", source: c.source, hanOnlyOk: c.hanOnlyOk ?? false)
    case "readsAs": got = LanguageRules.readsAs(c.text, c.reader ?? "")
    case "isIn": got = LanguageRules.isIn(c.text, target: c.target ?? "")
    default:
        print("::error::\(c.id): unknown fn \(c.fn)"); failed += 1; continue
    }
    if got != c.expect {
        failed += 1
        print("::error::\(c.id) [\(c.rule)] \(c.fn)(\"\(c.text)\", reader: \(c.reader ?? "-"), target: \(c.target ?? "-")) = \(got), expected \(c.expect) — \(c.why)")
    }
}
print("Language rules: \(cases.count - failed)/\(cases.count) cases pass.")
exit(failed == 0 ? 0 : 1)
