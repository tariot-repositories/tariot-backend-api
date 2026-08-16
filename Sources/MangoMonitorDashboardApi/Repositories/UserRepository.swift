import PostgresNIO
import Vapor

struct UserRepository {

    // MARK: - Properties
    private let pool: PostgresClient
    private let logger: Logger

    // MARK: - Init
    init(pool: PostgresClient, logger: Logger) {
        self.pool = pool
        self.logger = logger
    }

    // MARK: - Find All
    func findAll() async throws -> [User] {
        let rows = try await pool.query(
            """
            SELECT id, name, email, role, created_at
            FROM users
            ORDER BY created_at DESC
            """,
            logger: logger
        )

        var users: [User] = []

        for try await (id, name, email, role, createdAt) in rows.decode(
            (Int, String, String, String, Date).self
        ) {
            guard let userRole = UserRole(rawValue: role) else { continue }
            users.append(User(
                id: id,
                name: name,
                email: email,
                role: userRole,
                createdAt: createdAt
            ))
        }

        return users
    }

    // MARK: - Find by ID
    func findByID(_ id: Int) async throws -> User {
        let rows = try await pool.query(
            """
            SELECT id, name, email, role, created_at
            FROM users
            WHERE id = \(id)
            LIMIT 1
            """,
            logger: logger
        )

        for try await (id, name, email, role, createdAt) in rows.decode(
            (Int, String, String, String, Date).self
        ) {
            guard let userRole = UserRole(rawValue: role) else {
                throw Abort(.internalServerError, reason: "Invalid role value in database")
            }
            return User(
                id: id,
                name: name,
                email: email,
                role: userRole,
                createdAt: createdAt
            )
        }

        throw Abort(.notFound, reason: "User not found")
    }

    // MARK: - Insert
    func insert(_ dto: CreateUserDTO) async throws -> User {
        let rows = try await pool.query(
            """
            INSERT INTO users (name, email, role)
            VALUES (\(dto.name), \(dto.email), \(dto.role.rawValue))
            RETURNING id, name, email, role, created_at
            """,
            logger: logger
        )

        for try await (id, name, email, role, createdAt) in rows.decode(
            (Int, String, String, String, Date).self
        ) {
            guard let userRole = UserRole(rawValue: role) else {
                throw Abort(.internalServerError, reason: "Invalid role value in database")
            }
            return User(
                id: id,
                name: name,
                email: email,
                role: userRole,
                createdAt: createdAt
            )
        }

        throw Abort(.internalServerError, reason: "Failed to create user")
    }
}