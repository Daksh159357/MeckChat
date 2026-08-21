use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum WebRtcSignalType {
    SdpOffer,
    SdpAnswer,
    IceCandidate,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WebRtcSignalingMessage {
    pub call_id: String,
    pub sender_device_id: String,
    pub target_device_id: String,
    pub signal_type: WebRtcSignalType,
    pub sdp_or_candidate: String,
    pub timestamp: u64,
}

impl WebRtcSignalingMessage {
    pub fn new_offer(call_id: String, sender: String, target: String, sdp: String) -> Self {
        Self {
            call_id,
            sender_device_id: sender,
            target_device_id: target,
            signal_type: WebRtcSignalType::SdpOffer,
            sdp_or_candidate: sdp,
            timestamp: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap_or_default()
                .as_secs(),
        }
    }

    pub fn new_answer(call_id: String, sender: String, target: String, sdp: String) -> Self {
        Self {
            call_id,
            sender_device_id: sender,
            target_device_id: target,
            signal_type: WebRtcSignalType::SdpAnswer,
            sdp_or_candidate: sdp,
            timestamp: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap_or_default()
                .as_secs(),
        }
    }

    pub fn new_ice_candidate(
        call_id: String,
        sender: String,
        target: String,
        candidate: String,
    ) -> Self {
        Self {
            call_id,
            sender_device_id: sender,
            target_device_id: target,
            signal_type: WebRtcSignalType::IceCandidate,
            sdp_or_candidate: candidate,
            timestamp: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap_or_default()
                .as_secs(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_webrtc_signaling_serialization() {
        let msg = WebRtcSignalingMessage::new_offer(
            "call_123".into(),
            "devA".into(),
            "devB".into(),
            "v=0\r\no=- 12345 2 IN IP4 10.77.0.2...".into(),
        );

        let json = serde_json::to_string(&msg).unwrap();
        assert!(json.contains("SdpOffer"));
        assert!(json.contains("10.77.0.2"));
    }
}
