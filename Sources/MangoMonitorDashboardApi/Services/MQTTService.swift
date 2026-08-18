import Vapor
import MQTTNIO
import PostgresNIO
import NIOCore

struct MQTTService: LifecycleHandler {

    // MARK: - Properties
    private let client: MQTTClient
    private let logger: Logger
    private let databaseClient: DatabaseClient
    private let truckRepository: TruckRepository
    private let sensorReadingRepository: SensorReadingRepository
    private let alertRepository: AlertRepository
    private let deliveryRepository: DeliveryRepository
    private let deliverySlaveDetectionRepository: DeliverySlaveDetectionRepository

    // MARK: - Init
    init(app: Application) {
        self.logger = app.logger
        self.databaseClient = app.databaseClient
        self.truckRepository = TruckRepository(pool: app.databaseClient.pool, logger: app.logger)
        self.sensorReadingRepository = SensorReadingRepository(pool: app.databaseClient.pool, logger: app.logger)
        self.alertRepository = AlertRepository(pool: app.databaseClient.pool, logger: app.logger)
        self.deliveryRepository =  DeliveryRepository(pool: app.databaseClient.pool, logger: app.logger)
        self.deliverySlaveDetectionRepository = DeliverySlaveDetectionRepository(pool: app.databaseClient.pool, logger: app.logger)

        self.client = MQTTClient(
            configuration: .init(
                target: .host(
                    Environment.get("MQTT_HOST") ?? "broker.mqttdashboard.com",
                    port: Int(Environment.get("MQTT_PORT") ?? "1883") ?? 1883
                ),
                credentials: .init(
                    username: Environment.get("MQTT_USERNAME") ?? "",
                    password: Environment.get("MQTT_PASSWORD") ?? ""
                ),
            ),
            eventLoopGroupProvider: .shared(app.eventLoopGroup)
        )       
    }

    // MARK: - Alert Evaluation
    private func evaluateAlerts(
    payload: MQTTPayloadDTO,
    truckUUID: UUID,
    deliverySlaveDetectionID: UUID,
    readingID: UUID,
    recordedAt: Date
    ) async {
    do {
        // Step 1 — smooth the latest readings belonging
        // to this delivery/slave detection.
        let smoothed =
            try await sensorReadingRepository
                .smoothedValues(
                    deliverySlaveDetectionID:
                        deliverySlaveDetectionID,
                    raw: (
                        temperature:
                            payload.temperature,
                        humidity:
                            payload.humidity,
                        ethylene:
                            payload.ethylene
                    )
                )

        // Step 2 — evaluate temperature
        // and ethylene only.
        var breaches: [
            (
                parameter: AlertParameter,
                severity: AlertSeverity,
                value: Double,
                message: String
            )
        ] = []

        // MARK: Temperature

        if smoothed.temperature > 15.0 {

            breaches.append(
                (
                    parameter: .temperature,
                    severity: .critical,
                    value: smoothed.temperature,
                    message:
                        "Critical: suhu " +
                        "\(String(format: "%.1f", smoothed.temperature))°C " +
                        "melebihi batas maksimum 15°C"
                )
            )

        } else if
            smoothed.temperature > 13.0 ||
            smoothed.temperature < 8.0 {

            breaches.append(
                (
                    parameter: .temperature,
                    severity: .warning,
                    value: smoothed.temperature,
                    message:
                        "Warning: suhu " +
                        "\(String(format: "%.1f", smoothed.temperature))°C " +
                        "di luar rentang optimal 8–13°C"
                )
            )
        }

        // MARK: Ethylene

        if smoothed.ethylene > 100.0 {

            breaches.append(
                (
                    parameter: .ethylene,
                    severity: .critical,
                    value: smoothed.ethylene,
                    message:
                        "Critical: etilen " +
                        "\(String(format: "%.1f", smoothed.ethylene))ppm " +
                        "— pematangan aktif terdeteksi, " +
                        "tindakan segera diperlukan"
                )
            )

        } else if
            smoothed.ethylene > 50.0 {

            breaches.append(
                (
                    parameter: .ethylene,
                    severity: .warning,
                    value: smoothed.ethylene,
                    message:
                        "Warning: etilen " +
                        "\(String(format: "%.1f", smoothed.ethylene))ppm " +
                        "— awal pematangan terdeteksi"
                )
            )
        }

        // Step 3 — cooldown + severity escalation
        for breach in breaches {

            let shouldFire =
                try await shouldFireAlert(
                    truckUUID: truckUUID,
                    parameter: breach.parameter,
                    incomingSeverity: breach.severity
                )

            guard shouldFire else {
                logger.info("Alert suppressed by cooldown — \(breach.parameter.rawValue) for truck \(truckUUID)")
                continue
            }

            try await alertRepository.insert(
                truckUUID: truckUUID,
                readingID: readingID,
                recordedAt: recordedAt,
                parameter: breach.parameter,
                severity: breach.severity,
                value: breach.value,
                message: breach.message
            )

            logger.warning("Alert suppressed by cooldown — \(breach.parameter.rawValue) for truck \(truckUUID)")
        }
    } catch {
        logger.error("evaluateAlerts failed: \(String(reflecting: error))")
    }
    }

// MARK: - Cooldown Check
private func shouldFireAlert(
    truckUUID: UUID,
    parameter: AlertParameter,
    incomingSeverity: AlertSeverity
) async throws -> Bool {

    // Fetch last alert for this truck + parameter
    guard let last = try await alertRepository.findLast(
        truckUUID: truckUUID,
        parameter: parameter
    ) else {
        // No previous alert — always fire
        return true
    }

    // Severity escalation — fire immediately if incoming is higher
    if last.severity == .warning && incomingSeverity == .critical {
        return true
    }

    // Cooldown check
    let cooldownMinutes = Double(Environment.get("ALERT_COOLDOWN_MINUTES").flatMap(Int.init) ?? 10)
    let cooldownSeconds = cooldownMinutes * 60
    let elapsed = Date().timeIntervalSince(last.createdAt)

    return elapsed >= cooldownSeconds
}

