import Vapor

struct AlertDTO: Content {
    let id: UUID
    let truckUUID: UUID
    let readingID: UUID
    let readingRecordedAt: Date
    let deliverySlaveDetectionID: UUID?
    let masterID: String?
    let slaveID: String?
    let parameter: AlertParameter
    let severity: AlertSeverity
    let valueAtTrigger: Double
    let message: String
    let createdAt: Date
}