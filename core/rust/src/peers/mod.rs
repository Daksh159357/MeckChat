use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum ConnectionState {
    Offline,
    Online,
    Connecting,
    Authenticating,
    ConfiguringWireGuard,
    EstablishingTunnel,
    Connected,
    Disconnected,
    ConnectionFailed(String),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PeerDevice {
    pub device_id: String,
    pub display_name: String,
    pub platform: String,
    pub wireguard_public_key: String,
    pub virtual_ip: String,
    pub is_paired: bool,
    pub connection_state: ConnectionState,
    pub last_seen: u64,
}

pub struct PeerRegistry {
    peers: HashMap<String, PeerDevice>,
}

impl PeerRegistry {
    pub fn new() -> Self {
        Self {
            peers: HashMap::new(),
        }
    }

    pub fn upsert_online_peer(&mut self, peer: PeerDevice) {
        self.peers.insert(peer.device_id.clone(), peer);
    }

    pub fn set_peer_offline(&mut self, device_id: &str) {
        if let Some(peer) = self.peers.get_mut(device_id) {
            peer.connection_state = ConnectionState::Offline;
        }
    }

    pub fn update_connection_state(&mut self, device_id: &str, state: ConnectionState) {
        if let Some(peer) = self.peers.get_mut(device_id) {
            peer.connection_state = state;
        }
    }

    pub fn get_online_peers(&self) -> Vec<PeerDevice> {
        self.peers.values().cloned().collect()
    }

    pub fn get_peer(&self, device_id: &str) -> Option<&PeerDevice> {
        self.peers.get(device_id)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_peer_registry() {
        let mut registry = PeerRegistry::new();
        let peer = PeerDevice {
            device_id: "dev1".into(),
            display_name: "Daksh-Laptop".into(),
            platform: "Linux".into(),
            wireguard_public_key: "pub123".into(),
            virtual_ip: "10.77.0.4".into(),
            is_paired: true,
            connection_state: ConnectionState::Online,
            last_seen: 1000,
        };

        registry.upsert_online_peer(peer.clone());
        assert_eq!(registry.get_online_peers().len(), 1);

        registry.update_connection_state("dev1", ConnectionState::Connected);
        assert_eq!(
            registry.get_peer("dev1").unwrap().connection_state,
            ConnectionState::Connected
        );
    }
}
