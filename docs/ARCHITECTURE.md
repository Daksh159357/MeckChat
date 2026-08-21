# MeckChat System Architecture

```text
                         INTERNET
                            │
                    ┌───────▼───────┐
                    │     HiveMQ    │
                    │               │
                    │ ONLINE STATUS │
                    │ + SIGNALING   │
                    └───────┬───────┘
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

### 1. Signaling Plane (HiveMQ Broker TLS 8883)
- Serves exclusively as a global rendezvous and discovery service.
- Works over public networks including NAT, CGNAT, Mobile LTE/5G, and Wi-Fi.
- Handles typed signaling payloads:
  - `PRESENCE_ONLINE` / `PRESENCE_OFFLINE` (MQTT Last Will & Testament)
  - `PAIR_REQUEST` / `PAIR_ACCEPT` / `PAIR_REJECT` (Argon2id KDF authentication)
  - `WIREGUARD_OFFER` / `WIREGUARD_ANSWER` (Public key & NAT endpoint exchange)
  - `CONNECTION_STATE` (Tunnel status updates)
- **Zero user data** (messages, files, media) passes through HiveMQ.

### 2. Data Plane (WireGuard Encrypted Private Network - `10.77.0.0/16`)
- Peer-to-Peer tunnel established directly between devices once endpoints are exchanged.
- Allocates collision-resistant virtual IP addresses within `10.77.0.0/16` (e.g. Device A: `10.77.0.2`, Device B: `10.77.0.3`).
- Encrypts all user text messages (stored locally via SQLite), 64KB chunked resumable file transfers (SHA-256 integrity verified), and WebRTC streams over Curve25519 / ChaCha20-Poly1305 WireGuard protocol.

---

## 💻 Platform WireGuard Integration Architecture

| Operating System | VPN Integration Strategy | Status |
| :--- | :--- | :--- |
| **Linux** | Native `netlink` / `ip link` / `wg` driver configuration helper | **IMPLEMENTED** |
| **Windows** | Wintun driver & `wireguard.exe` tunnel service abstraction | **PARTIALLY IMPLEMENTED** |
| **Android** | Android `VpnService` / WireGuard Android SDK helper | **PARTIALLY IMPLEMENTED** |
| **macOS / iOS** | Apple Network Extension (`NETunnelProviderManager`) & entitlement signing specification | **REQUIRES APPLE SIGNING** |
