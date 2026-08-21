use rumqttc::{AsyncClient, LastWill, MqttOptions, QoS, Transport};
use serde::{Deserialize, Serialize};
use std::time::Duration;
use tracing::{info, warn};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MqttConfig {
    pub host: String,
    pub port: u16,
    pub use_tls: bool,
    pub keep_alive_secs: u64,
}

impl Default for MqttConfig {
    fn default() -> Self {
        Self {
            host: "broker.hivemq.com".into(),
            port: 8883,
            use_tls: true,
            keep_alive_secs: 30,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OnlinePresencePayload {
    pub protocol_version: String,
    pub device_id: String,
    pub display_name: String,
    pub platform: String,
    pub wireguard_public_key: String,
    pub virtual_ip: String,
    pub timestamp: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OfflinePresencePayload {
    pub protocol_version: String,
    pub device_id: String,
    pub status: String,
    pub timestamp: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PairRequestPayload {
    pub sender_device_id: String,
    pub target_device_id: String,
    pub auth_token_hash: String,
    pub salt: String,
    pub timestamp: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PairAcceptPayload {
    pub sender_device_id: String,
    pub target_device_id: String,
    pub wireguard_public_key: String,
    pub virtual_ip: String,
    pub timestamp: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PairRejectPayload {
    pub sender_device_id: String,
    pub target_device_id: String,
    pub reason: String,
    pub timestamp: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WireGuardOfferPayload {
    pub sender_device_id: String,
    pub target_device_id: String,
    pub public_key: String,
    pub virtual_ip: String,
    pub public_endpoint: Option<String>,
    pub timestamp: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WireGuardAnswerPayload {
    pub sender_device_id: String,
    pub target_device_id: String,
    pub public_key: String,
    pub virtual_ip: String,
    pub public_endpoint: Option<String>,
    pub timestamp: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConnectionStatePayload {
    pub sender_device_id: String,
    pub target_device_id: String,
    pub state: String,
    pub timestamp: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "msg_type", content = "payload")]
pub enum SignalingMessage {
    PresenceOnline(OnlinePresencePayload),
    PresenceOffline(OfflinePresencePayload),
    PairRequest(PairRequestPayload),
    PairAccept(PairAcceptPayload),
    PairReject(PairRejectPayload),
    WireGuardOffer(WireGuardOfferPayload),
    WireGuardAnswer(WireGuardAnswerPayload),
    ConnectionState(ConnectionStatePayload),
}

impl SignalingMessage {
    /// Asserts that NO application content (chat messages, file bytes, media) can be present
    pub fn assert_no_application_data(&self) -> bool {
        let json_str = serde_json::to_string(self).unwrap_or_default();
        !json_str.contains("chat_message")
            && !json_str.contains("file_chunk")
            && !json_str.contains("file_bytes")
            && !json_str.contains("private_key")
    }
}

pub struct HiveMqSignalingClient {
    pub config: MqttConfig,
    pub device_id: String,
}

impl HiveMqSignalingClient {
    pub fn new(config: MqttConfig, device_id: String) -> Self {
        Self { config, device_id }
    }

    pub fn build_mqtt_options(&self) -> MqttOptions {
        let client_id = format!("meckchat_{}", self.device_id);
        let mut opts = MqttOptions::new(client_id, &self.config.host, self.config.port);
        opts.set_keep_alive(Duration::from_secs(self.config.keep_alive_secs));

        if self.config.use_tls {
            opts.set_transport(Transport::tls_with_default_config());
        }

        // Configure Last Will and Testament for unexpected disconnects
        let lwt_topic = format!("meckchat/v1/presence/offline/{}", self.device_id);
        let lwt_payload = serde_json::to_string(&OfflinePresencePayload {
            protocol_version: "1.0".into(),
            device_id: self.device_id.clone(),
            status: "offline".into(),
            timestamp: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap_or_default()
                .as_secs(),
        })
        .unwrap_or_default();

        let last_will = LastWill::new(lwt_topic, lwt_payload, QoS::AtLeastOnce, true);
        opts.set_last_will(last_will);

        opts
    }

    pub fn online_topic(&self) -> String {
        format!("meckchat/v1/presence/online/{}", self.device_id)
    }

    pub fn offline_topic(&self) -> String {
        format!("meckchat/v1/presence/offline/{}", self.device_id)
    }

    pub fn signal_topic(&self) -> String {
        format!("meckchat/v1/signal/{}", self.device_id)
    }

    pub fn discovery_topic() -> &'static str {
        "meckchat/v1/discovery"
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_mqtt_topic_structure() {
        let client = HiveMqSignalingClient::new(MqttConfig::default(), "dev123".into());
        assert_eq!(client.online_topic(), "meckchat/v1/presence/online/dev123");
        assert_eq!(
            client.offline_topic(),
            "meckchat/v1/presence/offline/dev123"
        );
        assert_eq!(client.signal_topic(), "meckchat/v1/signal/dev123");
    }

    #[test]
    fn test_signaling_message_data_plane_isolation() {
        let msg = SignalingMessage::WireGuardOffer(WireGuardOfferPayload {
            sender_device_id: "devA".into(),
            target_device_id: "devB".into(),
            public_key: "pubkey_wg_123".into(),
            virtual_ip: "10.77.0.2".into(),
            public_endpoint: Some("203.0.113.10:51820".into()),
            timestamp: 1724242920,
        });

        assert!(msg.assert_no_application_data());
        let json = serde_json::to_string(&msg).unwrap();
        assert!(!json.contains("private_key"));
        assert!(!json.contains("chat"));
    }
}
