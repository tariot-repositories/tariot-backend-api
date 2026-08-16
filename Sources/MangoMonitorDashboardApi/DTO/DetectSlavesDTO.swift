import Vapor

struct DetectSlavesDTO: Content {
    let deliveryID: Int
    let masterCode: String
    let slaveDetected: [DetectedSlaveDTO]

    enum CodingKeys: String, CodingKey {
        case deliveryID = "delivery_id"
        case masterCode = "master_code"
        case slaveDetected = "slave_detected"
    }
}

struct DetectedSlaveDTO: Content {
    let slaveCode: String
    let timestamp: Int64

    enum CodingKeys: String, CodingKey {
        case slaveCode = "slave_code"
        case timestamp
    }
}

struct DetectSlavesResponseDTO: Content {
    let deliveryID: Int
    let masterCode: String
    let slaveCount: Int
    let slaves: [DeliverySlaveDetection]
}