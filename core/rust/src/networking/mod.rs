use std::net::SocketAddr;
use tokio::net::UdpSocket;
use tracing::info;

pub struct WireGuardSocketTransport {
    pub local_addr: SocketAddr,
}

impl WireGuardSocketTransport {
    pub fn new(local_virtual_ip: &str, port: u16) -> Result<Self, String> {
        let addr_str = format!("{}:{}", local_virtual_ip, port);
        let local_addr: SocketAddr = addr_str.parse().map_err(|e: std::net::AddrParseError| e.to_string())?;
        Ok(Self { local_addr })
    }

    pub async fn bind_listener(&self) -> Result<UdpSocket, String> {
        let socket = UdpSocket::bind(self.local_addr)
            .await
            .map_err(|e| format!("Failed to bind WireGuard P2P socket: {}", e))?;
        info!("WireGuard P2P transport listening on {}", self.local_addr);
        Ok(socket)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_socket_addr_parsing() {
        let transport = WireGuardSocketTransport::new("127.0.0.1", 51820).unwrap();
        assert_eq!(transport.local_addr.port(), 51820);
    }
}
