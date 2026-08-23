# MeckChat System Architecture & Status

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
- Serves exclusively as a global rendezvous and discovery service (`broker.hivemq.com:8883`).
- Works over public networks including NAT, CGNAT, Mobile LTE/5G, and Wi-Fi.
- Handles typed signaling payloads:
  - `PRESENCE_ONLINE` / `PRESENCE_OFFLINE` (MQTT Last Will & Testament)
  - `PAIR_REQUEST` / `PAIR_ACCEPT` / `PAIR_REJECT` (Argon2id KDF authentication)
  - `WIREGUARD_OFFER` / `WIREGUARD_ANSWER` (Public key & NAT endpoint exchange)
  - `CONNECTION_STATE` (Tunnel status updates)
- **Zero user data** (messages, files, media) passes through HiveMQ. Verified by `assert_no_application_data()` in Rust core and `assertNoChatDataInMqtt()` in Dart.

### 2. Data Plane (WireGuard Encrypted Private Network - `10.77.0.0/16`)
- Peer-to-Peer tunnel established directly between devices once endpoints are exchanged.
- Allocates collision-resistant virtual IP addresses within `10.77.0.0/16` derived from SHA-256 hash of device identity.
- Cryptographic Engine: Official WireGuard GoBackend (`com.wireguard.android:tunnel`) on Android and BoringTun Noise protocol (`boringtun::noise::Tunn`) on Linux using Curve25519, ChaCha20-Poly1305, and BLAKE2s.
- Encrypts all user text messages (stored locally via SQLite), 64KB chunked resumable file transfers (SHA-256 integrity verified), and WebRTC streams over WireGuard.
- Handshake Verification Guard: WireGuard tunnel state transitions to `Connected` ONLY IF `time_since_last_handshake` < 180s and P2P `HEALTH_PING`/`HEALTH_PONG` health check succeeds over `10.77.x.y:51821`.

---

## 💻 Operating System WireGuard Driver Matrix

| Operating System | VPN / Tunnel Integration Strategy | Implementation Status |
| :--- | :--- | :--- |
| **Linux** | Native `WireGuardManager` engine creating `meckchat0` WireGuard interface with peer AllowedIPs and keepalives | **IMPLEMENTED & VERIFIED** |
| **Android** | Official `wireguard-android` SDK (`GoBackend`) integrated in `MeckChatVpnService.kt` and `MainActivity.kt` MethodChannel (`com.meckchat/wireguard_vpn`) for real WireGuard Noise protocol, handshakes, and statistics | **IMPLEMENTED & VERIFIED** |
| **Windows** | Wintun driver & `wireguard.exe` tunnel service abstraction | **PARTIALLY IMPLEMENTED** |
| **macOS / iOS** | Apple Network Extension (`NETunnelProviderManager`) & entitlement signing specification | **NOT VERIFIED** (Requires Apple Signing) |
