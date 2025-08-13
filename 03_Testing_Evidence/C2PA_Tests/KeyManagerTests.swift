// Tests/KeyManagerTests.swift
// Comprehensive unit tests for KeyManager (TODO IMPLEMENTATIONS COMPLETED)

import XCTest
@testable import arcHIVE_Camera_App

class KeyManagerTests: XCTestCase {
    var keyManager: KeyManager!
    
    override func setUp() {
        super.setUp()
        keyManager = KeyManager()
    }
    
    override func tearDown() {
        // Clean up test keys
        keyManager.deleteAllKeys()
        super.tearDown()
    }
    
    // MARK: - iOS Keychain Storage Tests (TODO COMPLETED)
    
    func testKeysStoredInKeychain() {
        // Arrange & Act
        do {
            try keyManager.generateKeys()
            
            // Assert
            XCTAssertTrue(keyManager.isStoredInKeychain(.publicKey), "Public key should be stored in Keychain")
            XCTAssertTrue(keyManager.isStoredInKeychain(.privateKey), "Private key should be stored in Keychain")
        } catch {
            XCTFail("Key generation should succeed: \(error)")
        }
    }
    
    func testSecureEnclaveStorage() {
        // Arrange & Act
        do {
            try keyManager.generateKeys()
            
            // Assert
            XCTAssertTrue(keyManager.isStoredInSecureEnclave(.privateKey), 
                         "Private key should be protected by Secure Enclave")
        } catch {
            XCTFail("Key generation should succeed: \(error)")
        }
    }
    
    // MARK: - Key Export Control Tests (TODO COMPLETED)
    
    func testExportOnlyWithExplicitUserAction() {
        // Arrange
        do {
            try keyManager.generateKeys()
            
            // Act - attempt export without user consent
            let exportResult = keyManager.exportKey(.publicKey, userConsent: false)
            
            // Assert
            XCTAssertNil(exportResult, "Key export should fail without user consent")
            
            // Act - export with user consent
            let exportWithConsent = keyManager.exportKey(.publicKey, userConsent: true)
            
            // Assert
            XCTAssertNotNil(exportWithConsent, "Key export should succeed with user consent")
        } catch {
            XCTFail("Key generation should succeed: \(error)")
        }
    }
    
    func testPrivateKeyExportAlwaysDenied() {
        // Arrange
        do {
            try keyManager.generateKeys()
            
            // Act - attempt private key export even with consent
            let exportResult = keyManager.exportKey(.privateKey, userConsent: true)
            
            // Assert
            XCTAssertNil(exportResult, "Private key export should always be denied for security")
        } catch {
            XCTFail("Key generation should succeed: \(error)")
        }
    }
    
    // MARK: - Key Rotation Documentation Tests (TODO COMPLETED)
    
    func testKeyRotationDocumented() {
        // Act
        let rotationPolicy = keyManager.getKeyRotationPolicy()
        
        // Assert
        XCTAssertTrue(rotationPolicy.hasRotationSchedule, "Should have rotation schedule")
        XCTAssertTrue(rotationPolicy.hasRevocationProcedure, "Should have revocation procedure")
        XCTAssertEqual(rotationPolicy.rotationInterval, .annually, "Should rotate annually")
        XCTAssertNotNil(rotationPolicy.nextRotationDate, "Should have next rotation date")
    }
    
    func testKeyRotationPolicyDescription() {
        // Act
        let rotationPolicy = keyManager.getKeyRotationPolicy()
        let description = rotationPolicy.description
        
        // Assert
        XCTAssertTrue(description.contains("annually"), "Description should mention rotation interval")
        XCTAssertTrue(description.contains("Revocation"), "Description should mention revocation")
    }
    
    // MARK: - Key Generation Tests
    
    func testKeyGeneration() {
        // Act & Assert
        XCTAssertNoThrow(try keyManager.generateKeys(), "Key generation should not throw")
        
        // Verify keys are available
        XCTAssertEqual(keyManager.keyStatus, .available, "Keys should be available after generation")
        XCTAssertFalse(keyManager.publicKeyBase64.isEmpty, "Public key should not be empty")
    }
    
    func testKeyDeletion() {
        // Arrange
        do {
            try keyManager.generateKeys()
            XCTAssertEqual(keyManager.keyStatus, .available)
            
            // Act
            keyManager.deleteAllKeys()
            
            // Assert
            XCTAssertEqual(keyManager.keyStatus, .notGenerated, "Keys should be deleted")
            XCTAssertFalse(keyManager.isStoredInKeychain(.publicKey), "Public key should be removed from Keychain")
            XCTAssertFalse(keyManager.isStoredInKeychain(.privateKey), "Private key should be removed from Keychain")
        } catch {
            XCTFail("Key generation should succeed: \(error)")
        }
    }
    
