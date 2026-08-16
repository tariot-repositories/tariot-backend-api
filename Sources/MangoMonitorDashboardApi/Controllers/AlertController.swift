import Vapor

struct AlertController: RouteCollection {

    private let alertRepository: AlertRepository

    init(alertRepository: AlertRepository) {
        self.alertRepository = alertRepository
    }

    func boot(routes: any RoutesBuilder) throws {
        let alerts = routes.grouped("alerts")

        alerts.get(use: index)
        alerts.get(":truckID", use: show)
    }

    // MARK: - GET /alerts
    func index(req: Request) async throws -> [AlertDTO] {
        let alerts = try await alertRepository.findAllActive()
        return alerts.map { makeDTO(from: $0) }
    }

    // MARK: - GET /alerts/:truckID
    func show(req: Request) async throws -> [AlertDTO] {
        guard let truckID = req.parameters.get("truckID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid truck UUID")
        }

        let alerts = try await alertRepository.findAll(truckUUID: truckID)
        return alerts.map { makeDTO(from: $0) }
    }

    // MARK: - Private DTO Mapping
    private func makeDTO(from alert: Alert) -> AlertDTO {
        AlertDTO(
            id: alert.id,
            truckUUID: alert.truckUUID,
            readingID: alert.readingID,
            parameter: alert.parameter,
            severity: alert.severity,
            valueAtTrigger: alert.valueAtTrigger,
            message: alert.message,
            createdAt: alert.createdAt.description
        )
    }
}