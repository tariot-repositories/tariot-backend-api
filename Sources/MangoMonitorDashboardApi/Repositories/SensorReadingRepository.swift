import PostgresNIO
import Vapor

import PostgresNIO
import Vapor

struct SensorReadingRepository {

    // MARK: - Properties

    private let pool: PostgresClient
    private let logger: Logger

    // MARK: - Init

    init(
        pool: PostgresClient,
        logger: Logger
    ) {
        self.pool = pool
        self.logger = logger
    }

    // MARK: - Insert

    /// Inserts a sensor reading.
    ///
    /// `truckUUID` is kept because it is still required by the
    /// current database schema and existing alert/read APIs.
    ///
    /// `deliverySlaveDetectionID` is the new relationship introduced
    /// in Phase 3.1.
    func insert(
        payload: MQTTPayloadDTO,
        truckUUID: UUID,
        deliverySlaveDetectionID: UUID?
    ) async throws -> (
        id: UUID,
        recordedAt: Date
    ) {

        let readingID = UUID()
        let recordedAt = Date()

        try await pool.query(
            """
            INSERT INTO sensor_readings (
                id,
                truck_uuid,
                delivery_slave_detection_id,
                recorded_at,
                temperature,
                humidity,
                ethylene_ppm,
                gas_raw,
                latitude,
                longitude
            )
            VALUES (
                \(readingID),
                \(truckUUID),
                \(deliverySlaveDetectionID),
                \(recordedAt),
                \(payload.temperature),
                \(payload.humidity),
                \(payload.ethylene),
                0,
                \(payload.latitude),
                \(payload.longitude)
            )
            """,
            logger: logger
        )

        return (
            id: readingID,
            recordedAt: recordedAt
        )
    }

    // MARK: - Smoothed Values by Truck
    //
    // Temporary compatibility path.
    // Phase 3.5 will move alert smoothing to
    // delivery-slave-detection scope.

    func smoothedValues(
        truckUUID: UUID,
        raw: (
            temperature: Double,
            humidity: Double,
            ethylene: Double
        )
    ) async throws -> (
        temperature: Double,
        humidity: Double,
        ethylene: Double
    ) {

        let rows = try await pool.query(
            """
            SELECT
                AVG(temperature),
                AVG(humidity),
                AVG(ethylene_ppm)
            FROM (
                SELECT
                    temperature,
                    humidity,
                    ethylene_ppm
                FROM sensor_readings
                WHERE truck_uuid = \(truckUUID)
                ORDER BY recorded_at DESC
                LIMIT 5
            ) recent
            """,
            logger: logger
        )

        for try await (
            temperature,
            humidity,
            ethylene
        ) in rows.decode(
            (
                Double?,
                Double?,
                Double?
            ).self
        ) {

            return (
                temperature:
                    temperature ?? raw.temperature,
                humidity:
                    humidity ?? raw.humidity,
                ethylene:
                    ethylene ?? raw.ethylene
            )
        }

        return raw
    }

    // MARK: - Smoothed Values by Detection

    /// New Phase 3 path.
    ///
    /// Only readings belonging to one delivery-slave detection
    /// are included in the smoothing window.
    func smoothedValues(
        deliverySlaveDetectionID: UUID,
        raw: (
            temperature: Double,
            humidity: Double,
            ethylene: Double
        )
    ) async throws -> (
        temperature: Double,
        humidity: Double,
        ethylene: Double
    ) {

        let rows = try await pool.query(
            """
            SELECT
                AVG(temperature),
                AVG(humidity),
                AVG(ethylene_ppm)
            FROM (
                SELECT
                    temperature,
                    humidity,
                    ethylene_ppm
                FROM sensor_readings
                WHERE delivery_slave_detection_id =
                    \(deliverySlaveDetectionID)
                ORDER BY recorded_at DESC
                LIMIT 5
            ) recent
            """,
            logger: logger
        )

        for try await (
            temperature,
            humidity,
            ethylene
        ) in rows.decode(
            (
                Double?,
                Double?,
                Double?
            ).self
        ) {

            return (
                temperature:
                    temperature ?? raw.temperature,
                humidity:
                    humidity ?? raw.humidity,
                ethylene:
                    ethylene ?? raw.ethylene
            )
        }

        return raw
    }

