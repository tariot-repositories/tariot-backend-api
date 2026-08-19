import Vapor
import PostgresNIO

/// configures your application
func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    let config = PostgresClient.Configuration(
        host: Environment.get("DB_HOST") ?? "127.0.0.1",
        port: Int(Environment.get("DB_PORT") ?? "6543") ?? 6543,
        username: Environment.get("DB_USERNAME") ?? "postgres",
        password: Environment.get("DB_PASSWORD") ?? "password",
        database: Environment.get("DB_NAME") ?? "postgres",
        tls: .disable
    )

    let postgresClient = PostgresClient(
        configuration: config,
        backgroundLogger: app.logger,
    )
    app.databaseClient = DatabaseClient(pool: postgresClient)
    app.lifecycle.use(PostgresClientLifecycle(client: postgresClient))
    app.lifecycle.use(MQTTService(app: app))
    // register routes
    try routes(app)
}

private struct PostgresClientLifecycle: LifecycleHandler {
    let client: PostgresClient

    func didBoot(_ app: Application) throws {
        app.logger.info("PostgresClient pool started")
        Task{
            await client.run();
        }
    }

    func shutdown(_ app: Application) {
        app.logger.info("PostgresClient pool shutting down")
    }
}
