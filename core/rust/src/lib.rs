pub mod chat;
pub mod files;
pub mod identity;
pub mod media;
pub mod mqtt;
pub mod networking;
pub mod pairing;
pub mod peers;
pub mod wireguard;

pub use chat::{ChatDatabase, ChatMessage, MessageStatus};
pub use files::{FileMetadata, ResumableFileTransfer, TransferStatus};
pub use identity::DeviceIdentity;
pub use mqtt::{HiveMqSignalingClient, MqttConfig, OnlinePresencePayload};
pub use pairing::{QRPairingPayload, SharedSecretPairing};
pub use peers::{ConnectionState, PeerDevice, PeerRegistry};
pub use wireguard::{WireGuardInterfaceConfig, WireGuardPeerConfig};

/// Version identifier of MeckChat core engine
pub fn meckchat_core_version() -> &'static str {
    "0.1.0"
}

/// FFI interface function to initialize a new local identity securely
pub fn init_device_identity(name: String, platform: String) -> String {
    let identity = DeviceIdentity::new(name, platform);
    serde_json::to_string(&identity).unwrap_or_default()
}
