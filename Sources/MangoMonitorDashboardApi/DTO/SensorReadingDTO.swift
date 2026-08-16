import Vapor

struct LatestReadingDTO: Content {
    let temperature: Double
    let humidity: Double
    let ethylenePPM: Double
    let latitude: Double
    let longitude: Double
    let recordedAt: String
}

struct RawReadingDTO: Content {
    let id: UUID
    let truckUUID: UUID
    let deliverySlaveDetectionID: UUID?
    let recordedAt: String
    let temperature: Double
    let humidity: Double
    let ethylenePPM: Double
    let gasRaw: Double
    let latitude: Double
    let longitude: Double
}

struct SlaveReadingsResponseDTO: Content {
    let masterID: String
    let slaveID: String
    let readings: [RawReadingDTO]
}

struct LatestSlaveReadingDTO: Content {
    let masterID: String
    let slaveID: String
    let reading: LatestReadingDTO
}