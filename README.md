# MeckChat — Global Encrypted P2P Communication App

[![CI Status](https://github.com/Daksh159357/meckchat/actions/workflows/ci.yml/badge.svg)](https://github.com/Daksh159357/meckchat/actions/workflows/ci.yml)
[![Release Status](https://github.com/Daksh159357/meckchat/actions/workflows/release.yml/badge.svg)](https://github.com/Daksh159357/meckchat/actions/workflows/release.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**MeckChat** is a cross-platform (Android, iOS, Windows, Linux, macOS) global encrypted peer-to-peer communication application.

---

## 💡 Core Architecture

> **HiveMQ is used ONLY to show which MeckChat devices are online and to exchange the minimum signaling information required to establish a WireGuard connection. All actual chat, file, photo, video, and real-time media communication happens directly between devices through WireGuard.**

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
               ┌──────────┼──────────�## 📊 Feature & System Status Matrix (v0.1.4)

| Feature / Subsystem | Status | Technical Details & Verification Evidence |
| :--- | :--- | :--- |
| **Device Identity & Cryptography** | **IMPLEMENTED & VERIFIED** | Local X25519 keypair generation, SHA-256 Device IDs, collision-resistant `10.77.x.y` IP allocation. Private keys marked `#[serde(skip)]` and never leave local storage. |
| **Typed MQTT Presence & LWT** | **IMPLEMENTED & VERIFIED** | Connects to HiveMQ TLS 8883 (`broker.hivemq.com`). Publishes online/offline presence, handles discovery (`meckchat/v1/discovery`), self-device filtering, and Last Will & Testament (LWT). Verified zero user data over MQTT. |
| **Argon2id Shared-Secret Pairing** | **IMPLEMENTED & VERIFIED** | Shared secret authentication binding `shared_secret`, `salt`, `sender_device_id`, `receiver_device_id`, and `timestamp`. 300s expiration check and request ID replay prevention enforced. |
| **WireGuard BoringTun Engine** | **IMPLEMENTED & VERIFIED** | `WireGuardManager` runtime engine in Rust using BoringTun Noise protocol (`boringtun::noise::Tunn`), Curve25519, ChaCha20-Poly1305, BLAKE2s, and handshake state machine. |
| **Android Driver & Tunnel** | **IMPLEMENTED & VERIFIED** | Native `MeckChatVpnService.kt` and `MainActivity.kt` MethodChannel (`com.meckchat/wireguard_vpn`) creating Android TUN interface (`10.77.x.y/16`, MTU 1420) and binding to WireGuard engine. |
| **Linux Driver & Tunnel** | **IMPLEMENTED & VERIFIED** | `WireGuardManager` engine creating `meckchat0` WireGuard interface with peer AllowedIPs, keepalives, and native handshake metrics (`latest_handshake_secs`, `rx_bytes`, `tx_bytes`). |
| **P2P WireGuard Chat & Health Check** | **IMPLEMENTED & VERIFIED** | Direct P2P socket transport on `10.77.x.y:51821` with `HEALTH_PING`/`HEALTH_PONG` health checks, Chat Connection Guard (`wireguardStatus == Connected`), and zero HiveMQ chat traffic. |
| **SQLite History & Offline Queue** | **IMPLEMENTED & VERIFIED** | Chat history persisted locally in `chat_messages` table via `ChatDbService`. Pending offline messages auto-flush over WireGuard P2P socket upon reconnection. |
| **Flutter UI Navigation & States** | **IMPLEMENTED & VERIFIED** | 4 main tabs (**Devices**, **Chat**, **Files**, **Settings**). Visual distinction between **`🟢 HiveMQ Online`** and **`🟢 WireGuard Connected`**. |on implemented in Rust core. |
| **WebRTC Media & Calling** | **PARTIALLY IMPLEMENTED** | WebRTC SDP offer/answer and ICE candidate payload serializers (`WebRtcSignalingMessage`) implemented in Rust core and `flutter_webrtc` added. Camera/microphone hardware media pipeline & peer rendering are partially implemented. |
| **Flutter UI Dual State** | **IMPLEMENTED** | Visual distinction between **`🟢 Online`** (HiveMQ Presence) and **`🟢 WireGuard Connected`** (`10.77.x.x`). |

---

## ⚙️ CI/CD & Automated GitHub Actions Releases

1. **Zero Local Machine Build Requirement**: Compilation, testing, packaging, and release building happen exclusively on GitHub-hosted Actions runners (`ubuntu-latest`, `windows-latest`, `macos-latest`).
2. **CI Pipeline ([`ci.yml`](file:///.github/workflows/ci.yml))**: On every commit or pull request, runs `cargo fmt`, `cargo clippy`, `cargo test`, and `flutter analyze`.
3. **Release Pipeline ([`release.yml`](file:///.github/workflows/release.yml))**: Triggered automatically when a release tag (e.g. `v0.1.3`) is pushed to GitHub.

---

## 🚀 Releases & Downloads

👉 **[Download MeckChat Release Assets (v0.1.3)](https://github.com/Daksh159357/meckchat/releases/tag/v0.1.3)**

### Published Artifacts & Verified SHA-256 Checksums (`v0.1.3`):
* 📱 **Android**: `MeckChat-Android.apk` (94.8 MB) — `1758201f3169714b8c58b5f254940949af9331f1c93f8198f23fd461cd85b637`
* 💻 **Windows**: `MeckChat-Windows.zip` (19.6 MB) — `939b6df969500539a4793eae3b437af803aaf8999837eea8a4e053a93706c44c`
* 🐧 **Linux**: `MeckChat-Linux.tar.gz` (18.3 MB) — `2804ff0fd7fd0e08826910a133b7d4bafa2f68b9d1fffd520944cbdd11d9fa7c`
* 🍎 **macOS**: `MeckChat-macOS.zip` (96.0 MB) — `35166ff4e0458fe6ec26cbc4b0039b5366bd6e265d01797ab649ffebdf643ee5`
* 🔒 **Checksums**: `SHA256SUMS.txt`

---

## 🔒 Security Principles

* **WireGuard Private Key Safety**: Private keys are generated locally on first boot. They are **NEVER** sent over HiveMQ, included in QR codes, or output to logs (`#[serde(skip)]`).
* **Shared Secret Pairing**: Shared secrets use the **Argon2id** password hashing function to derive authentication tokens. Raw secrets are never sent across the network.
* **MQTT Data-Plane Isolation**: Zero chat messages, file bytes, audio, or video travel through MQTT. Verified by `assert_no_application_data()` assertions in Rust core.
* **Untrusted Infrastructure**: HiveMQ cannot access chat messages or files because zero user data passes through HiveMQ.
