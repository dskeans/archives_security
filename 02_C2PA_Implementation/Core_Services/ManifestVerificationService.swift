//
//  ManifestVerificationService.swift
//  arcHIVE Camera App
//
//  Comprehensive manifest verification with local and remote endpoint support
//  iOS 17+ compatible with modern networking and async/await
//

import Foundation
import SwiftUI
import Network

/// Verification endpoint result
struct VerificationEndpointResult {
    let isValid: Bool
    let source: VerificationSource
    let timestamp: Date
    let details: [String]
    let errors: [String]
    
    enum VerificationSource {
        case local
        case remote
        case cached
    }
}

/// Manifest verification service with endpoint support
@MainActor
class ManifestVerificationService: ObservableObject {
    static let shared = ManifestVerificationService()
    
    @Published var isVerifying = false
    @Published var verificationHistory: [VerificationEndpointResult] = []
    @Published var networkStatus: NetworkStatus = .unknown
    
    // Remote verification endpoints
    private let remoteEndpoints = [
        "https://verify.c2pa.org/api/v1/verify",
        "https://contentauthenticity.org/verify"
    ]
    
    private let networkMonitor = NWPathMonitor()
    private let verificationQueue = DispatchQueue(label: "verification.queue")
    
    enum NetworkStatus {
        case available
        case unavailable
        case unknown
    }
    
    private init() {
        startNetworkMonitoring()
    }
    
