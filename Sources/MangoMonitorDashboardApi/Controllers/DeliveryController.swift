import Vapor

struct DeliveryController: RouteCollection {
    private let deliveryRepository: DeliveryRepository
    private let userRepository: UserRepository
    private let deliverySlaveDetectionRepository: DeliverySlaveDetectionRepository

    init(
        deliveryRepository: DeliveryRepository,
        userRepository: UserRepository,
        deliverySlaveDetectionRepository: DeliverySlaveDetectionRepository
    ) {
        self.deliveryRepository = deliveryRepository
        self.userRepository = userRepository
        self.deliverySlaveDetectionRepository = deliverySlaveDetectionRepository
    }

    func boot(routes: any RoutesBuilder) throws {
        let deliveries = routes.grouped("deliveries")

        deliveries.get(use: index)
        deliveries.post(use: create)

        deliveries.get(":id", use: show)
        deliveries.patch(":id", "status", use: updateStatus)

        deliveries.get("truck", ":truckID", use: findByTruck)
        deliveries.get("assigned",":userID", use: assigned)
    }

    // MARK: - GET /deliveries

    func index(req: Request) async throws -> [DeliveryDTO] {
        let deliveries = try await deliveryRepository.findAll()
        var result: [DeliveryDTO] = []
        result.reserveCapacity(deliveries.count)

        for delivery in deliveries {
            let dto = try await makeDTO(from: delivery)
            result.append(dto)
        }
        return result
    }

    // MARK: - GET /deliveries/:id

    func show(req: Request) async throws -> DeliveryDetailDTO {
        guard let id = req.parameters.get("id", as: Int.self) else {
            throw Abort(.badRequest, reason: "Invalid delivery ID")
        }

         let delivery =
        try await deliveryRepository.findByID(id)

    let detections =
        try await deliverySlaveDetectionRepository.findAll(
            deliveryID: id
        )

    let driver: UserDTO?

    if let driverID = delivery.driverID {
        let user =
            try await userRepository.findByID(
                driverID
            )

        driver = UserDTO(
            id: user.id,
            name: user.name,
            email: user.email,
            role: user.role,
            createdAt:
                user.createdAt.description
        )
    } else {
        driver = nil
    }

    let assistDriver: UserDTO?

    if let assistDriverID =
        delivery.assistDriverID {

        let user =
            try await userRepository.findByID(
                assistDriverID
            )

        assistDriver = UserDTO(
            id: user.id,
            name: user.name,
            email: user.email,
            role: user.role,
            createdAt:
                user.createdAt.description
        )
    } else {
        assistDriver = nil
    }

    let detectedSlaves =
        detections.map { detection in

            DeliverySlaveDetectionDTO(
                id: detection.id,
                masterID:
                    detection.masterID,
                slaveID:
                    detection.slaveID,
                firstDetectedAt:
                    detection
                        .firstDetectedAt
                        .description,
                lastDetectedAt:
                    detection
                        .lastDetectedAt
                        .description
            )
        }

    return DeliveryDetailDTO(
        id: delivery.id,
        truckID: delivery.truckID,
        originLocation:
            delivery.originLocation,
        destinationLocation:
            delivery.destinationLocation,
        departureScheduledAt:
            delivery
                .departureScheduledAt
                .description,
        driver: driver,
        assistDriver: assistDriver,
        status: delivery.status,
        createdBy: delivery.createdBy,
        createdAt:
            delivery.createdAt.description,
        completedAt:
            delivery.completedAt?.description,
        detectedSlaves:
            detectedSlaves,
        crateCount:
            detections.count
    )
    }

    // MARK: - GET /deliveries/truck/:truckID

    func findByTruck(req: Request) async throws -> [DeliveryDTO] {
        guard let truckID = req.parameters.get("truckID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid truck ID")
        }

        let deliveries = try await deliveryRepository.findByTruck(truckID: truckID)

        var result: [DeliveryDTO] = []
        result.reserveCapacity(deliveries.count)

        for delivery in deliveries {
            let dto = try await makeDTO(from: delivery)
            result.append(dto)
        }

