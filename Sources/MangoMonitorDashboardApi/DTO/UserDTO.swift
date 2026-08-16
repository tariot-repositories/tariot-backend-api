import Vapor

struct UserDTO: Content {
    let id: Int
    let name: String
    let email: String
    let role: UserRole
    let createdAt: String
}

struct CreateUserDTO: Content {
    let name: String
    let email: String
    let role: UserRole
}