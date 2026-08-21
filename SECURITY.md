# Security Policy & Architecture Guidelines

## Core Security Guarantee
MeckChat relies on a strict zero-trust separation between signaling (HiveMQ) and application data (WireGuard).

### 1. HiveMQ Zero-Trust Model
HiveMQ is treated as **completely untrusted infrastructure**. 
* **Allowed on HiveMQ**: Device online/offline status, device IDs, WireGuard public keys, NAT signaling, public endpoints.
* **FORBIDDEN on HiveMQ**: Chat messages, file payloads, media streams, WireGuard private keys, passwords, shared secrets in plaintext.

### 2. WireGuard Key Management
* WireGuard private keys are generated locally on device startup using standard X25519 elliptic curve cryptography.
* Private keys are stored strictly in OS platform secure storage (Keychain, Keystore, Encrypted DB).
* Private keys **NEVER** leave the local device, are **NEVER** included in QR codes, and are **NEVER** written to log files.

### 3. Pairing & Shared Secret Authentication
* Pairing relies on QR codes or out-of-band shared secrets.
* Raw shared secrets are never used directly as encryption keys.
* Key material is derived using **Argon2id** key derivation function (KDF) with high memory and iteration parameters.

### 4. Reporting Vulnerabilities
If you discover a security vulnerability within MeckChat, please open a confidential security report or contact security maintainers directly before public disclosure.
