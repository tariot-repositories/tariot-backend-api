import PostgresNIO
import Vapor

struct DeliveryRepository {

    // MARK: - Properties
    private let pool: PostgresClient
    private let logger: Logger

    // MARK: - Init
    init(pool: PostgresClient, logger: Logger) {
        self.pool = pool
        self.logger = logger
    }

    // MARK: - Find All
    func findAll() async throws -> [Delivery] {
        let rows = try await pool.query(
            """
            SELECT id, truck_id, origin_location, destination_location, departure_scheduled_at,
                   driver_id, assist_driver_id, status,
                   created_by, created_at, completed_at
            FROM deliveries
            ORDER BY created_at DESC
            """,
            logger: logger
        )

        return try await decodeDeliveries(rows)
    }

    // MARK: - Find by ID
    func findByID(_ id: Int) async throws -> Delivery {
        let rows = try await pool.query(
            """
            SELECT id, truck_id, origin_location, destination_location,
                   departure_scheduled_at, driver_id, assist_driver_id, status,
                   created_by, created_at, completed_at
            FROM deliveries
            WHERE id = \(id)
            LIMIT 1
            """,
            logger: logger
        )

        let deliveries = try await decodeDeliveries(rows)

        guard let delivery = deliveries.first else {
            throw Abort(.notFound, reason: "Delivery not found")
        }

        return delivery
    }

    // MARK: - Find by Truck
    func findByTruck(truckID: UUID) async throws -> [Delivery] {
        let rows = try await pool.query(
            """
            SELECT id, truck_id, origin_location, destination_location,
                   driver_id, departure_scheduled_at, assist_driver_id, status,
                   created_by, created_at, completed_at
            FROM deliveries
            WHERE truck_id = \(truckID)
            ORDER BY created_at DESC
            """,
            logger: logger
        )

        return try await decodeDeliveries(rows)
    }

    // MARK: - Insert
    func insert(_ dto: CreateDeliveryDTO) async throws -> Delivery {
        let rows = try await pool.query(
            """
            INSERT INTO deliveries
                (truck_id, origin_location, destination_location,
                 driver_id, assist_driver_id, created_by)
            VALUES
                (\(dto.truckID), \(dto.originLocation), \(dto.destinationLocation),
                 \(dto.driverID), \(dto.assistDriverID), \(dto.createdBy))
            RETURNING id, truck_id, origin_location, destination_location,
                      driver_id, assist_driver_id, status,
                      created_by, created_at, completed_at
            """,
            logger: logger
        )

        let deliveries = try await decodeDeliveries(rows)

        guard let delivery = deliveries.first else {
            throw Abort(.internalServerError, reason: "Failed to create delivery")
        }

        return delivery
    }

    // MARK: - Update Status
    func updateStatus(id: Int, status: DeliveryStatus) async throws -> Delivery {
        let completedAt: Date? = status == .selesai ? Date() : nil

        let rows = try await pool.query(
            """
            UPDATE deliveries
            SET status = \(status.rawValue),
                completed_at = \(completedAt)
            WHERE id = \(id)
            RETURNING id, truck_id, origin_location, destination_location,
                      driver_id, assist_driver_id, status,
                      created_by, created_at, completed_at
            """,
            logger: logger
        )

        let deliveries = try await decodeDeliveries(rows)

        guard let delivery = deliveries.first else {
            throw Abort(.notFound, reason: "Delivery not found")
        }

        return delivery
    }

    func findAssignedToDriver(userID: Int) async throws -> [Delivery] {
        let rows = try await pool.query(
            """
            SELECT
            id,
            truck_id,
            origin_location,
            destination_location,
            departure_scheduled_at,
            driver_id,
            assist_driver_id,
            status,
            created_by,
            created_at,
            completed_at
            FROM deliveries
            WHERE driver_id = \(userID)
            AND status = 'menunggu_konfirmasi_supir'
            ORDER BY created_at DESC
            """,
            logger: logger
        )

        return try await decodeDeliveries(rows)
    }

    // MARK: - Private Decode Helper
    // Centralizes row decoding to avoid repetition across methods
    private func decodeDeliveries(_ rows: PostgresRowSequence) async throws -> [Delivery] {
        var deliveries: [Delivery] = []

        for try await (id, truckID, origin, destination, departureScheduledAt, driverID, assistDriverID, status, createdBy, createdAt, completedAt) in rows.decode(
            (Int, UUID, String, String, Date, Int?, Int?, String, Int, Date, Date?).self
        ) {
            guard let deliveryStatus = DeliveryStatus(rawValue: status) else { continue }

            deliveries.append(Delivery(
                id: id,
                truckID: truckID,
                originLocation: origin,
                destinationLocation: destination,
                departureScheduledAt: departureScheduledAt,
                driverID: driverID,
                assistDriverID: assistDriverID,
                status: deliveryStatus,
                createdBy: createdBy,
                createdAt: createdAt,
                completedAt: completedAt
            ))
        }

        return deliveries
    }
}