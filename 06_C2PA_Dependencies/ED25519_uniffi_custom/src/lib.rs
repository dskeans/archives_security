use ed25519_dalek::{Signature, Signer, SigningKey, Verifier, VerifyingKey};
use rand::rngs::OsRng;
use std::sync::Arc;
use thiserror::Error;

// Error types for proper error handling
#[derive(Error, Debug, uniffi::Error)]
pub enum Ed25519Error {
    #[error("Invalid private key: {reason}")]
    InvalidPrivateKey { reason: String },
    #[error("Invalid public key: {reason}")]
    InvalidPublicKey { reason: String },
    #[error("Invalid signature: {reason}")]
    InvalidSignature { reason: String },
    #[error("Signing failed: {reason}")]
    SigningFailed { reason: String },
    #[error("Verification failed: {reason}")]
    VerificationFailed { reason: String },
}

// Key pair structure
#[derive(uniffi::Object)]
pub struct Ed25519KeyPair {
    pub public_key: Vec<u8>,
    pub private_key: Vec<u8>,
}

#[uniffi::export]
impl Ed25519KeyPair {
    /// Create a new KeyPair with the given public and private keys
    #[uniffi::constructor]
    pub fn new(public_key: Vec<u8>, private_key: Vec<u8>) -> Arc<Self> {
        Arc::new(Self {
            public_key,
            private_key,
        })
    }

    /// Get the public key bytes
    pub fn get_public_key(&self) -> Vec<u8> {
        self.public_key.clone()
    }

    /// Get the private key bytes
    pub fn get_private_key(&self) -> Vec<u8> {
        self.private_key.clone()
    }

    /// Get the public key as a hex string
    pub fn get_public_key_hex(&self) -> String {
        hex::encode(&self.public_key)
    }

    /// Get the private key as a hex string
    pub fn get_private_key_hex(&self) -> String {
        hex::encode(&self.private_key)
    }
}

/// Generate a new ed25519 key pair
#[uniffi::export]
pub fn generate_keypair() -> Arc<Ed25519KeyPair> {
    use rand::RngCore;
    
    let mut rng = OsRng;
    let mut secret_key_bytes = [0u8; 32];
    rng.fill_bytes(&mut secret_key_bytes);
    
    let signing_key = SigningKey::from_bytes(&secret_key_bytes);
    let verifying_key = signing_key.verifying_key();
    
    let private_key = secret_key_bytes.to_vec();
    let public_key = verifying_key.to_bytes().to_vec();
    
    Arc::new(Ed25519KeyPair {
        public_key,
        private_key,
    })
}

/// Sign a message with the given private key
#[uniffi::export]
pub fn sign_message(message: Vec<u8>, private_key: Vec<u8>) -> Result<Vec<u8>, Ed25519Error> {
    if private_key.len() != 32 {
        return Err(Ed25519Error::InvalidPrivateKey {
            reason: format!("Private key must be exactly 32 bytes, got {}", private_key.len()),
        });
    }

    let mut key_bytes = [0u8; 32];
    key_bytes.copy_from_slice(&private_key);
    
    let signing_key = SigningKey::from_bytes(&key_bytes);
    let signature = signing_key.sign(&message);
    
    Ok(signature.to_bytes().to_vec())
}

/// Verify a signature against a message and public key
#[uniffi::export]
pub fn verify_signature(
    message: Vec<u8>,
    signature: Vec<u8>,
    public_key: Vec<u8>,
) -> Result<bool, Ed25519Error> {
    if public_key.len() != 32 {
        return Err(Ed25519Error::InvalidPublicKey {
            reason: format!("Public key must be exactly 32 bytes, got {}", public_key.len()),
        });
    }

    if signature.len() != 64 {
        return Err(Ed25519Error::InvalidSignature {
            reason: format!("Signature must be exactly 64 bytes, got {}", signature.len()),
        });
    }

    let mut pub_key_bytes = [0u8; 32];
    pub_key_bytes.copy_from_slice(&public_key);
    
    let mut sig_bytes = [0u8; 64];
    sig_bytes.copy_from_slice(&signature);

    let verifying_key = VerifyingKey::from_bytes(&pub_key_bytes)
        .map_err(|e| Ed25519Error::InvalidPublicKey {
            reason: e.to_string(),
        })?;

    let signature = Signature::from_bytes(&sig_bytes);

    match verifying_key.verify(&message, &signature) {
        Ok(()) => Ok(true),
        Err(_) => Ok(false),
    }
}

/// Create a keypair from existing private key bytes
#[uniffi::export]
pub fn keypair_from_private_key(private_key: Vec<u8>) -> Result<Arc<Ed25519KeyPair>, Ed25519Error> {
    if private_key.len() != 32 {
        return Err(Ed25519Error::InvalidPrivateKey {
            reason: format!("Private key must be exactly 32 bytes, got {}", private_key.len()),
        });
    }

    let mut key_bytes = [0u8; 32];
    key_bytes.copy_from_slice(&private_key);
    
    let signing_key = SigningKey::from_bytes(&key_bytes);
    let verifying_key = signing_key.verifying_key();
    
    let public_key = verifying_key.to_bytes().to_vec();
    
    Ok(Arc::new(Ed25519KeyPair {
        public_key,
        private_key,
    }))
}

// UniFFI setup
uniffi::setup_scaffolding!();