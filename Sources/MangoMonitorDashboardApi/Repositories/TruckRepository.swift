import PostgresNIO
import Vapor
struct TruckRepository {

    // MARK: - Properties
    private let pool: PostgresClient
    private let logger: Logger

    // MARK: - Init
    init(pool: PostgresClient, logger: Logger) {
        self.pool = pool
        self.logger = logger
    }

    func findAllActive() async throws -> [Truck] {
    let rows = try await pool.query(
        """
        SELECT id, truck_id, name, is_active, created_at, updated_at
        FROM trucks
        WHERE is_active = true
        ORDER BY created_at DESC
        """,
        logger: logger
    )

    var trucks: [Truck] = []

    for try await (id, truckID, name, isActive, createdAt, updatedAt) in rows.decode(
        (UUID, String, String?, Bool, Date, Date).self
    ) {
        trucks.append(Truck(
            id: id,
            truckId: truckID,
            name: name,
            isActive: isActive,
            createdAt: createdAt,
            updatedAt: updatedAt
        ))
    }

    return trucks
}


    // MARK: - Find by truck_id string
    func findByTruckID(_ truckID: String) async throws -> UUID {
        let rows = try await pool.query(
            """
            SELECT id FROM trucks
            WHERE truck_id = \(truckID)
            AND is_active = true
            LIMIT 1
            """,
            logger: logger
        )

        for try await (id) in rows.decode(UUID.self) {
            return id
        }

        throw Abort(.badRequest, reason: "Unknown truck_id '\(truckID)'. Register the truck first.")
    }
    func findLatest(truckUUID: UUID) async throws -> SensorReading? {
    let rows = try await pool.query(
        """
        SELECT id, truck_uuid, recorded_at, temperature, humidity,
               ethylene_ppm, gas_raw, latitude, longitude
        FROM sensor_readings
        WHERE truck_uuid = \(truckUUID)
        ORDER BY recorded_at DESC
        LIMIT 1
        """,
        logger: logger
    )

    for try await (id, tUUID, recordedAt, temperature, humidity, ethylenePPM, gasRaw, latitude, longitude) in rows.decode(
        (UUID, UUID, Date, Double, Double, Double, Int, Double, Double).self
    ) {
        return SensorReading(
            id: id,
            truckUUID: tUUID,
            deliverySlaveDetectionID: nil,
            recordedAt: recordedAt,
            temperature: temperature,
            humidity: humidity,
            ethylenePPM: ethylenePPM,
            gasRaw: Double(gasRaw),
            latitude: latitude,
            longitude: longitude
        )
    }

    return nil
}
func findByUUID(_ id: String) async throws -> Truck {
    guard let uuid = UUID(uuidString: id) else {
        throw Abort(.badRequest, reason: "Invalid truck UUID format")
    }

    let rows = try await pool.query(
        """
        SELECT id, truck_id, name, is_active, created_at, updated_at
        FROM trucks
        WHERE id = \(uuid)
        AND is_active = true
        LIMIT 1
        """,
        logger: logger
    )

    for try await (id, truckID, name, isActive, createdAt, updatedAt) in rows.decode(
        (UUID, String, String?, Bool, Date, Date).self
    ) {
        return Truck(
            id: id,
            truckId: truckID,
            name: name,
            isActive: isActive,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    throw Abort(.notFound, reason: "Truck not found")
}
}