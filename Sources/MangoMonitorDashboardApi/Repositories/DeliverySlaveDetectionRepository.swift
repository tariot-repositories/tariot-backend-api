import PostgresNIO
import Vapor

struct DeliverySlaveDetectionRepository {
    private let pool: PostgresClient
    private let logger: Logger

    init(pool: PostgresClient, logger: Logger) {
        self.pool = pool
        self.logger = logger
    }

    // Register or refresh a detected slave for a delivery.
    func upsert(
        deliveryID: Int,
        masterID: String,
        slaveID: String,
        detectedAt: Date = Date()
    ) async throws {
        try await pool.query(
            """
            INSERT INTO delivery_slave_detection (
                id,
                delivery_id,
                master_id,
                slave_id,
                first_detected_at,
                last_detected_at,
                created_at
            )
            VALUES (
                \(UUID()),
                \(deliveryID),
                \(masterID),
                \(slaveID),
                \(detectedAt),
                \(detectedAt),
                \(detectedAt)
            )
            ON CONFLICT (delivery_id, slave_id)
            DO UPDATE SET
                master_id = EXCLUDED.master_id,
                last_detected_at = EXCLUDED.last_detected_at
            """,
            logger: logger
        )
    }

    // Get all slaves detected for a delivery.
    func findAll(
        deliveryID: Int
    ) async throws -> [DeliverySlaveDetection] {

        let rows = try await pool.query(
            """
            SELECT
                id,
                delivery_id,
                master_id,
                slave_id,
                first_detected_at,
                last_detected_at,
                created_at
            FROM delivery_slave_detection
            WHERE delivery_id = \(deliveryID)
            ORDER BY first_detected_at ASC
            """,
            logger: logger
        )

        var detections: [DeliverySlaveDetection] = []

        for try await (
            id,
            deliveryID,
            masterID,
            slaveID,
            firstDetectedAt,
            lastDetectedAt,
            createdAt
        ) in rows.decode(
            (
                UUID,
                Int,
                String,
                String,
                Date,
                Date,
                Date
            ).self
        ) {
            detections.append(
                DeliverySlaveDetection(
                    id: id,
                    deliveryID: deliveryID,
                    masterID: masterID,
                    slaveID: slaveID,
                    firstDetectedAt: firstDetectedAt,
                    lastDetectedAt: lastDetectedAt,
                    createdAt: createdAt
                )
            )
        }

        return detections
    }

    // Find a specific slave currently associated with a delivery.
    func find(
        deliveryID: Int,
        slaveID: String
    ) async throws -> DeliverySlaveDetection? {

        let rows = try await pool.query(
            """
            SELECT
                id,
                delivery_id,
                master_id,
                slave_id,
                first_detected_at,
                last_detected_at,
                created_at
            FROM delivery_slave_detection
            WHERE delivery_id = \(deliveryID)
              AND slave_id = \(slaveID)
            LIMIT 1
            """,
            logger: logger
        )

        for try await (
            id,
            deliveryID,
            masterID,
            slaveID,
            firstDetectedAt,
            lastDetectedAt,
            createdAt
        ) in rows.decode(
            (
                UUID,
                Int,
                String,
                String,
                Date,
                Date,
                Date
            ).self
        ) {
            return DeliverySlaveDetection(
                id: id,
                deliveryID: deliveryID,
                masterID: masterID,
                slaveID: slaveID,
                firstDetectedAt: firstDetectedAt,
                lastDetectedAt: lastDetectedAt,
                createdAt: createdAt
            )
        }

        return nil
    }

    func findByID(
    _ id: UUID
) async throws -> DeliverySlaveDetection? {

    let rows = try await pool.query(
        """
        SELECT
            id,
            delivery_id,
            master_id,
            slave_id,
            first_detected_at,
            last_detected_at,
            created_at
        FROM delivery_slave_detection
        WHERE id = \(id)
        LIMIT 1
        """,
        logger: logger
    )

    for try await (
        id,
        deliveryID,
        masterID,
        slaveID,
        firstDetectedAt,
        lastDetectedAt,
        createdAt
    ) in rows.decode(
        (
            UUID,
            Int,
            String,
            String,
            Date,
            Date,
            Date
        ).self
    ) {
        return DeliverySlaveDetection(
            id: id,
            deliveryID: deliveryID,
            masterID: masterID,
            slaveID: slaveID,
            firstDetectedAt: firstDetectedAt,
            lastDetectedAt: lastDetectedAt,
            createdAt: createdAt
        )
    }

    return nil
    }

    func findActive(
    masterID: String,
    slaveID: String
) async throws -> DeliverySlaveDetection? {

    let rows = try await pool.query(
        """
        SELECT
            dsd.id,
            dsd.delivery_id,
            dsd.master_id,
            dsd.slave_id,
            dsd.first_detected_at,
            dsd.last_detected_at,
            dsd.created_at
        FROM delivery_slave_detection AS dsd
        INNER JOIN deliveries AS d
            ON d.id = dsd.delivery_id
        WHERE dsd.master_id = \(masterID)
          AND dsd.slave_id = \(slaveID)
          AND d.status <> 'selesai'
        ORDER BY dsd.last_detected_at DESC
        LIMIT 1
        """,
        logger: logger
    )

    for try await (
        id,
        deliveryID,
        masterID,
        slaveID,
        firstDetectedAt,
        lastDetectedAt,
        createdAt
    ) in rows.decode(
        (
            UUID,
            Int,
            String,
            String,
            Date,
            Date,
            Date
        ).self
    ) {
        return DeliverySlaveDetection(
            id: id,
            deliveryID: deliveryID,
            masterID: masterID,
            slaveID: slaveID,
            firstDetectedAt: firstDetectedAt,
            lastDetectedAt: lastDetectedAt,
            createdAt: createdAt
        )
    }

    return nil
}
}