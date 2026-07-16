import Foundation

struct BlockRule: Identifiable, Codable, Equatable {
    var id: UUID
    var domain: String

    init(
        id: UUID = UUID(),
        domain: String
    ) {
        self.id = id
        self.domain = DomainMatcher.normalizedDomain(domain) ?? domain
    }
}
