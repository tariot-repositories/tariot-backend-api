import Foundation

struct DeliverySlaveDetection: Codable, Identifiable {
    let id: UUID
    let deliveryID: Int
    let masterID: String
    let slaveID: String
    let firstDetectedAt: Date
    let lastDetectedAt: Date
    let createdAt: Date
}