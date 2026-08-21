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

### Absolute Separation Rule
* **HiveMQ carries ONLY**: Device online/offline presence, public key exchange, connection signaling, and NAT endpoint metadata.
* **WireGuard carries ALL**: End-to-end encrypted chat messages, file contents, photos, videos, audio, and WebRTC real-time media streams.

---

## 🛠️ Technology Stack

| Layer | Technology |
| ----- | ---------- |
| **UI Application** | Flutter (Dart) |
| **Core Engine** | Rust (`core/rust`) |
| **Flutter ↔ Rust Bridge** | `flutter_rust_bridge` |
| **Private Tunnel Networking** | WireGuard (`10.77.0.0/16`) |
| **Signaling & Presence** | MQTT (HiveMQ `broker.hivemq.com` TLS 8883) |
| **Pairing KDF** | Argon2id + QR Code Metadata |
| **File Integrity** | SHA-256 (Resumable 64KB Chunk Streams) |
| **Local Database** | SQLite |
| **Live Media Calls** | WebRTC (`flutter_webrtc`) |
| **CI/CD** | GitHub Actions Workflows |

---

## 📁 Repository Structure

```text
meckchat/
├── .github/
│   └── workflows/
│       ├── ci.yml               # Automated test/lint CI workflow
│       └── release.yml          # Cross-platform release build workflow
├── apps/
│   └── flutter/                 # Flutter UI application codebase
│       ├── lib/
│       │   ├── models/          # Device, Chat, FileTransfer models
│       │   ├── providers/       # Presence, Chat, FileTransfer, Settings providers
│       │   ├── screens/         # Devices, Chat, Files, Calls, Pairing, Settings UI
│       │   └── main.dart
│       └── pubspec.yaml
├── core/
│   └── rust/                    # Rust core networking & crypto engine
│       ├── src/
│       │   ├── identity/        # Local WG Keypair & 10.77.x.y Virtual IP generator
│       │   ├── pairing/         # Argon2id KDF & QR code payload encoder
│       │   ├── mqtt/            # HiveMQ client with Last Will & Testament (LWT)
│       │   ├── wireguard/       # WG peer config & keepalive generator
│       │   ├── chat/            # WireGuard E2E chat & SQLite history
│       │   ├── files/           # Chunked resumable file engine & SHA-256 checks
│       │   └── media/           # WebRTC signaling helper
│       └── Cargo.toml
├── protocol/
│   ├── MQTT_SPEC.md             # HiveMQ signaling namespace & JSON payloads
│   └── P2P_SPEC.md              # WireGuard binary header protocol
├── docs/
│   ├── ARCHITECTURE.md          # Network layer separation
│   └── SECURITY.md              # Zero-trust HiveMQ model & key protection
├── README.md
├── LICENSE
├── SECURITY.md
├── CONTRIBUTING.md
└── .gitignore
```

---

## ⚙️ How the GitHub Actions Build Works

1. **Zero Local Machine Build Requirement**: No compilation or packaging occurs locally. Everything is built isolated inside GitHub-hosted Actions runners (`ubuntu-latest`, `windows-latest`, `macos-latest`).
2. **CI Pipeline (`ci.yml`)**: On every commit or pull request, GitHub Actions installs Rust and Flutter, checks syntax formatting, runs `cargo test`, `cargo clippy`, `flutter analyze`, and unit tests.
3. **Release Pipeline (`release.yml`)**: Triggered automatically when a version tag (e.g. `v0.1.0`) is pushed to GitHub.

---

## 🚀 How Releases are Created & Where to Download

### Creating a Release (Tag-based):
To trigger a new build and release:
```bash
git tag -a v0.1.0 -m "Release v0.1.0"
git push origin v0.1.0
```

GitHub Actions will automatically spin up cross-platform runners to compile the binaries for Linux, Windows, Android, and macOS, and generate a new GitHub Release under:

👉 **[Download Latest MeckChat Releases](https://github.com/Daksh159357/meckchat/releases)**

### Generated Release Artifacts:
* 📱 **Android**: `meckchat-android-release.apk`
* 💻 **Windows**: `meckchat-windows-x64.zip`
* 🐧 **Linux**: `meckchat-linux-x64.tar.gz`
* 🍎 **macOS**: `meckchat-macos-x64.zip`

---

## 🔒 Security Principles

* **WireGuard Private Key Safety**: Private keys are generated locally on first boot and stored in secure storage. They are **NEVER** sent over HiveMQ, included in QR codes, or output to logs.
* **Shared Secret Pairing**: Shared secrets use the **Argon2id** password hashing function to derive authentication tokens. Raw secrets are never sent across the network.
* **Untrusted Infrastructure**: HiveMQ cannot access chat messages or files because zero user data passes through HiveMQ.
