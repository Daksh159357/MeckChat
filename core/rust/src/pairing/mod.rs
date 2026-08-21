use argon2::{
    password_hash::{rand_core::OsRng, PasswordHasher, SaltString},
    Argon2,
};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QRPairingPayload {
    pub protocol_version: String,
    pub device_id: String,
    pub display_name: String,
    pub platform: String,
    pub wireguard_public_key: String,
    pub virtual_ip: String,
    pub pairing_metadata: String,
}

impl QRPairingPayload {
    pub fn new(
        device_id: String,
        display_name: String,
        platform: String,
        wireguard_public_key: String,
        virtual_ip: String,
    ) -> Self {
        Self {
            protocol_version: "1.0".into(),
            device_id,
            display_name,
            platform,
            wireguard_public_key,
            virtual_ip,
            pairing_metadata: "meckchat_p2p_v1".into(),
        }
    }

    pub fn to_json(&self) -> Result<String, String> {
        serde_json::to_string(self).map_err(|e| e.to_string())
    }

    pub fn from_json(json_str: &str) -> Result<Self, String> {
        let payload: Self = serde_json::from_str(json_str).map_err(|e| e.to_string())?;
        if payload.wireguard_public_key.is_empty() || payload.device_id.is_empty() {
            return Err("Invalid QR pairing payload: missing critical parameters".into());
        }
        Ok(payload)
    }
}

pub struct SharedSecretPairing;

impl SharedSecretPairing {
    /// Derives an authentication token using Argon2id from a raw shared secret
    pub fn derive_auth_token(shared_secret: &str, salt: Option<&str>) -> Result<(String, String), String> {
        let salt_string = match salt {
            Some(s) => SaltString::from_b64(s).map_err(|e| e.to_string())?,
            None => SaltString::generate(&mut OsRng),
        };

        let argon2 = Argon2::default();
        let password_hash = argon2
            .hash_password(shared_secret.as_bytes(), &salt_string)
            .map_err(|e| e.to_string())?;

        Ok((password_hash.to_string(), salt_string.to_string()))
    }

    /// Verifies an incoming auth token against the local shared secret via Argon2id
    pub fn verify_shared_secret(shared_secret: &str, hash_str: &str) -> bool {
        use argon2::password_hash::PasswordVerifier;
        use argon2::PasswordHash;

        let parsed_hash = match PasswordHash::new(hash_str) {
            Ok(h) => h,
            Err(_) => return false,
        };

        Argon2::default()
            .verify_password(shared_secret.as_bytes(), &parsed_hash)
            .is_ok()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_qr_payload_serde() {
        let payload = QRPairingPayload::new(
            "dev123".into(),
            "Daksh-Phone".into(),
            "Android".into(),
            "wg_pub_key_123".into(),
            "10.77.0.3".into(),
        );
        let json = payload.to_json().unwrap();
        assert!(!json.contains("private"));
        assert!(!json.contains("secret"));

        let decoded = QRPairingPayload::from_json(&json).unwrap();
        assert_eq!(decoded.device_id, "dev123");
    }

    #[test]
    fn test_argon2id_pairing() {
        let secret = "MECKCHAT123";
        let (hash, _salt) = SharedSecretPairing::derive_auth_token(secret, None).unwrap();
        assert!(SharedSecretPairing::verify_shared_secret(secret, &hash));
        assert!(!SharedSecretPairing::verify_shared_secret(
            "WRONG_SECRET",
            &hash
        ));
    }
}
