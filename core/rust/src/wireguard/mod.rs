use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WireGuardPeerConfig {
    pub peer_public_key: String,
    pub allowed_ips: Vec<String>,
    pub endpoint: Option<String>,
    pub persistent_keepalive: u16,
}

impl WireGuardPeerConfig {
    pub fn new(peer_public_key: String, virtual_ip: String, endpoint: Option<String>) -> Self {
        Self {
            peer_public_key,
            allowed_ips: vec![format!("{}/32", virtual_ip)],
            endpoint,
            persistent_keepalive: 25, // 25s keepalive for NAT/CGNAT traversal
        }
    }

    /// Generates standard WireGuard configuration block format
    pub fn to_wg_quick_peer_block(&self) -> String {
        let endpoint_str = match &self.endpoint {
            Some(ep) => format!("Endpoint = {}\n", ep),
            None => "".into(),
        };

        format!(
            "[Peer]\nPublicKey = {}\nAllowedIPs = {}\n{}PersistentKeepalive = {}\n",
            self.peer_public_key,
            self.allowed_ips.join(", "),
            endpoint_str,
            self.persistent_keepalive
        )
    }
}

pub struct WireGuardInterfaceConfig {
    pub interface_name: String,
    pub local_virtual_ip: String,
    pub listen_port: u16,
    pub peers: Vec<WireGuardPeerConfig>,
}

impl WireGuardInterfaceConfig {
    pub fn new(local_virtual_ip: String) -> Self {
        Self {
            interface_name: "meckchat0".into(),
            local_virtual_ip,
            listen_port: 51820,
            peers: Vec::new(),
        }
    }

    pub fn add_peer(&mut self, peer: WireGuardPeerConfig) {
        self.peers
            .retain(|p| p.peer_public_key != peer.peer_public_key);
        self.peers.push(peer);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_wg_peer_config_generation() {
        let peer = WireGuardPeerConfig::new(
            "peer_pub_key_xyz".into(),
            "10.77.0.3".into(),
            Some("203.0.113.5:51820".into()),
        );

        let block = peer.to_wg_quick_peer_block();
        assert!(block.contains("PublicKey = peer_pub_key_xyz"));
        assert!(block.contains("AllowedIPs = 10.77.0.3/32"));
        assert!(block.contains("Endpoint = 203.0.113.5:51820"));
        assert!(block.contains("PersistentKeepalive = 25"));
    }
}
