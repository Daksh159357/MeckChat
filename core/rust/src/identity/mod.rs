use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use x25519_dalek::{PublicKey, StaticSecret};
use rand::rngs::OsRng;
use std::fmt;

#[derive(Clone, Serialize, Deserialize)]
pub struct DeviceIdentity {
    pub device_id: String,
    pub device_name: String,
    pub platform: String,
    pub public_key: String,
    pub virtual_ip: String,
    #[serde(skip)]
    private_key_bytes: Vec<u8>,
}

impl fmt::Debug for DeviceIdentity {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("DeviceIdentity")
            .field("device_id", &self.device_id)
            .field("device_name", &self.device_name)
            .field("platform", &self.platform)
            .field("public_key", &self.public_key)
            .field("virtual_ip", &self.virtual_ip)
            .field("private_key", &"[REDACTED_SECRET]")
            .finish()
    }
}

impl DeviceIdentity {
    pub fn new(device_name: String, platform: String) -> Self {
        let secret = StaticSecret::random_from_rng(OsRng);
        let public = PublicKey::from(&secret);

        let public_key_bytes = public.as_bytes();
        let public_key_b64 = base64::Engine::encode(
            &base64::engine::general_purpose::STANDARD,
            public_key_bytes,
        );

        // Derive deterministic Device ID from SHA-256 of Public Key
        let mut hasher = Sha256::new();
        hasher.update(public_key_bytes);
        let device_id_bytes = hasher.finalize();
        let device_id = hex::encode(&device_id_bytes[..16]);

        // Derive collision-resistant Virtual IP in 10.77.0.0/16 subnet
        let ip_host3 = if device_id_bytes[0] == 0 {
            1
        } else {
            device_id_bytes[0]
        };
        let ip_host4 = if device_id_bytes[1] == 0 {
            2
        } else {
            device_id_bytes[1]
        };
        let virtual_ip = format!("10.77.{}.{}", ip_host3, ip_host4);

        Self {
            device_id,
            device_name,
            platform,
            public_key: public_key_b64,
            virtual_ip,
            private_key_bytes: secret.to_bytes().to_vec(),
        }
    }

    pub fn get_public_key(&self) -> &str {
        &self.public_key
    }

    pub fn get_virtual_ip(&self) -> &str {
        &self.virtual_ip
    }

    /// Verifies that private key is NEVER exposed in serialized representation
    pub fn assert_secret_safety(&self) -> bool {
        let serialized = serde_json::to_string(self).unwrap_or_default();
        !serialized.contains("private_key")
            && !serialized.contains(&hex::encode(&self.private_key_bytes))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_identity_generation() {
        let identity = DeviceIdentity::new("Daksh-PC".into(), "Windows".into());
        assert!(!identity.device_id.is_empty());
        assert!(identity.virtual_ip.starts_with("10.77."));
        assert!(identity.assert_secret_safety());
    }
}
