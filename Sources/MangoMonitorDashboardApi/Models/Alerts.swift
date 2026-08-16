import Foundation

enum AlertSeverity: String, Codable {
    case warning
    case critical
}

enum AlertParameter: String, Codable {
    case temperature
    case humidity
    case ethylene
}

struct Alert {
    let id: UUID
    let truckUUID: UUID
    let readingID: UUID
    let readingRecordedAt: Date
    let parameter: AlertParameter
    let severity: AlertSeverity
    let valueAtTrigger: Double
    let message: String
    let createdAt: Date
}