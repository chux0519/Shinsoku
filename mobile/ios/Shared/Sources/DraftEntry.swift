import Foundation

struct DraftEntry: Equatable {
    var text: String
    var updatedAt: Date

    static let empty = DraftEntry(text: "", updatedAt: .now)
}
