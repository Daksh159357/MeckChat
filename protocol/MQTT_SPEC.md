# MeckChat MQTT Protocol Specification (v1)

## Overview
HiveMQ acts as the **Presence & Signaling Broker** for MeckChat devices across global networks (NAT, CGNAT, Mobile, Wi-Fi). 
**No user chat, file, photo, video, or key data is ever transmitted over MQTT.**

---

## MQTT Namespace: `meckchat/v1`

### 1. Online Presence Topic
**Topic**: `meckchat/v1/presence/online/<device_id>`  
**QoS**: 1  
**Retain**: true  
**Payload (JSON)**:
```json
{
  "protocol_version": "1.0",
  "device_id": "7f3a91b2c4e5...",
  "display_name": "Daksh-PC",
  "platform": "Windows",
  "wireguard_public_key": "x58N9zP...",
  "virtual_ip": "10.77.0.2",
  "timestamp": 1724242920
}
```

### 2. Offline Presence (Last Will & Testament) Topic
**Topic**: `meckchat/v1/presence/offline/<device_id>`  
**QoS**: 1  
**Retain**: true  
**Payload (JSON)**:
```json
{
  "protocol_version": "1.0",
  "device_id": "7f3a91b2c4e5...",
  "status": "offline",
  "timestamp": 1724242920
}
```

### 3. Peer Discovery Topic
**Topic**: `meckchat/v1/discovery`  
**QoS**: 0  
**Retain**: false  
**Payload (JSON)**:
```json
{
  "action": "QUERY_ONLINE_PEERS",
  "requester_device_id": "7f3a91b2c4e5..."
}
```

### 4. Direct Peer WireGuard Signaling Topic
**Topic**: `meckchat/v1/signal/<target_device_id>`  
**QoS**: 1  
**Retain**: false  
**Payload (JSON)**:
```json
{
  "type": "PAIR_REQUEST | PAIR_ACCEPT | HANDSHAKE_INIT | ENDPOINT_UPDATE",
  "sender_device_id": "7f3a91b2c4e5...",
  "wireguard_public_key": "x58N9zP...",
  "wireguard_endpoint": "203.0.113.45:51820",
  "virtual_ip": "10.77.0.2",
  "kdf_salt": "base64_encoded_salt...",
  "auth_tag": "argon2id_auth_tag..."
}
```
---

## MQTT Configuration Standard
* **Default Host**: `broker.hivemq.com`
* **Preferred Transport**: TLS Port `8883`
* **Fallback Transport**: TCP Port `1883` / WebSocket `8000` / WSS `8884`
* **Last Will and Testament (LWT)**: Configured on MQTT connect to automatically publish offline status to `meckchat/v1/presence/offline/<device_id>` if connection breaks unexpectedly.
