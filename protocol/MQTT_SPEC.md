# MeckChat Protocol Specification — Phase 1: MQTT Discovery

## Broker
- **Host**: `broker.hivemq.com`
- **Port**: `8883` (TLS TCP)
- **Protocol**: MQTT 3.1.1 / 5.0 over TLS

## Topics

| Action | Topic | QoS | Retained |
|---|---|---|---|
| Publish Online Presence | `meckchat/v1/presence/online/<device_id>` | 1 | `true` |
| Publish Offline Presence / LWT | `meckchat/v1/presence/offline/<device_id>` | 1 | `true` |
| Broadcast Discovery Request | `meckchat/v1/discovery` | 1 | `false` |
| Subscribe Online Wildcard | `meckchat/v1/presence/online/+` | 1 | N/A |
| Subscribe Offline Wildcard | `meckchat/v1/presence/offline/+` | 1 | N/A |
| Subscribe Discovery Requests | `meckchat/v1/discovery` | 1 | N/A |

## Payloads

### 1. Online Presence (`presence_online`)
Published upon initial connection, every 30-second heartbeat, and in response to discovery requests.
```json
{
  "type": "presence_online",
  "protocol_version": 1,
  "device_id": "<local_device_id>",
  "display_name": "<local_device_name>",
  "platform": "linux" | "android",
  "timestamp": 1724540000
}
```

### 2. Offline Presence (`presence_offline`)
Published upon clean application shutdown or as the MQTT Last Will and Testament (LWT) if disconnected abruptly.
```json
{
  "type": "presence_offline",
  "device_id": "<local_device_id>"
}
```

### 3. Discovery Request (`discovery_request`)
Published when a device first starts up to prompt all existing online peers to immediately re-announce their presence.
```json
{
  "type": "discovery_request",
  "protocol_version": 1,
  "device_id": "<local_device_id>",
  "timestamp": 1724540000
}
```
