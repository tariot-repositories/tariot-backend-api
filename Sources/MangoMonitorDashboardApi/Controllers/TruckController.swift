import Vapor

struct TruckController {

    // MARK: - Properties
    let truckRepository: TruckRepository
    let sensorReadingRepository: SensorReadingRepository
    let alertRepository: AlertRepository

    // MARK: - GET /api/v1/trucks
    // Returns all active trucks with latest reading embedded
    // and active alert count
    func index(_ req: Request) async throws -> [TruckListItemDTO] {
        let trucks = try await truckRepository.findAllActive()

        var result: [TruckListItemDTO] = []

        for truck in trucks {
            let latestReading = try await sensorReadingRepository.findLatest(truckUUID: truck.id)
            // let alertCount = try await alertRepository.countActive(truckUUID: truck.id)

            result.append(TruckListItemDTO(
                id: truck.id,
                truckId: truck.truckId,
                name: truck.name,
                latestReading: latestReading.map { reading in
                    LatestReadingDTO(
                        temperature: reading.temperature,
                        humidity: reading.humidity,
                        ethylenePPM: reading.ethylenePPM,
                        latitude: reading.latitude,
                        longitude: reading.longitude,
                        recordedAt: ISO8601DateFormatter().string(from: reading.recordedAt)
                    )
                }
                // activeAlertCount: alertCount
            ))
        }

        return result
    }

    // MARK: - GET /api/v1/trucks/:truckID
    // Returns a single truck's full detail with alert history
    func show(_ req: Request) async throws -> TruckDetailDTO {
        guard let truckID = req.parameters.get("truckID") else {
            throw Abort(.badRequest, reason: "Missing truckID parameter")
        }

        let truck = try await truckRepository.findByUUID(truckID)
        let latestReading = try await sensorReadingRepository.findLatest(truckUUID: truck.id)
        // let alerts = try await alertRepository.findAll(truckUUID: truck.id)

        return TruckDetailDTO(
            id: truck.id,
            truckId: truck.truckId,
            name: truck.name,
            isActive: truck.isActive,
            createdAt: ISO8601DateFormatter().string(from: truck.createdAt),
            latestReading: latestReading.map { reading in
                LatestReadingDTO(
                    temperature: reading.temperature,
                    humidity: reading.humidity,
                    ethylenePPM: reading.ethylenePPM,
                    latitude: reading.latitude,
                    longitude: reading.longitude,
                    recordedAt: ISO8601DateFormatter().string(from: reading.recordedAt)
                )
            },
            // alerts: alerts.map { alert in
            //     AlertDTO(
            //         id: alert.id,
            //         truckUUID: alert.truckUUID,
            //         readingID: alert.readingID,
            //         parameter: alert.parameter,
            //         severity: alert.severity,
            //         valueAtTrigger: alert.valueAtTrigger,
            //         message: alert.message,
            //         createdAt: ISO8601DateFormatter().string(from: alert.createdAt)
            //     )
            // }
        )
    }
}