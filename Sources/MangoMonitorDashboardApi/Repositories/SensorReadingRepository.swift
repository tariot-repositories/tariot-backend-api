import PostgresNIO
import Vapor

import PostgresNIO
import Vapor

struct SensorReadingRepository {

    // MARK: - Properties
    private let pool: PostgresClient
    private let logger: Logger

    // MARK: - Init
    init(pool: PostgresClient, logger: Logger) {
        self.pool = pool
        self.logger = logger
    }

    // MARK: - Insert
    func insert(
        payload: MQTTPayloadDTO,
        truckUUID: UUID,
        deliverySlaveDetectionID: UUID?
    ) async throws -> (id: UUID, recordedAt: Date) {

        let readingID = UUID()
        let recordedAt = Date()
        let ppm = GasCalibration.ppm(fromRsRo: payload.rsRo)

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
                \(ppm),
                \(payload.latitude),
                \(payload.longitude)
            )
            """,
            logger: logger
        )

        return (id: readingID, recordedAt: recordedAt)
    }

    // MARK: - Smoothed Values by Truck
    func smoothedValues(
        truckUUID: UUID,
        raw: (temperature: Double, humidity: Double, ethylene: Double)
    ) async throws -> (temperature: Double, humidity: Double, ethylene: Double) {

        let rows = try await pool.query(
            """
            SELECT
                AVG(temperature),
                AVG(humidity),
                AVG(ethylene_ppm)
            FROM (
                SELECT temperature, humidity, ethylene_ppm
                FROM sensor_readings
                WHERE truck_uuid = \(truckUUID)
                ORDER BY recorded_at DESC
                LIMIT 5
            ) recent
            """,
            logger: logger
        )

        for try await (temperature, humidity, ethylene) in rows.decode((Double?, Double?, Double?).self) {
            return (
                temperature: temperature ?? raw.temperature,
                humidity: humidity ?? raw.humidity,
                ethylene: ethylene ?? raw.ethylene
            )
        }

        return raw
    }

    // MARK: - Smoothed Values by Detection
    func smoothedValues(
        deliverySlaveDetectionID: UUID,
        raw: (temperature: Double, humidity: Double, ethylene: Double)
    ) async throws -> (temperature: Double, humidity: Double, ethylene: Double) {

        let rows = try await pool.query(
            """
            SELECT
                AVG(temperature),
                AVG(humidity),
                AVG(ethylene_ppm)
            FROM (
                SELECT temperature, humidity, ethylene_ppm
                FROM sensor_readings
                WHERE delivery_slave_detection_id = \(deliverySlaveDetectionID)
                ORDER BY recorded_at DESC
                LIMIT 5
            ) recent
            """,
            logger: logger
        )

        for try await (temperature, humidity, ethylene) in rows.decode((Double?, Double?, Double?).self) {
            return (
                temperature: temperature ?? raw.temperature,
                humidity: humidity ?? raw.humidity,
                ethylene: ethylene ?? raw.ethylene
            )
        }

        return raw
    }

    // MARK: - Raw Readings by Truck
    func findRaw(truckUUID: UUID) async throws -> [SensorReading] {
        let rows = try await pool.query(
            """
            SELECT
            sr.id,
            sr.truck_uuid,
            sr.delivery_slave_detection_id,
            dsd.master_id,
            dsd.slave_id,
            sr.recorded_at,
            sr.temperature,
            sr.humidity,
            sr.ethylene_ppm,
            sr.latitude,
            sr.longitude
            FROM sensor_readings sr
            JOIN delivery_slave_detection dsd
                ON dsd.id = sr.delivery_slave_detection_id
            WHERE sr.truck_uuid = \(truckUUID)
            ORDER BY sr.recorded_at ASC
            """,
            logger: logger
        )

        return try await decodeReadings(rows)
    }

    // MARK: - Raw Readings by Detection
    func findRaw(deliverySlaveDetectionID: UUID) async throws -> [SensorReading] {
        let rows = try await pool.query(
            """
            SELECT
            sr.id,
            sr.truck_uuid,
            sr.delivery_slave_detection_id,
            dsd.master_id,
            dsd.slave_id,
            sr.recorded_at,
            sr.temperature,
            sr.humidity,
            sr.ethylene_ppm,
            sr.latitude,
            sr.longitude
            FROM sensor_readings sr
            JOIN delivery_slave_detection dsd
                ON dsd.id = sr.delivery_slave_detection_id
            WHERE sr.delivery_slave_detection_id = \(deliverySlaveDetectionID)
            ORDER BY sr.recorded_at ASC
            """,
            logger: logger
        )

        return try await decodeReadings(rows)
    }

    // MARK: - Latest by Truck
    func findLatest(truckUUID: UUID) async throws -> SensorReading? {
        let rows = try await pool.query(
            """
            SELECT
                id, truck_uuid, delivery_slave_detection_id, recorded_at,
                temperature, humidity, ethylene_ppm, latitude, longitude
            FROM sensor_readings
            WHERE truck_uuid = \(truckUUID)
            ORDER BY recorded_at DESC
            LIMIT 1
            """,
            logger: logger
        )

        return try await decodeFirstReading(rows)
    }

    // MARK: - Latest by Detection
    func findLatest(deliverySlaveDetectionID: UUID) async throws -> SensorReading? {
        let rows = try await pool.query(
            """
            SELECT
                id, truck_uuid, delivery_slave_detection_id, recorded_at,
                temperature, humidity, ethylene_ppm, latitude, longitude
            FROM sensor_readings
            WHERE delivery_slave_detection_id = \(deliverySlaveDetectionID)
            ORDER BY recorded_at DESC
            LIMIT 1
            """,
            logger: logger
        )

        return try await decodeFirstReading(rows)
    }

    // MARK: - Decoding
    private func decodeReadings(_ rows: PostgresRowSequence) async throws -> [SensorReading] {
        var readings: [SensorReading] = []

        for try await (id, truckUUID, detectionID, masterID, slaveID, recordedAt, temperature, humidity, ethylenePPM, latitude, longitude) in rows.decode(
            (UUID, UUID, UUID?, String, String, Date, Double, Double, Double, Double?, Double?).self
        ) {
            readings.append(SensorReading(
                id: id,
                truckUUID: truckUUID,
                masterID: masterID,
                slaveID: slaveID,
                deliverySlaveDetectionID: detectionID,
                recordedAt: recordedAt,
                temperature: temperature,
                humidity: humidity,
                ethylenePPM: ethylenePPM,
                latitude: latitude,
                longitude: longitude
            ))
        }

        return readings
    }

    private func decodeFirstReading(_ rows: PostgresRowSequence) async throws -> SensorReading? {
        for try await (id, truckUUID, detectionID, masterID, slaveID, recordedAt, temperature, humidity, ethylenePPM, latitude, longitude) in rows.decode(
            (UUID, UUID, UUID?, String, String, Date, Double, Double, Double, Double?, Double?).self
        ) {
            return SensorReading(
                id: id,
                truckUUID: truckUUID,
                masterID: masterID,
                slaveID: slaveID,
                deliverySlaveDetectionID: detectionID,
                recordedAt: recordedAt,
                temperature: temperature,
                humidity: humidity,
                ethylenePPM: ethylenePPM,
                latitude: latitude,
                longitude: longitude
            )
        }

        return nil
    }
}