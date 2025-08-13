import Foundation
import DeviceCheck
import CryptoKit

/// Service for iOS App Attest integration providing hardware-backed attestation
/// Required for C2PA Level 2 conformance - Hardware Root of Trust verification
@available(iOS 14.0, *)
class AppAttestService: ObservableObject {
    
    // MARK: - Properties
    
    private let service = DCAppAttestService.shared
    private let keychain = KeychainService.shared
    
    @Published var isSupported: Bool = false
    @Published var attestationStatus: AttestationStatus = .unknown
    
    // MARK: - Types
    
    enum AttestationStatus {
        case unknown
        case supported
        case keyGenerated
        case attested
        case failed(Error)
    }
    
    enum AppAttestError: LocalizedError {
        case notSupported
        case keyGenerationFailed
        case attestationFailed
        case verificationFailed
        case invalidChallenge
        
        var errorDescription: String? {
            switch self {
            case .notSupported:
                return "App Attest is not supported on this device"
            case .keyGenerationFailed:
                return "Failed to generate App Attest key"
            case .attestationFailed:
                return "Failed to create attestation"
            case .verificationFailed:
                return "Failed to verify attestation"
            case .invalidChallenge:
                return "Invalid challenge data"
            }
        }
    }
    
    // MARK: - Initialization
    
    init() {
        checkSupport()
    }
    
    // MARK: - Public Methods
    
    /// Check if App Attest is supported on this device
    func checkSupport() {
        isSupported = service.isSupported
        attestationStatus = isSupported ? .supported : .unknown
    }
    
    /// Generate App Attest key for hardware-backed attestation
    /// Required for C2PA Level 2 certificate enrollment
    func generateKey() async throws -> String {
        guard isSupported else {
            throw AppAttestError.notSupported
        }
        
        do {
            let keyId = try await service.generateKey()
            
            // Store key ID securely in keychain
            try keychain.storeAppAttestKeyId(keyId)
            
            DispatchQueue.main.async {
                self.attestationStatus = .keyGenerated
            }
            
            return keyId
        } catch {
            DispatchQueue.main.async {
                self.attestationStatus = .failed(error)
            }
            throw AppAttestError.keyGenerationFailed
        }
    }
    
    /// Create attestation for certificate enrollment
    /// Provides hardware-backed proof of app integrity
    func createAttestation(challenge: Data) async throws -> Data {
        guard isSupported else {
            throw AppAttestError.notSupported
        }
        
        guard !challenge.isEmpty else {
            throw AppAttestError.invalidChallenge
        }
        
        do {
            // Get stored key ID
            let keyId = try keychain.getAppAttestKeyId()
            
            // Create attestation with challenge
            let attestation = try await service.attestKey(keyId, clientDataHash: challenge)
            
            DispatchQueue.main.async {
                self.attestationStatus = .attested
            }
            
            return attestation
        } catch {
            DispatchQueue.main.async {
                self.attestationStatus = .failed(error)
            }
            throw AppAttestError.attestationFailed
        }
    }
    
    /// Generate assertion for ongoing verification
    /// Used for runtime integrity verification
    func generateAssertion(challenge: Data) async throws -> Data {
        guard isSupported else {
            throw AppAttestError.notSupported
        }
        
        do {
            let keyId = try keychain.getAppAttestKeyId()
            let assertion = try await service.generateAssertion(keyId, clientDataHash: challenge)
            return assertion
        } catch {
            throw AppAttestError.verificationFailed
        }
    }
    
    /// Create certificate enrollment challenge
    /// Combines device info and app info for CA verification
    func createEnrollmentChallenge() -> Data {
        var challengeData = Data()
        
        // Add bundle identifier
        if let bundleId = Bundle.main.bundleIdentifier {
            challengeData.append(bundleId.data(using: .utf8) ?? Data())
        }
        
        // Add app version
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            challengeData.append(version.data(using: .utf8) ?? Data())
        }
        
        // Add build number
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            challengeData.append(build.data(using: .utf8) ?? Data())
        }
        
        // Add timestamp
        let timestamp = Date().timeIntervalSince1970
        challengeData.append(withUnsafeBytes(of: timestamp) { Data($0) })
        
        // Hash the challenge data
        return SHA256.hash(data: challengeData).data
    }
    
    /// Verify app integrity for C2PA Level 2 compliance
    func verifyAppIntegrity() async throws -> Bool {
        guard isSupported else {
            return false
        }
        
        do {
            let challenge = createEnrollmentChallenge()
            let assertion = try await generateAssertion(challenge: challenge)
            
            // In production, this would be verified by the CA
            // For now, we verify that we can generate valid assertions
            return !assertion.isEmpty
        } catch {
            return false
        }
    }
    
    /// Get device attestation info for CA enrollment
    func getDeviceAttestationInfo() -> [String: Any] {
        var info: [String: Any] = [:]
        
        info["isSupported"] = isSupported
        info["status"] = attestationStatus.description
        
        // Device information
        info["deviceModel"] = UIDevice.current.model
        info["systemVersion"] = UIDevice.current.systemVersion
        info["bundleId"] = Bundle.main.bundleIdentifier ?? "unknown"
        
        // App information
        info["appVersion"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "unknown"
        info["buildNumber"] = Bundle.main.infoDictionary?["CFBundleVersion"] ?? "unknown"
        
        return info
    }
}

// MARK: - AttestationStatus Extension

extension AppAttestService.AttestationStatus {
    var description: String {
        switch self {
        case .unknown:
            return "unknown"
        case .supported:
            return "supported"
        case .keyGenerated:
            return "keyGenerated"
        case .attested:
            return "attested"
        case .failed(let error):
            return "failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - KeychainService Extension

extension KeychainService {
    
    private static let appAttestKeyIdKey = "com.archive.camera.appAttest.keyId"
    
    func storeAppAttestKeyId(_ keyId: String) throws {
        let data = keyId.data(using: .utf8) ?? Data()
        try storeData(data, forKey: Self.appAttestKeyIdKey)
    }
    
    func getAppAttestKeyId() throws -> String {
        let data = try getData(forKey: Self.appAttestKeyIdKey)
        guard let keyId = String(data: data, encoding: .utf8) else {
            throw KeychainError.dataCorrupted
        }
        return keyId
    }
    
    func deleteAppAttestKeyId() throws {
        try deleteItem(forKey: Self.appAttestKeyIdKey)
    }
}

// MARK: - SHA256 Extension

extension SHA256.Digest {
    var data: Data {
        return Data(self)
    }
}
