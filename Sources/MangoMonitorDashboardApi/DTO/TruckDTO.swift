import Vapor

struct TruckListItemDTO: Content {
    let id: UUID
    let truckId: String
    let name: String?
    let latestReading: LatestReadingDTO?
    // let activeAlertCount: Int
}

struct TruckDetailDTO: Content {
    let id: UUID
    let truckId: String
    let name: String?
    let isActive: Bool
    let createdAt: String
    let latestReading: LatestReadingDTO?
    // let alerts: [AlertDTO]
}