import Foundation

enum DeliveryStatus: String, Codable {
    case dibuat
    case menungguKonfirmasiSupir  = "menunggu_konfirmasi_supir"
    case menungguDeteksiNode      = "menunggu_deteksi_node"
    case dalamPerjalanan          = "dalam_perjalanan"
    case selesai
}

struct Delivery {
    let id: Int
    let truckID: UUID
    let originLocation: String
    let destinationLocation: String
    let departureScheduledAt: Date
    let driverID: Int?
    let assistDriverID: Int?
    let status: DeliveryStatus
    let createdBy: Int
    let createdAt: Date
    let completedAt: Date?
}

struct DriverDelivery {
    let id: Int
    let truckID: UUID
    let originLocation: String
    let destinationLocation: String
    let departureScheduledAt: Date
    let status: DeliveryStatus
    let createdAt: Date
    let completedAt: Date?
    let createdBy: Int
}