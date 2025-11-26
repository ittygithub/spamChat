import Foundation


// Root response
struct EncryptResponse: Codable {
    let code: Int
    let message: String
    let encrypted: String
}

// Pagination link
struct PaginationLink: Codable {
    let url: String?
    let label: String
    let active: Bool
}

struct StatusBasic: Codable {
    let code: Int
    let message: String
}
