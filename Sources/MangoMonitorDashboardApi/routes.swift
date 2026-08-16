import Vapor

func routes(_ app: Application) throws {
     let sensorReadingController = SensorReadingController()
     let userController = UserController(
        userRepository: UserRepository(
            pool: app.databaseClient.pool,
            logger: app.logger
        )
    )
    let deliverySlaveDetectionController =
    DeliverySlaveDetectionController(
        deliveryRepository: DeliveryRepository(
            pool: app.databaseClient.pool,
            logger: app.logger
        ),
        detectionRepository: DeliverySlaveDetectionRepository(
            pool: app.databaseClient.pool,
            logger: app.logger
        )
    )

    let deliveryController = DeliveryController(
        deliveryRepository: DeliveryRepository(
            pool: app.databaseClient.pool,
            logger: app.logger
        ),
        userRepository: UserRepository(
            pool: app.databaseClient.pool,
            logger: app.logger
        ),
        deliverySlaveDetectionRepository: DeliverySlaveDetectionRepository(
            pool: app.databaseClient.pool,
            logger: app.logger
        )
    )

    let alertController = AlertController(
    alertRepository: AlertRepository(
        pool: app.databaseClient.pool,
        logger: app.logger
        )
    )

     let truckController = TruckController(
        truckRepository: TruckRepository(pool: app.databaseClient.pool, logger: app.logger),
        sensorReadingRepository: SensorReadingRepository(pool: app.databaseClient.pool, logger: app.logger),
        alertRepository: AlertRepository(pool: app.databaseClient.pool, logger: app.logger)
     )
    let api = app.grouped("api")

    app.get { req async in
        "It works!"
    }

    app.get("health") { req async -> HTTPStatus in
        .ok
    }

    app.get("hello", ":name") { req async -> String in
        let name = req.parameters.get("name") ?? "Anonymous"
        return "Hello, \(name)!"
    }

    // MARK: - User Routes

    try api.register(collection: userController)

    // MARK: - Delivery Routes
    try api.register(collection: deliveryController)
    try api.register(collection: deliverySlaveDetectionController)

    // MARK: - Alert Routes
    try api.register(collection: alertController)

    // truck routes
    let trucks = api.grouped("trucks")
    trucks.get(use: truckController.index)

    // sensor reading routes
    let readings = trucks.grouped(":truckID", "readings")
    readings.get("latest", use: sensorReadingController.latest)
    readings.get("raw", use: sensorReadingController.raw)
    let slaveDetectionReadings =
    api.grouped("slave-detection-readings")
    slaveDetectionReadings.get(
        ":detectionID",
        use: sensorReadingController.rawByDetection
    )
    slaveDetectionReadings.get(
    ":detectionID",
    "latest",
    use: sensorReadingController.latestByDetection
)
}
