import Foundation

struct InputSource: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let languageCode: String?
    let symbol: String

    var displayLanguageCode: String {
        languageCode?.uppercased() ?? symbol
    }
}
