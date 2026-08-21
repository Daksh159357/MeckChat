# MeckChat P2P Protocol Specification (WireGuard Transport)

## Overview
All MeckChat application traffic (Chat, Resumable Files, WebRTC Media) flows strictly over the private WireGuard tunnel (`10.77.0.0/16` subnet).

---

## WireGuard Network Addressing
- **Subnet**: `10.77.0.0/16`
- **Port**: Default UDP `51820` (dynamically negotiated for NAT/CGNAT traversal)
- **Collision-Resistant VIP Assignment**: Derived from SHA-256 hash of device's WireGuard public key mapped onto host bytes of `10.77.x.y`.

---

## Frame Wire Format

Each P2P TCP packet over WireGuard starts with a 5-byte header:
```text
┌──────────────┬──────────────┬────────────────────────────┐
│ Magic (2B)   │ MsgType (1B) │ Payload Length (2B, BigE)  │
│  "MC" (0x4D43)│  0x01 - 0x10 │ uint16                     │
└──────────────┴──────────────┴────────────────────────────┘
```

### Message Types (`MsgType`):
- `0x01` - **CHAT_TEXT**: Text message payload (Message ID, Timestamp, Body)
- `0x02` - **CHAT_ACK**: Delivery/Read receipt
- `0x05` - **FILE_START**: Initiate file transfer (file_id, filename, total_size, sha256_hash, chunk_size=64KB)
- `0x06` - **FILE_CHUNK**: Binary file chunk (file_id, sequence_number, data)
- `0x07` - **FILE_CHUNK_ACK**: Acknowledge chunk received & verified
- `0x08` - **FILE_RESUME_REQ**: Query last confirmed chunk sequence for resumable transfers
- `0x09` - **FILE_RESUME_ACK**: Respond with missing chunk range
- `0x0A` - **FILE_END**: Conclude transfer & verify full SHA-256 hash
- `0x10` - **WEBRTC_SIGNAL**: P2P Audio/Video SDP/ICE candidate exchange

---

## File Chunking & Resumable Flow

```text
Sender (10.77.0.2)                             Receiver (10.77.0.3)
      │                                              │
      │ ─── FILE_START (file_id, total, sha256) ───► │
      │ ◄─── FILE_RESUME_ACK (start_offset=0) ────── │
      │                                              │
      │ ─── FILE_CHUNK #0 (64 KB) ─────────────────► │
      │ ─── FILE_CHUNK #1 (64 KB) ─────────────────► │
      │ ◄── FILE_CHUNK_ACK #1 ────────────────────── │
      │       [ Connection Interrupted ]             │
      │       [ WireGuard Tunnel Reconnect ]         │
      │                                              │
      │ ─── FILE_RESUME_REQ (file_id) ─────────────► │
      │ ◄── FILE_RESUME_ACK (resume_from_chunk=2) ── │
      │                                              │
      │ ─── FILE_CHUNK #2 (64 KB) ─────────────────► │
      │ ─── FILE_END (file_id, sha256) ────────────► │
      │ ◄── FILE_END_ACK (verified=true) ─────────── │
```
