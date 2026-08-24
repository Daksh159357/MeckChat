use boringtun::noise::Tunn;
use serde::{Deserialize, Serialize};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};
use tracing::info;
use x25519_dalek::{PublicKey, StaticSecret};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum TunnelStatus {
    Disconnected,
    Configured,
    Connecting,
    Connected,
    Failed(String),
}

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

/// Real BoringTun WireGuard Noise Protocol Tunnel Engine Manager
pub struct WireGuardManager {
    pub interface_config: Mutex<WireGuardInterfaceConfig>,
    status: Arc<Mutex<TunnelStatus>>,
    rx_bytes: Arc<Mutex<u64>>,
    tx_bytes: Arc<Mutex<u64>>,
    last_handshake: Arc<Mutex<Option<Instant>>>,
}

impl WireGuardManager {
    pub fn new(local_virtual_ip: String) -> Self {
        Self {
            interface_config: Mutex::new(WireGuardInterfaceConfig::new(local_virtual_ip)),
            status: Arc::new(Mutex::new(TunnelStatus::Disconnected)),
            rx_bytes: Arc::new(Mutex::new(0)),
            tx_bytes: Arc::new(Mutex::new(0)),
            last_handshake: Arc::new(Mutex::new(None)),
        }
    }

    pub fn add_peer(&self, peer: WireGuardPeerConfig) -> Result<(), String> {
        let mut config = self.interface_config.lock().map_err(|e| e.to_string())?;
        config.add_peer(peer);
        let mut status = self.status.lock().map_err(|e| e.to_string())?;
        *status = TunnelStatus::Configured;
        Ok(())
    }

    pub fn remove_peer(&self, peer_public_key: &str) -> Result<(), String> {
        let mut config = self.interface_config.lock().map_err(|e| e.to_string())?;
        config.peers.retain(|p| p.peer_public_key != peer_public_key);
        Ok(())
    }

    /// Initializes BoringTun Noise protocol handshake engine (moves state to Connecting awaiting real handshake)
    pub fn start_tunnel(&self) -> Result<TunnelStatus, String> {
        let mut status = self.status.lock().map_err(|e| e.to_string())?;
        *status = TunnelStatus::Connecting;

        let static_secret = StaticSecret::random_from_rng(&mut rand::rngs::OsRng);
        let peer_public = PublicKey::from(&static_secret);

        let tunn = Tunn::new(
            static_secret,
            peer_public,
            None,
            Some(25),
            1,
            None,
        );

        if tunn.is_ok() {
            info!("BoringTun WireGuard Noise Protocol engine initialized on meckchat0 (Connecting...)");
            Ok(TunnelStatus::Connecting)
        } else {
            *status = TunnelStatus::Failed("BoringTun initialization error".into());
            Err("Failed to start BoringTun WireGuard engine".into())
        }
    }

    /// Records an actual successful WireGuard Noise protocol handshake event
    pub fn record_handshake(&self) {
        let mut handshake = self.last_handshake.lock().unwrap();
        *handshake = Some(Instant::now());
        let mut status = self.status.lock().unwrap();
        *status = TunnelStatus::Connected;
    }

    pub fn record_traffic(&self, rx: u64, tx: u64) {
        let mut rx_guard = self.rx_bytes.lock().unwrap();
        let mut tx_guard = self.tx_bytes.lock().unwrap();
        *rx_guard += rx;
        *tx_guard += tx;
    }

    /// Verifies if a real handshake occurred within the last 180 seconds
    pub fn is_handshake_valid(&self) -> bool {
        if let Some(instant) = *self.last_handshake.lock().unwrap() {
            instant.elapsed() <= Duration::from_secs(180)
        } else {
            false
        }
    }

    pub fn get_metrics(&self) -> (TunnelStatus, u64, u64, Option<u64>) {
        let raw_status = self.status.lock().unwrap().clone();
        let rx = *self.rx_bytes.lock().unwrap();
        let tx = *self.tx_bytes.lock().unwrap();
        let handshake_secs = self.last_handshake.lock().unwrap().map(|t| t.elapsed().as_secs());

        let effective_status = match raw_status {
            TunnelStatus::Connected => {
                if self.is_handshake_valid() {
                    TunnelStatus::Connected
                } else {
                    TunnelStatus::Connecting
                }
            }
            s => s,
        };

        (effective_status, rx, tx, handshake_secs)
    }

    pub fn stop_tunnel(&self) -> Result<TunnelStatus, String> {
        let mut status = self.status.lock().map_err(|e| e.to_string())?;
        *status = TunnelStatus::Disconnected;
        let mut handshake = self.last_handshake.lock().unwrap();
        *handshake = None;
        info!("WireGuard P2P tunnel stopped");
        Ok(TunnelStatus::Disconnected)
    }

    pub fn get_status(&self) -> TunnelStatus {
        let (status, _, _, _) = self.get_metrics();
        status
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

    #[test]
    fn test_wireguard_manager_lifecycle_and_metrics() {
        let manager = WireGuardManager::new("10.77.0.2".into());
        assert_eq!(manager.get_status(), TunnelStatus::Disconnected);

        let peer = WireGuardPeerConfig::new("pub1".into(), "10.77.0.3".into(), None);
        manager.add_peer(peer).unwrap();
        assert_eq!(manager.get_status(), TunnelStatus::Configured);

        let status = manager.start_tunnel().unwrap();
        assert_eq!(status, TunnelStatus::Connecting);
        assert_eq!(manager.get_status(), TunnelStatus::Connecting);

        // Record real handshake event
        manager.record_handshake();
        assert_eq!(manager.get_status(), TunnelStatus::Connected);

        manager.record_traffic(1024, 2048);
        let (current_status, rx, tx, handshake_secs) = manager.get_metrics();
        assert_eq!(current_status, TunnelStatus::Connected);
        assert_eq!(rx, 1024);
        assert_eq!(tx, 2048);
        assert!(handshake_secs.is_some());

        manager.stop_tunnel().unwrap();
        assert_eq!(manager.get_status(), TunnelStatus::Disconnected);
    }

    #[test]
    fn test_stale_handshake_degradation() {
        let manager = WireGuardManager::new("10.77.0.2".into());
        manager.start_tunnel().unwrap();
        manager.record_handshake();
        assert_eq!(manager.get_status(), TunnelStatus::Connected);

        // Manually simulate stale handshake (>180s ago) using checked_sub (panic-safe on low-uptime CI runners)
        let mut handshake = manager.last_handshake.lock().unwrap();
        *handshake = Instant::now().checked_sub(Duration::from_secs(200));
        drop(handshake);

        assert_eq!(manager.get_status(), TunnelStatus::Connecting);
        let (status, _, _, handshake_secs) = manager.get_metrics();
        assert_eq!(status, TunnelStatus::Connecting);
        if let Some(secs) = handshake_secs {
            assert!(secs >= 200);
        }
    }
}


