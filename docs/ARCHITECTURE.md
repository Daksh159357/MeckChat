# MeckChat Architecture — Phase 1: Real Device Discovery

## Objective
Establish real-time physical device discovery between Linux and Android devices over HiveMQ TLS broker (`broker.hivemq.com:8883`).

```
  ┌─────────────────┐                     ┌─────────────────┐
  │  Linux Laptop   │                     │  Android Phone  │
  │   (MeckChat)    │                     │   (MeckChat)    │
  └────────┬────────┘                     └────────┬────────┘
           │                                       │
           │  MQTT TLS (8883)                      │  MQTT TLS (8883)
           │                                       │
           ▼                                       ▼
     ┌───────────────────────────────────────────────────┐
     │              HiveMQ Public Broker                 │
     │             (broker.hivemq.com)                   │
     └───────────────────────────────────────────────────┘
```

## Discovery Flow
1. **Device Identity**: Generated locally on first run as `mc_<uuid>` and persisted in local preferences.
2. **Connection**: Client establishes TLS connection to `broker.hivemq.com:8883`.
3. **Presence Publication**: Local device publishes retained presence to `meckchat/v1/presence/online/<device_id>`.
4. **Subscriptions**: Subscribes to `meckchat/v1/presence/online/+`, `meckchat/v1/presence/offline/+`, `meckchat/v1/discovery`.
5. **Discovery Broadcast**: Client sends `discovery_request` on `meckchat/v1/discovery`.
6. **Peer Response**: Remote devices listening on discovery topic re-publish their presence immediately.
7. **Heartbeat**: Every 30 seconds, connected devices refresh their presence.
8. **Disconnection**: Client publishes `presence_offline` or the broker delivers Last Will and Testament.
