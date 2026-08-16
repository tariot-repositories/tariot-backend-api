import Vapor

struct UserController: RouteCollection {
    private let userRepository: UserRepository

    init(userRepository: UserRepository) {
        self.userRepository = userRepository
    }

    func boot(routes: any RoutesBuilder) throws {
        let users = routes.grouped("users")

        users.get(use: index)
        users.post(use: create)

        users.get(":id", use: show)
    }

    // MARK: - GET /users

    func index(req: Request) async throws -> [UserDTO] {
        let users = try await userRepository.findAll()

        return users.map { user in
            UserDTO(
                id: user.id,
                name: user.name,
                email: user.email,
                role: user.role,
                createdAt: user.createdAt.description
            )
        }
    }

    // MARK: - GET /users/:id

    func show(req: Request) async throws -> UserDTO {
        guard let id = req.parameters.get("id", as: Int.self) else {
            throw Abort(.badRequest, reason: "Invalid user ID")
        }

        let user = try await userRepository.findByID(id)

        return UserDTO(
            id: user.id,
            name: user.name,
            email: user.email,
            role: user.role,
            createdAt: user.createdAt.description
        )
    }

    // MARK: - POST /users

    func create(req: Request) async throws -> UserDTO {
        let dto = try req.content.decode(CreateUserDTO.self)

        let user = try await userRepository.insert(dto)

        return UserDTO(
            id: user.id,
            name: user.name,
            email: user.email,
            role: user.role,
            createdAt: user.createdAt.description
        )
    }
}