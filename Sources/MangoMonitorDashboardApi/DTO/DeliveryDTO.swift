import Vapor

struct DeliveryDTO: Content {
    let id: Int
    let truckID: UUID
    let originLocation: String
    let destinationLocation: String
    let departureScheduledAt: String
    let driver: UserDTO?
    let assistDriver: UserDTO?
    let status: DeliveryStatus
    let createdBy: Int
    let createdAt: String
    let completedAt: String?
}

struct CreateDeliveryDTO: Content {
    let truckID: UUID
    let originLocation: String
    let destinationLocation: String
    let driverID: Int?
    let assistDriverID: Int?
    let createdBy: Int
}

struct UpdateDeliveryStatusDTO: Content {
    let status: DeliveryStatus
}

struct DriverDeliveryDTO: Content {
    let id: Int
    let truckID: UUID
    let originLocation: String
    let destinationLocation: String
    let departureScheduledAt: Int64
    let status: DeliveryStatus
    let createdAt: Int64
    let completedAt: Int64?
    let createdBy: Int
}

struct DeliveryDetailDTO: Content {
    let id: Int
    let truckID: UUID
    let originLocation: String
    let destinationLocation: String
    let departureScheduledAt: String
    let driver: UserDTO?
    let assistDriver: UserDTO?
    let status: DeliveryStatus
    let createdBy: Int
    let createdAt: String
    let completedAt: String?
    let detectedSlaves: [DeliverySlaveDetectionDTO]
    let crateCount: Int
}

struct DeliverySlaveDetectionDTO: Content {
    let id: UUID
    let masterID: String
    let slaveID: String
    let firstDetectedAt: String
    let lastDetectedAt: String
}