    // MARK: - Lifecycle
    func didBoot(_ app: Application) throws {
        logger.info("MQTTService booting — connecting to broker...")
        Task {
            await run()
        }
    }

    func shutdown(_ app: Application) {
        logger.info("MQTTService shutting down...")
    }

    // MARK: - Core Loop
    private func run() async {
        do {
            try await client.connect()
            logger.info("MQTTService connected to broker")

            try await client.subscribe(to: [
                .init(topicFilter: "mango-monitor", qos: .atLeastOnce)
            ])
            logger.info("MQTTService subscribed to topic: mango-monitor")

            // Listen for incoming messages indefinitely
            for await message in client.messages {
                await handleMessage(message)
            }

        } catch {
            logger.error("MQTTService error: \(error.localizedDescription)")
        }
    }

    // MARK: - Message Handler
    private func handleMessage(_ message: MQTTMessage) async {
        guard let raw = message.payload.string else {
            logger.warning("MQTTService received non-string payload — skipping")
            return
        }

        guard let data = raw.data(using: .utf8) else {
            logger.warning("MQTTService could not convert payload to Data — skipping")
            return
        }

        do {
            let payload = try JSONDecoder().decode(MQTTPayloadDTO.self, from: data)
            logger.info("MQTTService received payload from master \(payload.masterID): \(payload.slaveID)")
            try await process(payload: payload)
        } catch {
            logger.error("MQTTService failed to decode payload: \(error.localizedDescription)")
        }
    }

    // MARK: - Payload Processor
    private func process(payload: MQTTPayloadDTO) async throws {
        guard let detection =
        try await deliverySlaveDetectionRepository.findActive(
            masterID: payload.masterID,
            slaveID: payload.slaveID
        )
    else {
        logger.warning(
            "MQTT reading ignored — no active delivery detection found for master \(payload.masterID), slave \(payload.slaveID)"
        )
        return
    }

    // 2. Resolve the truck from the delivery.
    let delivery =
        try await deliveryRepository.findByID(
            detection.deliveryID
        )
        

    let truckUUID =
        delivery.truckID

    // 3. Store the sensor reading with the
    //    delivery-slave detection relationship.
    let reading = try await sensorReadingRepository.insert(
            payload: payload,
            truckUUID: truckUUID,
            deliverySlaveDetectionID:
            detection.id
        )
        await evaluateAlerts(
            payload: payload,
            truckUUID: truckUUID,
            deliverySlaveDetectionID: detection.id,
            readingID: reading.id,
            recordedAt: reading.recordedAt
        )

    logger.info(
        "MQTTService stored reading \(reading.id) for delivery \(detection.deliveryID), slave \(payload.slaveID)"
    )
    }
}