    // MARK: - Network Monitoring
    
    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.networkStatus = path.status == .satisfied ? .available : .unavailable
            }
        }
        networkMonitor.start(queue: verificationQueue)
    }
    
    // MARK: - Comprehensive Verification
    
    /// Perform comprehensive manifest verification with local and remote endpoints
    func verifyManifest(for mediaItem: MediaItem) async -> VerificationEndpointResult {
        isVerifying = true
        defer { isVerifying = false }
        
        var details: [String] = []
        var errors: [String] = []
        
        // Step 1: Local verification
        details.append("Starting local verification...")
        let localResult = await performLocalVerification(mediaItem: mediaItem)
        
        if localResult.isValid {
            details.append("✅ Local verification: PASSED")
            details.append(contentsOf: localResult.details)
            
            // If local verification passes and remote is enabled, try remote verification
            if AppSettings.shared.remoteVerificationEnabled && networkStatus == .available {
                details.append("Attempting remote verification...")
                let remoteResult = await performRemoteVerification(mediaItem: mediaItem)
                
                if remoteResult.isValid {
                    details.append("✅ Remote verification: PASSED")
                    details.append(contentsOf: remoteResult.details)
                } else {
                    details.append("⚠️ Remote verification: FAILED (using local result)")
                    details.append(contentsOf: remoteResult.errors)
                }
            }
        } else {
            details.append("❌ Local verification: FAILED")
            errors.append(contentsOf: localResult.errors)
        }
        
        let result = VerificationEndpointResult(
            isValid: localResult.isValid,
            source: .local,
            timestamp: Date(),
            details: details,
            errors: errors
        )
        
        verificationHistory.append(result)
        return result
    }
    
    // MARK: - Local Verification
    
    private func performLocalVerification(mediaItem: MediaItem) async -> VerificationEndpointResult {
        var details: [String] = []
        var errors: [String] = []
        var isValid = true
        
        // Check if manifest exists
        guard let manifest = mediaItem.c2paManifest else {
            errors.append("No C2PA manifest found")
            return VerificationEndpointResult(
                isValid: false,
                source: .local,
                timestamp: Date(),
                details: details,
                errors: errors
            )
        }
        
        details.append("C2PA manifest found")
        
        // Verify manifest structure
        if manifest.claimGenerator == nil {
            errors.append("Missing claim generator")
            isValid = false
        } else {
            details.append("Claim generator: \(manifest.claimGenerator!)")
        }
        
        if manifest.version == nil {
            errors.append("Missing version")
            isValid = false
        } else {
            details.append("Version: \(manifest.version!)")
        }
        
        if manifest.signatureTime == nil {
            errors.append("Missing signature time")
            isValid = false
        } else {
            details.append("Signature time: \(formatDate(manifest.signatureTime!))")
        }
        
        // Verify Ed25519 signature if present
        if let signature = manifest.ed25519Signature {
            details.append("Ed25519 signature found")
            
            // Verify signature structure
            if signature.algorithm != "ed25519" {
                errors.append("Invalid signature algorithm: \(signature.algorithm)")
                isValid = false
            } else {
                details.append("Signature algorithm: ed25519 ✅")
            }
            
            if signature.value.isEmpty {
                errors.append("Empty signature value")
                isValid = false
            } else {
                details.append("Signature length: \(signature.value.count) characters")
            }
            
            if signature.publicKey.isEmpty {
                errors.append("Empty public key")
                isValid = false
            } else {
                details.append("Public key length: \(signature.publicKey.count) characters")
            }
            
            // Verify cryptographic signature
            do {
                let manifestData = try JSONEncoder().encode(manifest)
                let signatureValid = Ed25519Service.shared.verifySignature(
                    data: manifestData,
                    signature: signature.value,
                    publicKey: signature.publicKey
                )
                
                if signatureValid {
                    details.append("Cryptographic verification: PASSED ✅")
                } else {
                    errors.append("Cryptographic verification: FAILED")
                    isValid = false
                }
            } catch {
                errors.append("Signature verification error: \(error.localizedDescription)")
                isValid = false
            }
        } else {
            details.append("⚠️ No Ed25519 signature found")
        }
        
        // Verify arcHIVE identity if present
        if let identity = manifest.archiveIdentity {
            details.append("arcHIVE identity found")
            details.append("Ethereum address: \(identity.ethAddress)")
            details.append("Token ID: \(identity.tokenId)")
            details.append("Manifest hash: \(identity.manifestHash.prefix(20))...")
        } else {
            details.append("⚠️ No arcHIVE identity found")
        }
        
        // Verify assertions
        if !manifest.assertions.isEmpty {
            details.append("Assertions: \(manifest.assertions.count) found")
            
            let archiveAssertions = manifest.assertions.filter { $0.label == "arcHIVE.identity" }
            if !archiveAssertions.isEmpty {
                details.append("arcHIVE identity assertions: \(archiveAssertions.count)")
            }
        } else {
            details.append("⚠️ No assertions found")
        }
        
        return VerificationEndpointResult(
            isValid: isValid,
            source: .local,
            timestamp: Date(),
            details: details,
            errors: errors
        )
    }
    
    // MARK: - Remote Verification
    
    private func performRemoteVerification(mediaItem: MediaItem) async -> VerificationEndpointResult {
        var details: [String] = []
        var errors: [String] = []
        
        guard networkStatus == .available else {
            errors.append("Network not available for remote verification")
            return VerificationEndpointResult(
                isValid: false,
                source: .remote,
                timestamp: Date(),
                details: details,
                errors: errors
            )
        }
        
        guard let manifest = mediaItem.c2paManifest else {
            errors.append("No manifest to verify remotely")
            return VerificationEndpointResult(
                isValid: false,
                source: .remote,
                timestamp: Date(),
                details: details,
                errors: errors
            )
        }
        
        // Try each remote endpoint
        for endpoint in remoteEndpoints {
            details.append("Trying endpoint: \(endpoint)")
            
            do {
                let result = try await verifyWithRemoteEndpoint(manifest: manifest, endpoint: endpoint)
                if result.isValid {
                    details.append("✅ Remote endpoint verification: PASSED")
                    details.append(contentsOf: result.details)
                    return result
                } else {
                    details.append("❌ Remote endpoint verification: FAILED")
                    errors.append(contentsOf: result.errors)
                }
            } catch {
                errors.append("Remote endpoint error: \(error.localizedDescription)")
            }
        }
        
        return VerificationEndpointResult(
            isValid: false,
            source: .remote,
            timestamp: Date(),
            details: details,
            errors: errors
        )
    }
    
    private func verifyWithRemoteEndpoint(manifest: C2PAManifest, endpoint: String) async throws -> VerificationEndpointResult {
        guard let url = URL(string: endpoint) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("arcHIVE Camera App/1.0", forHTTPHeaderField: "User-Agent")
        
        // Prepare verification payload
        let payload = [
            "manifest": try JSONEncoder().encode(manifest).base64EncodedString(),
            "format": "c2pa",
            "version": "1.0"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        var details: [String] = []
        var errors: [String] = []
        
        details.append("HTTP Status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            // Parse response
            if let responseDict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let isValid = responseDict["valid"] as? Bool ?? false
                
                if let message = responseDict["message"] as? String {
                    details.append("Response: \(message)")
                }
                
                if let validationDetails = responseDict["details"] as? [String] {
                    details.append(contentsOf: validationDetails)
                }
                
                return VerificationEndpointResult(
                    isValid: isValid,
                    source: .remote,
                    timestamp: Date(),
                    details: details,
                    errors: errors
                )
            }
        } else {
            errors.append("HTTP Error: \(httpResponse.statusCode)")
        }
        
        return VerificationEndpointResult(
            isValid: false,
            source: .remote,
            timestamp: Date(),
            details: details,
            errors: errors
        )
    }
    
    // MARK: - Helper Methods
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Clear verification history
    func clearHistory() {
        verificationHistory.removeAll()
    }
    
    /// Get verification summary
    func getVerificationSummary() -> String {
        let total = verificationHistory.count
        let passed = verificationHistory.filter { $0.isValid }.count
        return "\(passed)/\(total) verifications passed"
    }
}
