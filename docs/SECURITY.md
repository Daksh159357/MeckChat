# Security & Cryptographic Design

## Key Principles

1. **Local Key Generation**:
   - WireGuard private keys are generated on device startup using local cryptographically secure random number generators (CSPRNG).
   - Keys are stored securely on the local device filesystem / OS secure enclave.
   - Private keys are **never** published to MQTT, transmitted over networks, or exported to logs (`#[serde(skip)]`).

2. **Argon2id Key Derivation for Shared Secrets**:
   - Shared secret pairing uses the **Argon2id** password hashing / KDF algorithm to protect against brute-force attack vectors.
   - Output derived keys authenticate connection signaling messages before establishing WireGuard peer configurations.
   - QR code serializations include only device ID, public key, and virtual IP (zero private keys or raw secrets in QR codes).

3. **SHA-256 File Integrity Verification**:
   - File chunking streams check chunk-level CRC32 and compute full-file SHA-256 hashes.
   - Files are verified upon transfer completion before rendering or opening on the receiving device.

4. **Zero Knowledge on Central Infrastructure & MQTT Data-Plane Isolation**:
   - HiveMQ cannot read or record user content because zero application data passes through HiveMQ.
   - Rust core enforces `SignalingMessage::assert_no_application_data()`, guaranteeing that no chat messages, file bytes, audio, or video streams are ever published to MQTT topics.
   - WireGuard tunnels provide end-to-end transport encryption independent of intermediate network paths.