    // MARK: - Raw Readings by Truck
    //
    // Kept for the current REST API while Phase 3 migration
    // is still in progress.

    func findRaw(
        truckUUID: UUID
    ) async throws -> [SensorReading] {

        let rows = try await pool.query(
            """
            SELECT
                id,
                truck_uuid,
                delivery_slave_detection_id,
                recorded_at,
                temperature,
                humidity,
                ethylene_ppm,
                gas_raw,
                latitude,
                longitude
            FROM sensor_readings
            WHERE truck_uuid = \(truckUUID)
            ORDER BY recorded_at ASC
            """,
            logger: logger
        )

        return try await decodeReadings(
            rows
        )
    }

    // MARK: - Raw Readings by Detection

    func findRaw(
        deliverySlaveDetectionID: UUID
    ) async throws -> [SensorReading] {

        let rows = try await pool.query(
            """
            SELECT
                id,
                truck_uuid,
                delivery_slave_detection_id,
                recorded_at,
                temperature,
                humidity,
                ethylene_ppm,
                gas_raw,
                latitude,
                longitude
            FROM sensor_readings
            WHERE delivery_slave_detection_id =
                \(deliverySlaveDetectionID)
            ORDER BY recorded_at ASC
            """,
            logger: logger
        )

        return try await decodeReadings(
            rows
        )
    }

    // MARK: - Latest by Truck
    //
    // Kept for the current truck-oriented API.

    func findLatest(
        truckUUID: UUID
    ) async throws -> SensorReading? {

        let rows = try await pool.query(
            """
            SELECT
                id,
                truck_uuid,
                delivery_slave_detection_id,
                recorded_at,
                temperature,
                humidity,
                ethylene_ppm,
                gas_raw,
                latitude,
                longitude
            FROM sensor_readings
            WHERE truck_uuid = \(truckUUID)
            ORDER BY recorded_at DESC
            LIMIT 1
            """,
            logger: logger
        )

        return try await decodeFirstReading(
            rows
        )
    }

    // MARK: - Latest by Detection

    func findLatest(
        deliverySlaveDetectionID: UUID
    ) async throws -> SensorReading? {

        let rows = try await pool.query(
            """
            SELECT
                id,
                truck_uuid,
                delivery_slave_detection_id,
                recorded_at,
                temperature,
                humidity,
                ethylene_ppm,
                gas_raw,
                latitude,
                longitude
            FROM sensor_readings
            WHERE delivery_slave_detection_id =
                \(deliverySlaveDetectionID)
            ORDER BY recorded_at DESC
            LIMIT 1
            """,
            logger: logger
        )

        return try await decodeFirstReading(
            rows
        )
    }

    // MARK: - Decoding

    private func decodeReadings(
        _ rows: PostgresRowSequence
    ) async throws -> [SensorReading] {

        var readings: [SensorReading] = []

        for try await (
            id,
            truckUUID,
            detectionID,
            recordedAt,
            temperature,
            humidity,
            ethylenePPM,
            gasRaw,
            latitude,
            longitude
        ) in rows.decode(
            (
                UUID,
                UUID,
                UUID?,
                Date,
                Double,
                Double,
                Double,
                Int,
                Double,
                Double
            ).self
        ) {

            readings.append(
                SensorReading(
                    id: id,
                    truckUUID: truckUUID,
                    deliverySlaveDetectionID:
                        detectionID,
                    recordedAt: recordedAt,
                    temperature: temperature,
                    humidity: humidity,
                    ethylenePPM: ethylenePPM,
                    gasRaw: Double(gasRaw),
                    latitude: latitude,
                    longitude: longitude
                )
            )
        }

        return readings
    }

    private func decodeFirstReading(
        _ rows: PostgresRowSequence
    ) async throws -> SensorReading? {

        for try await (
            id,
            truckUUID,
            detectionID,
            recordedAt,
            temperature,
            humidity,
            ethylenePPM,
            gasRaw,
            latitude,
            longitude
        ) in rows.decode(
            (
                UUID,
                UUID,
                UUID?,
                Date,
                Double,
                Double,
                Double,
                Int,
                Double,
                Double
            ).self
        ) {

            return SensorReading(
                id: id,
                truckUUID: truckUUID,
                deliverySlaveDetectionID:
                    detectionID,
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
}