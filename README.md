# MeckChat — Phase 1: Real Device Discovery

MeckChat is a cross-platform encrypted peer-to-peer communication application.

## Phase 1 Milestone
Real-time physical device discovery between **Linux** and **Android** devices over the HiveMQ public MQTT broker (`broker.hivemq.com:8883` over TLS).

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

## Protocol Overview
- **Broker**: `broker.hivemq.com:8883` (TLS)
- **Topics**:
  - `meckchat/v1/presence/online/<device_id>`: Retained online presence
  - `meckchat/v1/presence/offline/<device_id>`: Offline notification / Last Will
  - `meckchat/v1/discovery`: Broadcast discovery request
- **Presence Heartbeat**: 30 seconds
- **Self-Filtering**: Messages from the local device are ignored safely.

## Repository Structure
```
meckchat/
├── apps/
│   └── flutter/        # Cross-platform Flutter application
├── docs/               # Architecture & protocol documentation
├── protocol/           # MQTT specification
├── .github/
│   └── workflows/      # CI & Release automation (Linux & Android)
└── README.md
```

## License
MIT