        return result
    }

    // MARK: - POST /deliveries

    func create(req: Request) async throws -> DeliveryDTO {
        let dto = try req.content.decode(CreateDeliveryDTO.self)

        let delivery = try await deliveryRepository.insert(dto)

        return try await makeDTO(from: delivery)
    }

    // MARK: - PATCH /deliveries/:id/status

    func updateStatus(req: Request) async throws -> DeliveryDTO {
        guard let id = req.parameters.get("id", as: Int.self) else {
            throw Abort(.badRequest, reason: "Invalid delivery ID")
        }

        let dto = try req.content.decode(UpdateDeliveryStatusDTO.self)

        let delivery = try await deliveryRepository.updateStatus(
            id: id,
            status: dto.status
        )

        return try await makeDTO(from: delivery)
    }

    func assigned(req: Request) async throws -> [DriverDeliveryDTO] {
        guard let userID = req.parameters.get("userID", as: Int.self) else {
            throw Abort(
                .badRequest,
                reason: "Missing or invalid user_id query parameter"
            )
        }

        let deliveries = try await deliveryRepository.findAssignedToDriver(
        userID: userID
    )

    return deliveries.map { delivery in
        DriverDeliveryDTO(
            id: delivery.id,
            truckID: delivery.truckID,
            originLocation: delivery.originLocation,
            destinationLocation: delivery.destinationLocation,
            departureScheduledAt: Int64(
                delivery.departureScheduledAt.timeIntervalSince1970
            ),
            status: delivery.status,
            createdAt: Int64(
                delivery.createdAt.timeIntervalSince1970
            ),
            completedAt: delivery.completedAt.map {
                Int64($0.timeIntervalSince1970)
            },
            createdBy: delivery.createdBy
        )
    }
    }

    // MARK: - Private DTO Mapping

    private func makeDTO(from delivery: Delivery) async throws -> DeliveryDTO {
        let driver: UserDTO?

        if let driverID = delivery.driverID {
            let user = try await userRepository.findByID(driverID)

            driver = UserDTO(
                id: user.id,
                name: user.name,
                email: user.email,
                role: user.role,
                createdAt: user.createdAt.description
            )
        } else {
            driver = nil
        }

        let assistDriver: UserDTO?

        if let assistDriverID = delivery.assistDriverID {
            let user = try await userRepository.findByID(assistDriverID)

            assistDriver = UserDTO(
                id: user.id,
                name: user.name,
                email: user.email,
                role: user.role,
                createdAt: user.createdAt.description
            )
        } else {
            assistDriver = nil
        }

        return DeliveryDTO(
            id: delivery.id,
            truckID: delivery.truckID,
            originLocation: delivery.originLocation,
            destinationLocation: delivery.destinationLocation,
            departureScheduledAt: delivery.departureScheduledAt.description,
            driver: driver,
            assistDriver: assistDriver,
            status: delivery.status,
            createdBy: delivery.createdBy,
            createdAt: delivery.createdAt.description,
            completedAt: delivery.completedAt?.description
        )
    }
    private func makeDetailDTO(
    from delivery: Delivery,
    detections: [DeliverySlaveDetection]
    ) async throws -> DeliveryDetailDTO {

    let base = try await makeDTO(
        from: delivery
    )

    let detectedSlaves =
        detections.map {
            DeliverySlaveDetectionDTO(
                id: $0.id,
                masterID: $0.masterID,
                slaveID: $0.slaveID,
                firstDetectedAt:
                    $0.firstDetectedAt.description,
                lastDetectedAt:
                    $0.lastDetectedAt.description
            )
        }

    return DeliveryDetailDTO(
        id: base.id,
        truckID: base.truckID,
        originLocation:
            base.originLocation,
        destinationLocation:
            base.destinationLocation,
        departureScheduledAt:
            base.departureScheduledAt,
        driver:
            base.driver,
        assistDriver:
            base.assistDriver,
        status:
            base.status,
        createdBy:
            base.createdBy,
        createdAt:
            base.createdAt,
        completedAt:
            base.completedAt,
        detectedSlaves:
            detectedSlaves,
        crateCount:
            detectedSlaves.count
    )
}
}