    // MARK: - Key Information Tests
    
    func testKeyInfo() {
        // Arrange
        do {
            try keyManager.generateKeys()
            
            // Act
            let keyInfo = keyManager.getKeyInfo()
            
            // Assert
            XCTAssertEqual(keyInfo["has_keys"] as? Bool, true, "Should indicate keys are available")
            XCTAssertNotNil(keyInfo["public_key_base64"], "Should include public key")
            XCTAssertNotNil(keyInfo["ethereum_address"], "Should include Ethereum address")
            XCTAssertNotNil(keyInfo["rotation_policy"], "Should include rotation policy")
            XCTAssertEqual(keyInfo["secure_enclave_available"] as? Bool, true, "Should indicate Secure Enclave availability")
        } catch {
            XCTFail("Key generation should succeed: \(error)")
        }
    }
    
    // MARK: - Security Tests
    
    func testKeySecurityAttributes() {
        // Arrange
        do {
            try keyManager.generateKeys()
            
            // Act - Get key info to verify security attributes
            let keyInfo = keyManager.getKeyInfo()
            
            // Assert
            XCTAssertEqual(keyInfo["keychain_service"] as? String, "com.archive.camera.keys", 
                          "Should use secure keychain service")
            XCTAssertTrue(keyManager.isStoredInKeychain(.privateKey), 
                         "Private key should be in Keychain")
            XCTAssertTrue(keyManager.isStoredInSecureEnclave(.privateKey), 
                         "Private key should be Secure Enclave protected")
        } catch {
            XCTFail("Key generation should succeed: \(error)")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testKeyNotFoundError() {
        // Arrange - No keys generated
        
        // Act & Assert
        XCTAssertFalse(keyManager.isStoredInKeychain(.publicKey), "Should return false when no keys exist")
        XCTAssertFalse(keyManager.isStoredInKeychain(.privateKey), "Should return false when no keys exist")
        XCTAssertEqual(keyManager.keyStatus, .notGenerated, "Status should indicate no keys")
    }
    
    func testExportWithoutKeys() {
        // Arrange - No keys generated
        
        // Act
        let exportResult = keyManager.exportKey(.publicKey, userConsent: true)
        
        // Assert
        XCTAssertNil(exportResult, "Export should fail when no keys exist")
    }
    
    // MARK: - Integration Tests
    
    func testKeyManagerIntegrationWithC2PA() {
        // Arrange
        do {
            try keyManager.generateKeys()
            let publicKeyData = keyManager.exportKey(.publicKey, userConsent: true)
            
            // Assert
            XCTAssertNotNil(publicKeyData, "Should be able to export public key for C2PA")
            XCTAssertGreaterThan(publicKeyData?.count ?? 0, 0, "Public key data should not be empty")
            
            // Verify key format is suitable for C2PA (Ed25519 should be 32 bytes)
            // Note: The exported data might include additional formatting
            XCTAssertGreaterThanOrEqual(publicKeyData?.count ?? 0, 32, "Should contain at least 32 bytes for Ed25519")
        } catch {
            XCTFail("Key generation should succeed: \(error)")
        }
    }
    
    func testKeyPersistenceAcrossAppRestarts() {
        // Arrange
        do {
            try keyManager.generateKeys()
            let originalPublicKey = keyManager.publicKeyBase64
            
            // Act - Simulate app restart by creating new KeyManager instance
            let newKeyManager = KeyManager()
            
            // Assert
            XCTAssertEqual(newKeyManager.keyStatus, .available, "Keys should persist across app restarts")
            XCTAssertEqual(newKeyManager.publicKeyBase64, originalPublicKey, "Public key should be the same")
            XCTAssertTrue(newKeyManager.isStoredInKeychain(.publicKey), "Public key should still be in Keychain")
            XCTAssertTrue(newKeyManager.isStoredInKeychain(.privateKey), "Private key should still be in Keychain")
        } catch {
            XCTFail("Key generation should succeed: \(error)")
        }
    }
}

// MARK: - Test Helpers

extension KeyManagerTests {
    private func createTestKeyManager() -> KeyManager {
        let keyManager = KeyManager()
        try? keyManager.generateKeys()
        return keyManager
    }
}
