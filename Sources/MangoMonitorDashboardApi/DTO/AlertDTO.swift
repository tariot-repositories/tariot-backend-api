import Vapor

struct AlertDTO: Content {
    let id: UUID
    let truckUUID: UUID
    let readingID: UUID
    let parameter: AlertParameter
    let severity: AlertSeverity
    let valueAtTrigger: Double
    let message: String
    let createdAt: String
}