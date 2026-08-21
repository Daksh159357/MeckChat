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
               ┌──────────┼──────────┐
               │          │          │
             Chat       Files      Media
```

### Absolute Separation Rule
* **HiveMQ carries ONLY**: Device online/offline presence (`PresenceOnline`/`PresenceOffline`), public key exchange, connection signaling, and NAT endpoint metadata.
* **WireGuard carries ALL**: End-to-end encrypted chat messages, file contents, photos, videos, audio, and WebRTC real-time media streams. Zero user data passes through HiveMQ.

---

## 📊 Feature & System Status Matrix (Phase 3 Audit)

| Feature / Subsystem | Status | Technical Details & Verification Evidence |
| :--- | :--- | :--- |
| **Device Identity & Cryptography** | **IMPLEMENTED** | Local X25519 keypair generation, SHA-256 Device IDs, `10.77.x.y` IP allocation. Private keys marked `#[serde(skip)]` and never leave local storage. |
| **Typed MQTT Presence & LWT** | **IMPLEMENTED** | Connects to HiveMQ TLS 8883 (`broker.hivemq.com`). Publishes online/offline presence, handles discovery (`meckchat/v1/discovery`), and sets Last Will & Testament (LWT). Verified zero user data over MQTT. |
| **Argon2id Shared-Secret Pairing** | **IMPLEMENTED** | KDF password hashing for shared secrets and QR code payload serialization. Raw secret never transmitted. QR payload excludes private keys. |
| **WireGuard Core Engine** | **IMPLEMENTED** | `WireGuardManager` runtime engine in Rust, `WireGuardPeerConfig` builder (`to_wg_quick_peer_block()`), and 25s keepalive settings for NAT traversal. |
| **Android Driver & Tunnel** | **PARTIALLY IMPLEMENTED** / **NOT VERIFIED** | Flutter UI & MQTT signaling functional in `MeckChat-Android.apk`. Native Android `VpnService` / WireGuard Go backend integration is partially implemented and requires physical device testing. |
| **Windows Driver & Tunnel** | **PARTIALLY IMPLEMENTED** / **NOT VERIFIED** | `MeckChat.exe` launches from `MeckChat-Windows.zip`. Wintun driver & `wireguard.exe` tunnel service layer is partially implemented and requires physical Windows hardware testing. |
| **Linux Driver & Tunnel** | **PARTIALLY IMPLEMENTED** / **NOT VERIFIED** | `MeckChat-Linux.tar.gz` app launches. `netlink`/`ip link`/`wg` driver helper functions exist in Rust core, but physical kernel interface creation requires sudo/root physical device testing. |
| **macOS Driver & Tunnel** | **NOT VERIFIED** | `MeckChat-macOS.zip` builds via CI. Apple Network Extension (`NETunnelProviderManager`) requires Apple Developer Program certificates & entitlement signing. |
| **iOS Driver & Tunnel** | **NOT VERIFIED** / **PLANNED** | iOS build verified via macOS CI runner. Standalone installable iOS binary requires Apple Developer signing profile. |
| **P2P WireGuard Chat** | **IMPLEMENTED** (Core) / **NOT VERIFIED** (Live Tunnel) | `WireGuardSocketTransport` UDP binding on `10.77.x.x` virtual IP with local SQLite (`rusqlite`) database history in Rust core. Live tunnel delivery requires OS WireGuard driver. |
| **P2P Resumable File Engine** | **IMPLEMENTED** (Core) / **NOT VERIFIED** (Live Tunnel) | 64KB chunk streaming, non-blocking chunk offset resumption, end-to-end SHA-256 validation implemented in Rust core. |
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
