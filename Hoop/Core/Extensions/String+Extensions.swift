import Foundation

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var removingBidirectionalControlCharacters: String {
        String(unicodeScalars.filter { !Self.bidirectionalControlCharacterSet.contains($0) })
    }

    private static let bidirectionalControlCharacterSet = CharacterSet(
        charactersIn: "\u{061C}\u{200E}\u{200F}\u{202A}\u{202B}\u{202C}\u{202D}\u{202E}\u{2066}\u{2067}\u{2068}\u{2069}"
    )
}
