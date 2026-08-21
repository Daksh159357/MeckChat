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

## 📊 Phase 2 Implementation & Platform Matrix

| Feature / Subsystem | Implementation Status | Verification & Evidence |
| :--- | :--- | :--- |
| **Device Identity & Cryptography** | **IMPLEMENTED** | Local X25519 keypair generation, SHA-256 Device IDs, `10.77.x.y` IP allocation. Private keys marked `#[serde(skip)]`. |
| **Typed MQTT Signaling** | **IMPLEMENTED** | Explicit typed signaling payloads (`PRESENCE_ONLINE`, `PAIR_REQUEST`, `WIREGUARD_OFFER`). Zero application content via MQTT verified by unit tests. |
| **Argon2id Secret Pairing** | **IMPLEMENTED** | KDF password hashing for shared secrets and QR code payload serialization. Raw secret never transmitted. |
| **WireGuard Core Engine** | **IMPLEMENTED** | `WireGuardManager` runtime engine, status state machine (`Disconnected`, `Configured`, `Connected`), 25s keepalives for NAT pinholes. |
| **Linux WireGuard Driver** | **IMPLEMENTED** | Native `netlink` / `ip link` / `wg` device interface helper configuration. |
| **Windows WireGuard Driver** | **PARTIALLY IMPLEMENTED** | Wintun driver & `wireguard.exe` tunnel service abstraction layer. |
| **Android WireGuard Driver** | **PARTIALLY IMPLEMENTED** | Android `VpnService` / WireGuard Android SDK integration specification. |
| **macOS / iOS Driver** | **REQUIRES APPLE SIGNING** | Apple Network Extension (`NETunnelProviderManager`) architecture & developer entitlements specification. |
| **P2P WireGuard Chat** | **IMPLEMENTED** | `WireGuardSocketTransport` UDP binding on `10.77.x.x` virtual IP with local SQLite (`rusqlite`) database history. |
| **P2P Resumable File Engine** | **IMPLEMENTED** | 64KB chunk streaming, non-blocking chunk offset resumption, end-to-end SHA-256 validation. |
| **WebRTC Media Signaling** | **IMPLEMENTED** | SDP offer/answer and ICE candidate payload serializer in Rust core. |
| **Flutter UI Connection State** | **IMPLEMENTED** | Visual distinction between **`🟢 Online`** (HiveMQ Presence) and **`🟢 WireGuard Connected`** (`10.77.x.x`). |

---

## ⚙️ How the GitHub Actions Build Works

1. **Zero Local Machine Build Requirement**: No compilation, packaging, or cross-compilation occurs locally on your laptop. Everything is built inside isolated GitHub-hosted Actions runners (`ubuntu-latest`, `windows-latest`, `macos-latest`).
2. **CI Pipeline ([`ci.yml`](file:///.github/workflows/ci.yml))**: On every commit or pull request, GitHub Actions installs Rust and Flutter, runs `cargo fmt`, `cargo clippy`, `cargo test`, `flutter analyze`, and unit tests.
3. **Release Pipeline ([`release.yml`](file:///.github/workflows/release.yml))**: Triggered automatically when a version tag (e.g. `v0.1.2`) is pushed to GitHub. Generates release bundles and automated SHA-256 checksums (`SHA256SUMS.txt`).

---

## 🚀 Releases & Downloads

To trigger a new automated release:
```bash
git tag -a v0.1.2 -m "Release v0.1.2 Phase 2 P2P Runtime"
git push origin v0.1.2
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
