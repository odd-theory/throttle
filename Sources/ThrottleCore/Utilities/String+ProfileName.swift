import Foundation

extension String {
    var normalizedProfileName: String {
        lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    var profileFileName: String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let collapsed = String(scalars)
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")
        return collapsed.isEmpty ? "profile" : collapsed
    }
}
