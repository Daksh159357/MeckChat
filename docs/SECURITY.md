# Security & Cryptographic Design

## Key Principles

1. **Local Key Generation**:
   - WireGuard private keys are generated on device startup using local cryptographically secure random number generators (CSPRNG).
   - Keys are stored securely on the local device filesystem / OS secure enclave.
   - Private keys are **never** published to MQTT, transmitted over networks, or exported to logs (`#[serde(skip)]`).

2. **Argon2id Key Derivation for Shared Secrets & Replay Protection**:
   - Shared secret pairing uses the **Argon2id** password hashing / SHA-256 HMAC algorithm.
   - Authentication proof calculation strictly binds: `shared_secret`, random `salt`, `sender_device_id`, `receiver_device_id`, and `timestamp`.
   - **Expiration & Replay Attack Prevention**:
     - Requests older than 300 seconds (`timestamp > 300s`) are rejected (`PAIR_REJECT`).
     - In-memory cache of processed `request_id`s rejects duplicate replayed requests.
     - Receiver device ID verification (`receiver_device_id == localDevice.deviceId`).
   - QR code serializations include only device ID, public key, and virtual IP (zero private keys or raw secrets in QR codes).

3. **SHA-256 File Integrity Verification**:
   - File chunking streams check chunk-level CRC32 and compute full-file SHA-256 hashes.
   - Files are verified upon transfer completion before rendering or opening on the receiving device.

4. **Zero Knowledge on Central Infrastructure & MQTT Data-Plane Isolation**:
   - HiveMQ cannot read or record user content because zero application data passes through HiveMQ.
   - Rust core enforces `SignalingMessage::assert_no_application_data()`, and Dart `MqttService` enforces `assertNoChatDataInMqtt()`, guaranteeing that no chat messages, file bytes, audio, or video streams are ever published to MQTT topics.
   - WireGuard tunnels (`10.77.0.0/16`) provide end-to-end transport encryption independent of intermediate network paths.

5. **Chat Connection Guard & Offline Storage Isolation**:
   - Chat messages can ONLY be transmitted over the WireGuard P2P socket when `wireguardStatus == Connected`.
   - If WireGuard is disconnected, messages are stored locally in SQLite with status `PENDING` and UI status `"Waiting for secure connection"`. Zero fallback to MQTT.
   - Pending offline messages auto-flush over the WireGuard P2P socket when the tunnel status transitions to `Connected`.
