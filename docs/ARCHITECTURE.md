# MeckChat System Architecture

```text
                         INTERNET
                            │
                    ┌───────▼───────┐
                    │     HiveMQ     │
                    │                │
                    │ ONLINE STATUS  │
                    │ + SIGNALING    │
                    └───────┬────────┘
                            │
                  MQTT only for signaling
                            │
             ┌──────────────┴──────────────┐
             │                             │
       ┌─────▼─────┐                 ┌─────▼─────┐
       │  Device A │                 │  Device B │
       │  MeckChat │                 │  MeckChat │
       └─────┬─────┘                 └─────┬─────┘
             │                             │
             │       WireGuard tunnel      │
             │◄═══════════════════════════►│
             │                             │
             └───────────┬─────────────────┘
                         │
                   PRIVATE NETWORK (10.77.0.0/16)
                         │
              ┌──────────┼──────────┐
              │          │          │
            Chat       Files      Media
```

## Architectural Boundaries

### Signaling Layer (HiveMQ Broker)
- Serves exclusively as a global rendezvous and discovery service.
- Works over public networks including NAT, CGNAT, Mobile LTE/5G, and Wi-Fi.
- Handles presence (`online`, `offline`), last will messages, and initial peer public WireGuard setup parameters.

### Data Layer (WireGuard Encrypted Private Network)
- Peer-to-Peer tunnel established directly between devices once endpoints are discovered.
- Allocates collision-resistant virtual IP addresses within `10.77.0.0/16`.
- Encrypts all user messages, files, photos, videos, and WebRTC media streams with ChaCha20-Poly1305 / Curve25519 standard WireGuard protocol.
