import Vapor

struct DeliverySlaveDetectionController: RouteCollection {

    private let deliveryRepository: DeliveryRepository
    private let detectionRepository: DeliverySlaveDetectionRepository

    init(
        deliveryRepository: DeliveryRepository,
        detectionRepository: DeliverySlaveDetectionRepository
    ) {
        self.deliveryRepository = deliveryRepository
        self.detectionRepository = detectionRepository
    }

    func boot(routes: any RoutesBuilder) throws {
        let detections =
            routes.grouped(
                "delivery-slave-detections"
            )

        detections.post(use: create)
        detections.get(":deliveryID", use: index)
    }

    // MARK: - POST /delivery-slave-detections

    func create(
        req: Request
    ) async throws -> DetectSlavesResponseDTO {

        let payload =
            try req.content.decode(
                DetectSlavesDTO.self
            )

        // 1. Verify that the delivery exists.
        _ = try await deliveryRepository.findByID(
            payload.deliveryID
        )

        guard !payload.slaveDetected.isEmpty else {
            throw Abort(
                .badRequest,
                reason:
                    "slave_detected must not be empty"
            )
        }

        // 2. Register / refresh every detected slave.
        for detectedSlave
            in payload.slaveDetected {

            let detectedAt =
                Date(
                    timeIntervalSince1970:
                        TimeInterval(
                            detectedSlave.timestamp
                        )
                )

            try await detectionRepository.upsert(
                deliveryID:
                    payload.deliveryID,
                masterID:
                    payload.masterCode,
                slaveID:
                    detectedSlave.slaveCode,
                detectedAt:
                    detectedAt
            )
        }

        // 3. Return the current detection state
        //    for this delivery.
        let detections =
            try await detectionRepository.findAll(
                deliveryID:
                    payload.deliveryID
            )

        return DetectSlavesResponseDTO(
            deliveryID:
                payload.deliveryID,
            masterCode:
                payload.masterCode,
            slaveCount:
                detections.count,
            slaves:
                detections
        )
    }

    // MARK: - GET /delivery-slave-detections/:deliveryID

    func index(
        req: Request
    ) async throws -> DetectSlavesResponseDTO {

        guard let deliveryID =
            req.parameters.get(
                "deliveryID",
                as: Int.self
            )
        else {
            throw Abort(
                .badRequest,
                reason:
                    "Invalid delivery ID"
            )
        }

        _ = try await deliveryRepository.findByID(
            deliveryID
        )

        let detections =
            try await detectionRepository.findAll(
                deliveryID:
                    deliveryID
            )

        let masterCode =
            detections.first?.masterID ?? ""

        return DetectSlavesResponseDTO(
            deliveryID:
                deliveryID,
            masterCode:
                masterCode,
            slaveCount:
                detections.count,
            slaves:
                detections
        )
    }
}