//
//  Ed25519Service.swift
//  arcHIVE Camera App
//
//  Ed25519 cryptographic service for C2PA manifest signing and blockchain identity
//

import Foundation
import CryptoKit

// Ed25519 KeyPair structure to replace the missing UniFFI type
struct Ed25519KeyPair {
    let privateKey: Data
    let publicKey: Data

    func getPrivateKey() -> [UInt8] {
        return Array(privateKey)
    }

    func getPublicKey() -> [UInt8] {
        return Array(publicKey)
    }

    func getPublicKeyHex() -> String {
        return publicKey.map { String(format: "%02x", $0) }.joined()
    }
}

// Native Ed25519 functions using CryptoKit as fallback
func generateKeypair() -> Ed25519KeyPair {
    let privateKey = Curve25519.Signing.PrivateKey()
    let publicKey = privateKey.publicKey

    return Ed25519KeyPair(
        privateKey: privateKey.rawRepresentation,
        publicKey: publicKey.rawRepresentation
    )
}

func signMessage(message: [UInt8], privateKey: [UInt8]) throws -> [UInt8] {
    let privateKeyData = Data(privateKey)
    let messageData = Data(message)

    let signingKey = try Curve25519.Signing.PrivateKey(rawRepresentation: privateKeyData)
    let signature = try signingKey.signature(for: messageData)

    return Array(signature)
}

func verifySignature(message: [UInt8], signature: [UInt8], publicKey: [UInt8]) -> Bool {
    do {
        let publicKeyData = Data(publicKey)
        let messageData = Data(message)
        let signatureData = Data(signature)

        let verifyingKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
        return verifyingKey.isValidSignature(signatureData, for: messageData)
    } catch {
        print("❌ Ed25519 signature verification failed: \(error)")
        return false
    }
}

class Ed25519Service: ObservableObject {
    static let shared = Ed25519Service()
    
    private var keypair: Ed25519KeyPair?
    private let keyURL: URL
    
    // Blockchain identity configuration
    let ethAddress = "0x39e281975c0593D1cA54120Af458976A55491F9B"
    
    private init() {
        // Set up the keypair storage location
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        keyURL = documentsDir.appendingPathComponent("ed25519_key.json")
        
        // Load or generate keypair on initialization
        loadOrGenerateKeypair()
    }
    
    // MARK: - Keypair Management
    
    /// Load existing keypair or generate a new one
    private func loadOrGenerateKeypair() {
        if let existingKeypair = loadKeypair(from: keyURL) {
            keypair = existingKeypair
            print("✅ Ed25519 keypair loaded from disk")
        } else {
            keypair = generateKeypair()
            saveKeypair(to: keyURL)
            print("✅ New Ed25519 keypair generated and saved")
        }
    }
    
    /// Save keypair to disk as JSON
    private func saveKeypair(to url: URL) {
        guard let keypair = keypair else {
            print("❌ No keypair to save")
            return
        }
        
        let publicKeyData = Data(keypair.getPublicKey())
        let privateKeyData = Data(keypair.getPrivateKey())
        
        let dict: [String: String] = [
            "public_key": publicKeyData.base64EncodedString(),
            "private_key": privateKeyData.base64EncodedString(),
            "eth_address": ethAddress,
            "created_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
            try jsonData.write(to: url)
            print("✅ Ed25519 keypair saved to: \(url.lastPathComponent)")
        } catch {
            print("❌ Failed to save keypair: \(error.localizedDescription)")
        }
    }
    
    /// Load keypair from disk
    private func loadKeypair(from url: URL) -> Ed25519KeyPair? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: String],
                  let pubStr = dict["public_key"],
                  let privStr = dict["private_key"],
                  let publicKeyData = Data(base64Encoded: pubStr),
                  let privateKeyData = Data(base64Encoded: privStr) else {
                print("❌ Invalid keypair file format")
                return nil
            }
            
            let publicKey = Array(publicKeyData)
            let privateKey = Array(privateKeyData)
            
            return Ed25519KeyPair(privateKey: Data(privateKey), publicKey: Data(publicKey))
        } catch {
            print("❌ Failed to load keypair: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Public API
    
    /// Get the current public key as base64 string
    func getPublicKeyBase64() -> String {
        guard let keypair = keypair else {
            print("❌ No keypair available")
            return ""
        }
        return Data(keypair.getPublicKey()).base64EncodedString()
    }
    
    /// Get the current public key as hex string
    func getPublicKeyHex() -> String {
        guard let keypair = keypair else {
            print("❌ No keypair available")
            return ""
        }
        return keypair.getPublicKeyHex()
    }
    
    /// Sign data and return base64 encoded signature
    func signData(_ data: Data) -> String? {
        guard let keypair = keypair else {
            print("❌ No keypair available for signing")
            return nil
        }
        
        do {
            let message = Array(data)
            let privateKey = keypair.getPrivateKey()
            let signature = try signMessage(message: message, privateKey: privateKey)
            return Data(signature).base64EncodedString()
        } catch {
            print("❌ Failed to sign data: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Sign JSON manifest data
    func signManifest(_ manifestData: Data) -> (signature: String, publicKey: String)? {
        guard let signature = signData(manifestData) else {
            return nil
        }
        
        let publicKey = getPublicKeyBase64()
        return (signature: signature, publicKey: publicKey)
    }
    
    /// Verify a signature against data
    func verifySignature(data: Data, signature: String, publicKey: String) -> Bool {
        guard let signatureData = Data(base64Encoded: signature),
              let publicKeyData = Data(base64Encoded: publicKey) else {
            print("❌ Invalid signature or public key format")
            return false
        }
        
        do {
            // Use CryptoKit for Ed25519 signature verification
            let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
            return publicKey.isValidSignature(signatureData, for: data)
        } catch {
            print("❌ Signature verification failed: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Calculate SHA256 hash of data
    func calculateManifestHash(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
    }
    
    /// Get keypair info for diagnostics
    func getKeypairInfo() -> [String: Any] {
        guard let keypair = keypair else {
            return ["status": "No keypair available"]
        }
        
        return [
            "status": "Available",
            "public_key_hex": keypair.getPublicKeyHex(),
            "public_key_base64": getPublicKeyBase64(),
            "eth_address": ethAddress,
            "key_file_exists": FileManager.default.fileExists(atPath: keyURL.path)
        ]
    }
    
    /// Regenerate keypair (for testing or key rotation)
    func regenerateKeypair() {
        keypair = generateKeypair()
        saveKeypair(to: keyURL)
        print("✅ Ed25519 keypair regenerated")
    }
}

// MARK: - Extensions for C2PA Integration

extension Ed25519Service {
    /// Create arcHIVE.identity assertion for C2PA manifest
    func createIdentityAssertion(manifestHash: String, tokenId: String = "TBD") -> [String: Any] {
        return [
            "label": "arcHIVE.identity",
            "data": [
                "eth_address": ethAddress,
                "manifest_hash": manifestHash,
                "token_id": tokenId,
                "signing_algorithm": "ed25519",
                "public_key": getPublicKeyBase64(),
                "created_at": ISO8601DateFormatter().string(from: Date())
            ]
        ]
    }
    
    /// Create C2PA signature structure
    func createC2PASignature(for data: Data) -> [String: Any]? {
        guard let signatureBase64 = signData(data) else {
            return nil
        }
        
        return [
            "algorithm": "ed25519",
            "value": signatureBase64,
            "public_key": getPublicKeyBase64(),
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
    }
}
