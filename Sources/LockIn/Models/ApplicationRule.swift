import Foundation

struct ApplicationRule: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var bundleIdentifier: String

    init(id: UUID = UUID(), name: String, bundleIdentifier: String) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
    }
}
