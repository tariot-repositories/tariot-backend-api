import Vapor

struct SensorReadingController {

    // MARK: - GET /api/v1/trucks/:truckID/readings/latest
    func latest(_ req: Request) async throws -> LatestReadingDTO {
        let truckUUID = try resolvedTruckUUID(req)

        let repo = SensorReadingRepository(
            pool: req.application.databaseClient.pool,
            logger: req.logger
        )

        guard let reading = try await repo.findLatest(truckUUID: truckUUID) else {
            throw Abort(.notFound, reason: "No readings found for this truck")
        }

        return LatestReadingDTO(
            temperature: reading.temperature,
            humidity: reading.humidity,
            ethylenePPM: reading.ethylenePPM,
            latitude: reading.latitude,
            longitude: reading.longitude,
            recordedAt: ISO8601DateFormatter().string(from: reading.recordedAt)
        )
    }

    // MARK: - GET /api/trucks/:truckID/readings/raw
    func raw(_ req: Request) async throws -> [RawReadingDTO] {
        let truckUUID = try resolvedTruckUUID(req)

        let repo = SensorReadingRepository(
            pool: req.application.databaseClient.pool,
            logger: req.logger
        )

        let readings = try await repo.findRaw(truckUUID: truckUUID)
        let formatter = ISO8601DateFormatter()

        return readings.map { reading in
            RawReadingDTO(
                id: reading.id,
                truckUUID: reading.truckUUID,
                masterID: reading.masterID,
                slaveID: reading.slaveID,
                deliverySlaveDetectionID: reading.deliverySlaveDetectionID,
                recordedAt: formatter.string(from: reading.recordedAt),
                temperature: reading.temperature,
                humidity: reading.humidity,
                ethylenePPM: reading.ethylenePPM,
                latitude: reading.latitude,
                longitude: reading.longitude
            )
        }
    }

    // MARK: - GET readings by detection
    func rawByDetection(req: Request) async throws -> SlaveReadingsResponseDTO {
        guard let detectionID = req.parameters.get("detectionID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid delivery slave detection ID")
        }

        let detectionRepository = DeliverySlaveDetectionRepository(
            pool: req.application.databaseClient.pool,
            logger: req.logger
        )

        guard let detection = try await detectionRepository.findByID(detectionID) else {
            throw Abort(.notFound, reason: "Delivery slave detection not found")
        }

        let repo = SensorReadingRepository(
            pool: req.application.databaseClient.pool,
            logger: req.logger
        )

        let readings = try await repo.findRaw(deliverySlaveDetectionID: detectionID)
        let formatter = ISO8601DateFormatter()

        let responseReadings = readings.map { reading in
            RawReadingDTO(
                id: reading.id,
                truckUUID: reading.truckUUID,
                masterID: reading.masterID,
                slaveID: reading.slaveID,
                deliverySlaveDetectionID: reading.deliverySlaveDetectionID,
                recordedAt: formatter.string(from: reading.recordedAt),
                temperature: reading.temperature,
                humidity: reading.humidity,
                ethylenePPM: reading.ethylenePPM,
                latitude: reading.latitude,
                longitude: reading.longitude
            )
        }

        return SlaveReadingsResponseDTO(
            masterID: detection.masterID,
            slaveID: detection.slaveID,
            readings: responseReadings
        )
    }

    // MARK: - GET latest by detection
    func latestByDetection(req: Request) async throws -> LatestSlaveReadingDTO {
        guard let detectionID = req.parameters.get("detectionID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid delivery slave detection ID")
        }

        let detectionRepository = DeliverySlaveDetectionRepository(
            pool: req.application.databaseClient.pool,
            logger: req.logger
        )

        guard let detection = try await detectionRepository.findByID(detectionID) else {
            throw Abort(.notFound, reason: "Delivery slave detection not found")
        }

        let repo = SensorReadingRepository(
            pool: req.application.databaseClient.pool,
            logger: req.logger
        )

        guard let reading = try await repo.findLatest(deliverySlaveDetectionID: detectionID) else {
            throw Abort(.notFound, reason: "No readings found for this slave")
        }

        return LatestSlaveReadingDTO(
            masterID: detection.masterID,
            slaveID: detection.slaveID,
            reading: LatestReadingDTO(
                temperature: reading.temperature,
                humidity: reading.humidity,
                ethylenePPM: reading.ethylenePPM,
                latitude: reading.latitude,
                longitude: reading.longitude,
                recordedAt: ISO8601DateFormatter().string(from: reading.recordedAt)
            )
        )
    }

    // MARK: - Private Helpers
    private func resolvedTruckUUID(_ req: Request) throws -> UUID {
        guard
            let truckIDString = req.parameters.get("truckID"),
            let uuid = UUID(uuidString: truckIDString)
        else {
            throw Abort(.badRequest, reason: "Invalid or missing truck UUID")
        }
        return uuid
    }
}