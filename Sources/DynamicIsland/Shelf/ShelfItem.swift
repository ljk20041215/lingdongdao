import Foundation

struct ShelfItem: Identifiable, Codable, Equatable {
    let id: UUID
    let url: URL
    let addedAt: Date
}
