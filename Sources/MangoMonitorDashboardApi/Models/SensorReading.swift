import Foundation

struct SensorReading {
    let id: UUID
    let truckUUID: UUID
    let deliverySlaveDetectionID: UUID?
    let recordedAt: Date
    let temperature: Double
    let humidity: Double
    let ethylenePPM: Double
    let gasRaw: Double
    let latitude: Double
    let longitude: Double
}
