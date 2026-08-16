import Foundation

enum UserRole: String, Codable {
    case admin
    case driver
    case dispatcher
}

struct User {
    let id: Int
    let name: String
    let email: String
    let role: UserRole
    let createdAt: Date
}