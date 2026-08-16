# MangoMonitorDashboardApi

💧 A project built with the Vapor web framework.

## Getting Started

To build the project using the Swift Package Manager, run the following command in the terminal from the root of the project:
```bash
swift build
```

To run the project and start the server, use the following command:
```bash
swift run
```

To execute tests, use the following command:
```bash
swift test
```

### See more

- [Vapor Website](https://vapor.codes)
- [Vapor Documentation](https://docs.vapor.codes)
- [Vapor GitHub](https://github.com/vapor)
- [Vapor Community maintained packages](https://github.com/vapor-community)

# Tariot Mango Monitor API — macOS Dashboard

> Source: current Vapor backend implementation discussed in this conversation.
>
> Base URL (local): `http://127.0.0.1:8080/api`
>
> This document describes the routes currently intended for the macOS dashboard. It does **not** invent future endpoints; routes marked as compatibility/secondary should be treated accordingly.

## 1. Deliveries

### GET `/deliveries`

Get the delivery list.

**Method:** `GET`

**Request body:** none

**Response:** `200 OK`

```json
[
  {
    "id": 1,
    "truckID": "285F28CC-F214-4205-8EE6-D1DDE75BD442",
    "originLocation": "Jakarta",
    "destinationLocation": "Bandung",
    "departureScheduledAt": "2026-08-13 06:46:42 +0000",
    "driver": {
      "id": 1,
      "name": "Raka Adhyatama",
      "email": "raka.adhyatama@example.com",
      "role": "driver",
      "createdAt": "2026-08-12 17:57:02 +0000"
    },
    "assistDriver": {
      "id": 2,
      "name": "Nayaka Pradipta",
      "email": "nayaka.pradipta@example.com",
      "role": "driver",
      "createdAt": "2026-08-12 17:57:02 +0000"
    },
    "status": "dalam_perjalanan",
    "createdBy": 4,
    "createdAt": "2026-08-13 06:16:42 +0000",
    "completedAt": null
  }
]
```

### GET `/deliveries/{id}`

Get one delivery plus its detected slaves and derived crate count.

**Method:** `GET`

**Request body:** none

**Response:** `200 OK`

```json
{
  "id": 1,
  "truckID": "285F28CC-F214-4205-8EE6-D1DDE75BD442",
  "originLocation": "Jakarta",
  "destinationLocation": "Bandung",
  "departureScheduledAt": "2026-08-13 06:46:42 +0000",
  "driver": {
    "id": 1,
    "name": "Raka Adhyatama",
    "email": "raka.adhyatama@example.com",
    "role": "driver",
    "createdAt": "2026-08-12 17:57:02 +0000"
  },
  "assistDriver": {
    "id": 2,
    "name": "Nayaka Pradipta",
    "email": "nayaka.pradipta@example.com",
    "role": "driver",
    "createdAt": "2026-08-12 17:57:02 +0000"
  },
  "status": "dalam_perjalanan",
  "createdBy": 4,
  "createdAt": "2026-08-13 06:16:42 +0000",
  "completedAt": null,
  "detectedSlaves": [
    {
      "id": "BB7C2BFE-84BC-40DE-BE9E-DE06BE796119",
      "masterID": "M1",
      "slaveID": "M1S1",
      "firstDetectedAt": "2026-04-15 01:30:00 +0000",
      "lastDetectedAt": "2026-04-15 01:30:00 +0000"
    },
    {
      "id": "CE8C1B0E-7B6E-4D0E-9AA3-320E0D3F7C52",
      "masterID": "M1",
      "slaveID": "M1S2",
      "firstDetectedAt": "2026-04-15 01:30:00 +0000",
      "lastDetectedAt": "2026-04-15 01:30:00 +0000"
    }
  ],
  "crateCount": 2
}
```

### GET `/deliveries/truck/{truckID}`

Get deliveries associated with one truck.

**Method:** `GET`

**Path parameter:** `truckID` = truck UUID

**Response:** same `DeliveryDTO[]` shape as `GET /deliveries`.

### PATCH `/deliveries/{id}/status`

Update the delivery status.

**Method:** `PATCH`

**Request body:** `UpdateDeliveryStatusDTO` (exact field schema is defined by the backend DTO; the current controller expects a `status` value matching `DeliveryStatus`).

Known status values:

```text
 dibuat
 menunggu_konfirmasi_supir
 menunggu_deteksi_node
 dalam_perjalanan
 selesai
```

**Response:** updated `DeliveryDTO`.

### POST `/deliveries`

Create a delivery.

**Method:** `POST`

**Request body:** `CreateDeliveryDTO`.

The current repository expects these fields internally:

```json
{
  "truckID": "<truck UUID>",
  "originLocation": "Jakarta",
  "destinationLocation": "Bandung",
  "driverID": 1,
  "assistDriverID": 2,
  "createdBy": 4
}
```

> The exact encoded field names depend on the current `CreateDeliveryDTO` definition. The backend repository uses `truckID`, `originLocation`, `destinationLocation`, `driverID`, `assistDriverID`, and `createdBy` properties.

---

## 2. Slave detection / crate mapping

### GET `/slave-detection-readings/{detectionID}/...`

The macOS dashboard should use the **slave-specific reading endpoints below** after obtaining `detectionID` from `GET /deliveries/{id}`.

### GET `/slave-detection-readings/{detectionID}`

Get the full sensor history for one detected slave.

**Method:** `GET`

**Response:** `200 OK`

```json
{
  "masterID": "M1",
  "slaveID": "M1S1",
  "readings": [
    {
      "id": "FB1D64C5-EC0A-466E-91F4-C83E67B54C43",
      "truckUUID": "285F28CC-F214-4205-8EE6-D1DDE75BD442",
      "deliverySlaveDetectionID": "BB7C2BFE-84BC-40DE-BE9E-DE06BE796119",
      "recordedAt": "2026-08-15T17:20:12Z",
      "temperature": 3.5,
      "humidity": 59.5,
      "ethylenePPM": 88,
      "gasRaw": 0,
      "latitude": -23.46633333,
      "longitude": -51.84013333
    }
  ]
}
```

### GET `/slave-detection-readings/{detectionID}/latest`

Get only the latest reading for one detected slave.

**Method:** `GET`

**Response:** `200 OK`

```json
{
  "masterID": "M1",
  "slaveID": "M1S1",
  "reading": {
    "temperature": 13,
    "humidity": 51,
    "ethylenePPM": 97,
    "latitude": -23.46631667,
    "longitude": -51.84028333,
    "recordedAt": "2026-08-15T17:39:08Z"
  }
}
```

---

## 3. Alerts

### GET `/alerts`

Get persisted alert events across trucks.

**Method:** `GET`

**Response:** `200 OK`

```json
[
  {
    "id": "E2D623AF-FDA9-4EC3-A083-26911337AA9F",
    "truckUUID": "285F28CC-F214-4205-8EE6-D1DDE75BD442",
    "readingID": "987FE99D-AF4D-40A1-9A06-BE6BD784F72A",
    "parameter": "temperature",
    "severity": "critical",
    "valueAtTrigger": 20.96,
    "message": "Critical: suhu 21.0°C melebihi batas maksimum 15°C",
    "createdAt": "2026-08-15 17:38:52 +0000"
  }
]
```

> Current semantics: this is an alert-event/history feed. It is **not** a resolved-vs-active alert lifecycle yet.

### GET `/alerts/{truckID}`

Get alert events for one truck.

**Method:** `GET`

**Path parameter:** `truckID` = truck UUID

**Response:** same `AlertDTO[]` shape as `GET /alerts`.

Current alert parameters generated by the backend:

```text
temperature
ethylene
```

Current generated severities:

```text
warning
critical
```

Humidity alerts are no longer generated by the current MQTT alert evaluator; older humidity rows may still exist in the database as history.

---

## 4. Truck / sensor compatibility endpoints

These endpoints still exist and are currently used by truck-oriented backend code. They should be treated as compatibility endpoints while the dashboard moves to detection-scoped data.

### GET `/trucks`

Get active trucks.

**Method:** `GET`

**Response:** `TruckDTO[]` (exact DTO shape is defined by the current `TruckController`).

### GET `/trucks/{truckID}/readings/latest`

Get the latest reading for a truck.

**Method:** `GET`

**Response:**

```json
{
  "temperature": 13,
  "humidity": 51,
  "ethylenePPM": 97,
  "latitude": -23.46631667,
  "longitude": -51.84028333,
  "recordedAt": "2026-08-15T17:39:08Z"
}
```

### GET `/trucks/{truckID}/readings/raw`

Get raw readings for a truck.

**Method:** `GET`

**Response:** `RawReadingDTO[]`.

> This endpoint remains available because `TruckController` still uses truck-scoped latest readings. It should not be treated as the preferred crate/slave-specific endpoint.

---

## 5. Dashboard recommendation

For the macOS dashboard, the preferred data flow is:

```text
GET /deliveries
        ↓
GET /deliveries/{id}
        ↓
detectedSlaves[] + crateCount
        ↓
GET /slave-detection-readings/{detectionID}/latest
        ↓
GET /slave-detection-readings/{detectionID}
        ↓
GET /alerts/{truckUUID}
```

The dashboard should not calculate crate count from sensor readings; it should use `crateCount` from the delivery detail response.

# Tariot Mango Monitor API — iOS App

> Source: current Vapor backend implementation discussed in this conversation.
>
> Base URL (local): `http://127.0.0.1:8080/api`
>
> This document focuses on the routes the driver/iOS flow currently needs: assigned deliveries, delivery status, and detected-slave registration.

## 1. Assigned deliveries

### GET `/deliveries/assigned/{userID}`

Get deliveries currently assigned to a driver.

**Method:** `GET`

**Path parameter:** `userID` = user/driver integer ID

**Response:** `200 OK`

```json
[
  {
    "id": 1,
    "truckID": "285F28CC-F214-4205-8EE6-D1DDE75BD442",
    "originLocation": "Jakarta",
    "destinationLocation": "Bandung",
    "departureScheduledAt": 1776012402,
    "status": "menunggu_konfirmasi_supir",
    "createdAt": 1775974602,
    "completedAt": null,
    "createdBy": 4
  }
]
```

> The current `assigned()` controller converts the dates to Unix timestamps. Exact integer values depend on the actual dates stored in PostgreSQL.

---

## 2. Delivery status

### PATCH `/deliveries/{id}/status`

Change the status of a delivery.

**Method:** `PATCH`

**Path parameter:** `id` = delivery integer ID

**Request body:** current backend expects `UpdateDeliveryStatusDTO`.

Conceptually:

```json
{
  "status": "menunggu_deteksi_node"
}
```

Known status values:

```text
buat / dibuat                → actual enum value: dibuat
menunggu_konfirmasi_supir
menunggu_deteksi_node

dalam_perjalanan
selesai
```

**Response:** updated `DeliveryDTO`.

> The iOS app should use the exact enum strings above when changing delivery state.

---

## 3. Register detected slaves

This is the main iOS-to-backend topology endpoint.

### POST `/delivery-slave-detections`

Register or refresh the slaves detected for a delivery.

**Method:** `POST`

**Request body:**

```json
{
  "delivery_id": 1,
  "master_code": "M1",
  "slave_detected": [
    {
      "slave_code": "M1S1",
      "timestamp": 1776216600
    },
    {
      "slave_code": "M1S2",
      "timestamp": 1776216600
    }
  ]
}
```

Field meanings:

| Field | Type | Meaning |
|---|---|---|
| `delivery_id` | integer | Target delivery |
| `master_code` | string | Master identifier discovered by the iOS app |
| `slave_detected` | array | Slaves discovered for this delivery |
| `slave_code` | string | Individual slave identifier |
| `timestamp` | integer | Unix timestamp of detection |

**Response:**

```json
{
  "deliveryID": 1,
  "masterCode": "M1",
  "slaveCount": 2,
  "slaves": [
    {
      "id": "BB7C2BFE-84BC-40DE-BE9E-DE06BE796119",
      "deliveryID": 1,
      "masterID": "M1",
      "slaveID": "M1S1",
      "firstDetectedAt": "2026-08-15 17:20:00 +0000",
      "lastDetectedAt": "2026-08-15 17:20:00 +0000",
      "createdAt": "2026-08-15 17:20:00 +0000"
    },
    {
      "id": "CE8C1B0E-7B6E-4D0E-9AA3-320E0D3F7C52",
      "deliveryID": 1,
      "masterID": "M1",
      "slaveID": "M1S2",
      "firstDetectedAt": "2026-08-15 17:20:00 +0000",
      "lastDetectedAt": "2026-08-15 17:20:00 +0000",
      "createdAt": "2026-08-15 17:20:00 +0000"
    }
  ]
}
```

The backend uses `(delivery_id, slave_id)` as a unique key, so repeated detections refresh `last_detected_at` instead of creating duplicates.

---

## 4. Inspect detected slaves for a delivery

### GET `/delivery-slave-detections/{deliveryID}`

Retrieve all detected slaves currently stored for a delivery.

**Method:** `GET`

**Path parameter:** `deliveryID` = delivery integer ID

**Response:**

```json
{
  "deliveryID": 1,
  "masterCode": "M1",
  "slaveCount": 2,
  "slaves": [
    {
      "id": "BB7C2BFE-84BC-40DE-BE9E-DE06BE796119",
      "deliveryID": 1,
      "masterID": "M1",
      "slaveID": "M1S1",
      "firstDetectedAt": "2026-08-15 17:20:00 +0000",
      "lastDetectedAt": "2026-08-15 17:20:00 +0000",
      "createdAt": "2026-08-15 17:20:00 +0000"
    }
  ]
}
```

---

## 5. Delivery detail (available if the iOS app needs it)

### GET `/deliveries/{id}`

Returns the delivery plus detected-slave metadata and `crateCount`.

**Method:** `GET`

The response includes:

```text
delivery fields
driver / assistDriver
status
detectedSlaves[]
crateCount
```

Example:

```json
{
  "id": 1,
  "truckID": "285F28CC-F214-4205-8EE6-D1DDE75BD442",
  "originLocation": "Jakarta",
  "destinationLocation": "Bandung",
  "status": "dalam_perjalanan",
  "detectedSlaves": [
    {
      "id": "BB7C2BFE-84BC-40DE-BE9E-DE06BE796119",
      "masterID": "M1",
      "slaveID": "M1S1",
      "firstDetectedAt": "2026-08-15 17:20:00 +0000",
      "lastDetectedAt": "2026-08-15 17:20:00 +0000"
    }
  ],
  "crateCount": 1
}
```

---

## 6. Important: MQTT sensor ingestion is not an iOS REST route

The backend receives sensor telemetry separately through MQTT.

Current payload shape:

```json
{
  "timestamp": 1000909090,
  "master_id": "M1",
  "slave_id": "M1S1",
  "temperature": 31.5,
  "humidity": 40,
  "lat": -23.46636667,
  "lng": -51.84015,
  "ppm": 100
}
```

The iOS app's responsibility discussed in this architecture is to discover the master/slave topology and register the detected slaves through `POST /delivery-slave-detections`.

The backend `MQTTService` then resolves `master_id + slave_id` against `delivery_slave_detection` and stores sensor readings.

---

## 7. iOS recommended flow

```text
1. GET /deliveries/assigned/{userID}
          ↓
2. PATCH /deliveries/{id}/status
          ↓
3. Discover master/slaves via MQTT wildcard
          ↓
4. POST /delivery-slave-detections
          ↓
5. PATCH /deliveries/{id}/status → dalam_perjalanan
```

For later verification/debugging, the iOS app may also call:

```text
GET /deliveries/{id}
GET /delivery-slave-detections/{deliveryID}
```
