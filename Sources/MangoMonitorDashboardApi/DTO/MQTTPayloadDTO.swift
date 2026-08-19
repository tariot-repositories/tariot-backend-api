import Vapor

struct MQTTPayloadDTO: Content {
    let masterID: String
    let slaveID: String
    let temperature: Double
    let humidity: Double
    let latitude: Double?
    let longitude: Double?
    let rsRo: Double

    enum CodingKeys: String, CodingKey {
        case masterID     = "master_id"
        case slaveID      = "slave_id"
        case temperature
        case humidity
        case latitude     = "lat"
        case longitude    = "lng"
        case rsRo         = "rs_ro"
    }
}   