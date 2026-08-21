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
* **HiveMQ carries ONLY**: Device online/offline presence, public key exchange, connection signaling, and NAT endpoint metadata.
* **WireGuard carries ALL**: End-to-end encrypted chat messages, file contents, photos, videos, audio, and WebRTC real-time media streams.

---

## 📊 Feature Implementation Status

| Feature / Subsystem | Implementation Status | Notes |
| :--- | :--- | :--- |
| **Device Identity & Crypto** | **IMPLEMENTED** | X25519 WireGuard keypairs, SHA-256 Device IDs, `10.77.x.y` IP generator. Private keys never leave the device. |
| **MQTT Signaling (HiveMQ)** | **IMPLEMENTED** | Presence broadcasting (`online`/`offline`), Last Will and Testament (LWT), TLS 8883 support via `rumqttc`. |
| **Argon2id Pairing KDF** | **IMPLEMENTED** | Password hashing for shared-secret pairing & QR payload serialization. |
| **SQLite Chat Persistence** | **IMPLEMENTED** | `rusqlite` database layer storing message history, statuses (`SENT`, `DELIVERED`, `READ`). |
| **Resumable File Engine** | **IMPLEMENTED** | 64KB chunk streaming, SHA-256 end-to-end verification, non-blocking chunk offsets. |
| **WireGuard Config Engine** | **IMPLEMENTED** | Rust configuration block generator with 25s keepalives for NAT traversal. |
| **WebRTC Signaling Helper** | **IMPLEMENTED** | SDP offer/answer and ICE candidate payload serializer in Rust core. |
| **Flutter Application UI** | **IMPLEMENTED** | Full UI screens for Devices, Chat, Files, Calls, QR Pairing, and Settings. |
| **Flutter ↔ Rust FFI Layer** | **PARTIALLY IMPLEMENTED** | Service abstraction & Dart models active; native dynamic library compilation linked via `flutter_rust_bridge`. |
| **Native VPN Driver Integration** | **PARTIALLY IMPLEMENTED** | WireGuard config generation complete; native OS TUN driver calls vary by platform. |
| **Direct WebRTC Stream** | **PLANNED** | WebRTC signaling complete; direct video/audio stream rendering over WireGuard. |

---

## ⚙️ How the GitHub Actions Build Works

1. **Zero Local Machine Build Requirement**: No compilation, packaging, or cross-compilation occurs locally on your laptop. Everything is built inside isolated GitHub-hosted Actions runners (`ubuntu-latest`, `windows-latest`, `macos-latest`).
2. **CI Pipeline ([`ci.yml`](file:///.github/workflows/ci.yml))**: On every commit or pull request, GitHub Actions installs Rust and Flutter, runs `cargo fmt`, `cargo clippy`, `cargo test`, `flutter analyze`, and unit tests.
3. **Release Pipeline ([`release.yml`](file:///.github/workflows/release.yml))**: Triggered automatically when a version tag (e.g. `v0.1.0`) is pushed to GitHub. Generates release bundles and automated SHA-256 checksums (`SHA256SUMS.txt`).

---

## 🚀 Releases & Downloads

To trigger a new automated release:
```bash
git tag -a v0.1.0 -m "Release v0.1.0"
git push origin v0.1.0
```

GitHub Actions spins up cross-platform runners and uploads binaries to:

👉 **[Download MeckChat Releases](https://github.com/Daksh159357/meckchat/releases)**

### Generated Release Artifacts & Checksums:
* 📱 **Android**: `MeckChat-Android.apk`
* 💻 **Windows**: `MeckChat-Windows.zip`
* 🐧 **Linux**: `MeckChat-Linux.tar.gz`
* 🍎 **macOS**: `MeckChat-macOS.zip`
* 🔒 **Checksums**: `SHA256SUMS.txt`

> **Note on iOS Distribution**: iOS applications require Apple Developer Program certificates and mobile provisioning profiles for device installation. To avoid distributing non-installable binaries, iOS builds are verified via macOS runners in CI rather than published as standalone un-signed release artifacts.

---

## 🔒 Security Principles

* **WireGuard Private Key Safety**: Private keys are generated locally on first boot. They are **NEVER** sent over HiveMQ, included in QR codes, or output to logs (`#[serde(skip)]`).
* **Shared Secret Pairing**: Shared secrets use the **Argon2id** password hashing function to derive authentication tokens. Raw secrets are never sent across the network.
* **Untrusted Infrastructure**: HiveMQ cannot access chat messages or files because zero user data passes through HiveMQ.

---

## 🌐 Global Internet & NAT Traversal Limitations

* WireGuard peer configurations include `PersistentKeepalive = 25` to maintain UDP NAT pinholes across routers and mobile CGNAT networks.
* In strict symmetric NAT or firewall environments, direct UDP hole punching may require static endpoint forwarding or external STUN/TURN signaling fallback. HiveMQ is **never** used as a relay fallback for application data.
