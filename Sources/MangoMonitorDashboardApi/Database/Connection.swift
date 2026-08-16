import PostgresNIO
import Vapor

struct DatabaseClient {
    let pool: PostgresClient
    
    init(pool: PostgresClient) {
        self.pool = pool
    }
}

extension Application {
    private struct DatabaseClientKey: StorageKey {
        typealias Value = DatabaseClient
    }

    var databaseClient: DatabaseClient {
        get {
            guard let client = self.storage[DatabaseClientKey.self] else {
                fatalError("DatabaseClient not configured. Please configure it in your application.")
            }
            return client
        }
        set {
            self.storage[DatabaseClientKey.self] = newValue
        }
    }
}