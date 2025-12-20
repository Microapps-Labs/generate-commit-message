import Foundation

#if canImport(FoundationModels)
import FoundationModels

@available(macOS 26.0, iOS 26.0, *)
@Generable
struct CommitMessage {
    @Guide(description: "Type: MUST be exactly one of these: feat, fix, docs, chore, refactor, test, perf")
    var type: String

    @Guide(description: "Scope: SHORT component name (auth, api, ui, parser) or empty string. NEVER use file paths. Max 10 chars.")
    var scope: String

    @Guide(description: "Description: what changed, imperative verb, lowercase, specific action, max 50 chars, no period")
    var description: String
}

@available(macOS 26.0, iOS 26.0, *)
extension CommitMessage {
    func format() -> String {
        if scope.isEmpty || scope.lowercased() == "none" {
            return "\(type): \(description)"
        } else {
            return "\(type)(\(scope)): \(description)"
        }
    }
}

#endif
