import PostgresNIO
import Vapor

struct AlertRepository {
    private let pool: PostgresClient
    private let logger: Logger

    init(pool: PostgresClient, logger: Logger) {
        self.pool = pool
        self.logger = logger
    }

    func insert(
        truckUUID: UUID,
        readingID: UUID,
        recordedAt: Date,
        parameter: AlertParameter,
        severity: AlertSeverity,
        value: Double,
        message: String
    ) async throws {
        try await pool.query(
            """
            INSERT INTO alerts
                (id, truck_uuid, reading_id, reading_recorded_at,
                 parameter, severity, value_at_trigger, message, created_at)
            VALUES
                (\(UUID()), \(truckUUID), \(readingID), \(recordedAt),
                 \(parameter.rawValue)::alert_parameter, \(severity.rawValue)::alert_severity,
                 \(value), \(message), \(Date()))
            """,
            logger: logger
        )
    }

    // MARK: - Find Last Alert
    // Used for cooldown check — returns the most recent alert
    // for a specific truck + parameter combination
    func findLast(
        truckUUID: UUID,
        parameter: AlertParameter
    ) async throws -> (severity: AlertSeverity, createdAt: Date)? {

        let rows = try await pool.query(
            """
            SELECT severity, created_at
            FROM alerts
            WHERE truck_uuid = \(truckUUID)
            AND parameter = \(parameter.rawValue)::alert_parameter
            ORDER BY created_at DESC
            LIMIT 1
            """,
            logger: logger
        )

        for try await (severity, createdAt) in rows.decode((String, Date).self) {
            guard let alertSeverity = AlertSeverity(rawValue: severity) else {
                return nil
            }
            return (severity: alertSeverity, createdAt: createdAt)
        }

        return nil
    }

    // MARK: - Find All by Truck
    func findAll(truckUUID: UUID) async throws -> [Alert] {
        let rows = try await pool.query(
            """
            SELECT id, truck_uuid, reading_id, reading_recorded_at,
                   parameter, severity, value_at_trigger, message, created_at
            FROM alerts
            WHERE truck_uuid = \(truckUUID)
            ORDER BY created_at DESC
            """,
            logger: logger
        )

        var alerts: [Alert] = []

        for try await (id, tUUID, readingID, readingRecordedAt, parameter, severity, valueAtTrigger, message, createdAt) in rows.decode(
            (UUID, UUID, UUID, Date, String, String, Double, String, Date).self
        ) {
            guard
                let alertParameter = AlertParameter(rawValue: parameter),
                let alertSeverity = AlertSeverity(rawValue: severity)
            else { continue }

            alerts.append(Alert(
                id: id,
                truckUUID: tUUID,
                readingID: readingID,
                readingRecordedAt: readingRecordedAt,
                parameter: alertParameter,
                severity: alertSeverity,
                valueAtTrigger: valueAtTrigger,
                message: message,
                createdAt: createdAt
            ))
        }

        return alerts
    }

    // MARK: - Find All Active (across all trucks)
    func findAllActive() async throws -> [Alert] {
        let rows = try await pool.query(
            """
            SELECT id, truck_uuid, reading_id, reading_recorded_at,
                   parameter, severity, value_at_trigger, message, created_at
            FROM alerts
            ORDER BY created_at DESC
            """,
            logger: logger
        )

        var alerts: [Alert] = []

        for try await (id, tUUID, readingID, readingRecordedAt, parameter, severity, valueAtTrigger, message, createdAt) in rows.decode(
            (UUID, UUID, UUID, Date, String, String, Double, String, Date).self
        ) {
            guard
                let alertParameter = AlertParameter(rawValue: parameter),
                let alertSeverity = AlertSeverity(rawValue: severity)
            else { continue }

            alerts.append(Alert(
                id: id,
                truckUUID: tUUID,
                readingID: readingID,
                readingRecordedAt: readingRecordedAt,
                parameter: alertParameter,
                severity: alertSeverity,
                valueAtTrigger: valueAtTrigger,
                message: message,
                createdAt: createdAt
            ))
        }

        return alerts
    }
}