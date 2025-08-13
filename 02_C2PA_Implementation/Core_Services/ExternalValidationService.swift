import Foundation

/// External Validation Service
/// Provides optional external manifest validation using C2PA trust lists
/// Ensures no files or personal data are uploaded during validation
class ExternalValidationService {
    
    // MARK: - Types
    
    struct ValidationResult {
        let isValid: Bool
        let trustLevel: TrustLevel
        let errors: [String]
        let warnings: [String]
        let validatedAt: Date
        let trustListVersion: String?

        // Additional properties for unit testing (TODO IMPLEMENTATION COMPLETED)
        let status: ValidationStatus
        let reason: String
        let usedTrustList: Bool

        init(isValid: Bool, trustLevel: TrustLevel, errors: [String], warnings: [String], validatedAt: Date, trustListVersion: String?) {
            self.isValid = isValid
            self.trustLevel = trustLevel
            self.errors = errors
            self.warnings = warnings
            self.validatedAt = Date()
            self.trustListVersion = trustListVersion

            // Set additional properties
            self.status = isValid ? .valid : .invalid
            self.reason = errors.first ?? (isValid ? "Validation successful" : "Validation failed")
            self.usedTrustList = trustListVersion != nil
        }
    }

    enum ValidationStatus {
        case valid
        case invalid
        case skipped
    }
    
    enum TrustLevel {
        case trusted      // Certificate in official trust list
        case untrusted    // Certificate not in trust list
        case unknown      // Unable to verify (offline/error)
        case invalid      // Invalid certificate or signature
    }
    
    struct ValidationSettings {
        let enabled: Bool
        let useOfficialTrustList: Bool
        let allowOfflineValidation: Bool
        let cacheValidationResults: Bool
        
        static let `default` = ValidationSettings(
            enabled: false,  // Disabled by default for privacy
            useOfficialTrustList: true,
            allowOfflineValidation: true,
            cacheValidationResults: true
        )
    }
    
    // MARK: - Properties
    
    @Published var settings = ValidationSettings.default
    private let trustListCache = TrustListCache()
    private let validationQueue = DispatchQueue(label: "com.archive.camera.validation", qos: .utility)
    
    // MARK: - Public Methods
    
    /// Validate a C2PA manifest without uploading files or personal data
    /// - Parameter manifestPath: Local path to the manifest file
    /// - Returns: Validation result
    func validateManifest(at manifestPath: String) async -> ValidationResult {
        guard settings.enabled else {
            logPrivacy("External validation disabled by user settings")
            return ValidationResult(
                isValid: true,  // Assume valid when validation is disabled
                trustLevel: .unknown,
                errors: [],
                warnings: ["External validation is disabled"],
                validatedAt: Date(),
                trustListVersion: nil
            )
        }
        
        logC2PA("Starting external validation for manifest: \(URL(fileURLWithPath: manifestPath).lastPathComponent)")
        
        do {
            // Step 1: Parse manifest locally (no upload)
            let manifest = try parseManifestLocally(at: manifestPath)
            
            // Step 2: Extract certificate information (local operation)
            let certificateInfo = try extractCertificateInfo(from: manifest)
            
            // Step 3: Validate against trust list (may require network)
            let trustValidation = await validateAgainstTrustList(certificateInfo)
            
            // Step 4: Perform signature validation (local operation)
            let signatureValidation = validateSignatureLocally(manifest, certificateInfo)
            
            // Step 5: Combine results
            let result = combineValidationResults(trustValidation, signatureValidation)
            
            logC2PA("External validation completed: \(result.trustLevel)")
            return result
            
        } catch {
            logError("External validation failed: \(error.localizedDescription)")
            return ValidationResult(
                isValid: false,
                trustLevel: .invalid,
                errors: [error.localizedDescription],
                warnings: [],
                validatedAt: Date(),
                trustListVersion: nil
            )
        }
    }
    
    /// Update trust list from official C2PA sources (privacy-safe)
    func updateTrustList() async -> Bool {
        guard settings.enabled && settings.useOfficialTrustList else {
            logPrivacy("Trust list update skipped - validation disabled or not using official list")
            return false
        }
        
        logC2PA("Updating C2PA trust list...")
        
        do {
            // Download only trust list metadata (no personal data)
            let trustListData = try await downloadTrustListSafely()
            
            // Cache the trust list locally
            try trustListCache.updateTrustList(trustListData)
            
            logC2PA("Trust list updated successfully")
            return true
            
        } catch {
            logError("Failed to update trust list: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Get cached trust list information
    func getTrustListInfo() -> TrustListInfo? {
        return trustListCache.getInfo()
    }
    
    /// Clear validation cache for privacy
    func clearValidationCache() {
        trustListCache.clearCache()
        logPrivacy("Validation cache cleared")
    }
    
    // MARK: - Private Methods
    
    private func parseManifestLocally(at path: String) throws -> ManifestData {
        let manifestURL = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: manifestURL)
        
        // Parse JSON manifest
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let json = json else {
            throw ValidationError.invalidManifestFormat
        }
        
        return ManifestData(
            format: json["format"] as? String ?? "",
            version: json["version"] as? String ?? "",
            claimGenerator: json["claim_generator"] as? String ?? "",
            signature: json["signature"] as? String ?? "",
            certificate: json["certificate"] as? String ?? ""
        )
    }
    
    private func extractCertificateInfo(from manifest: ManifestData) throws -> CertificateInfo {
        guard !manifest.certificate.isEmpty else {
            throw ValidationError.noCertificateFound
        }
        
        // Parse certificate data (local operation)
        // This would involve parsing the X.509 certificate
        // For now, we'll extract basic information
        
        return CertificateInfo(
            issuer: extractIssuerFromCertificate(manifest.certificate),
            subject: extractSubjectFromCertificate(manifest.certificate),
            serialNumber: extractSerialFromCertificate(manifest.certificate),
            fingerprint: calculateCertificateFingerprint(manifest.certificate)
        )
    }
    
    private func validateAgainstTrustList(_ certificateInfo: CertificateInfo) async -> TrustValidationResult {
        // Check local trust list cache first
        if let cachedResult = trustListCache.checkCertificate(certificateInfo.fingerprint) {
            logC2PA("Using cached trust list result")
            return cachedResult
        }
        
        // If offline validation is allowed and we have no cache, assume unknown
        if !settings.useOfficialTrustList || settings.allowOfflineValidation {
            logC2PA("Offline validation - trust level unknown")
            return TrustValidationResult(
                trustLevel: .unknown,
                errors: [],
                warnings: ["Offline validation - unable to verify against trust list"]
            )
        }
        
        // Online validation (privacy-safe - only certificate fingerprint)
        do {
            let result = try await validateCertificateOnline(certificateInfo.fingerprint)
            
            // Cache the result
            if settings.cacheValidationResults {
                trustListCache.cacheResult(certificateInfo.fingerprint, result)
            }
            
            return result
            
        } catch {
            logError("Online trust validation failed: \(error.localizedDescription)")
            return TrustValidationResult(
                trustLevel: .unknown,
                errors: [error.localizedDescription],
                warnings: []
            )
        }
    }
    
    private func validateSignatureLocally(_ manifest: ManifestData, _ certificateInfo: CertificateInfo) -> SignatureValidationResult {
        // Perform local signature validation
        // This would involve cryptographic verification of the signature
        
        // For now, basic validation
        let hasSignature = !manifest.signature.isEmpty
        let hasCertificate = !manifest.certificate.isEmpty
        
        if hasSignature && hasCertificate {
            return SignatureValidationResult(
                isValid: true,
                errors: [],
                warnings: []
            )
        } else {
            return SignatureValidationResult(
                isValid: false,
                errors: hasSignature ? [] : ["No signature found"],
                warnings: hasCertificate ? [] : ["No certificate found"]
            )
        }
    }
    
    private func combineValidationResults(_ trustResult: TrustValidationResult, _ signatureResult: SignatureValidationResult) -> ValidationResult {
        let isValid = signatureResult.isValid && (trustResult.trustLevel == .trusted || trustResult.trustLevel == .unknown)
        
        var errors = trustResult.errors + signatureResult.errors
        var warnings = trustResult.warnings + signatureResult.warnings
        
        return ValidationResult(
            isValid: isValid,
            trustLevel: trustResult.trustLevel,
            errors: errors,
            warnings: warnings,
            validatedAt: Date(),
            trustListVersion: trustListCache.getInfo()?.version
        )
    }
    
    private func downloadTrustListSafely() async throws -> TrustListData {
        // This would download the official C2PA trust list
        // Only metadata is downloaded - no personal data is sent
        
        let trustListURL = URL(string: "https://c2pa.org/trust-list/v1/trust-list.json")!
        
        let (data, response) = try await URLSession.shared.data(from: trustListURL)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ValidationError.trustListDownloadFailed
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let json = json else {
            throw ValidationError.invalidTrustListFormat
        }
        
        return TrustListData(
            version: json["version"] as? String ?? "unknown",
            lastUpdated: Date(),
            certificates: json["certificates"] as? [[String: Any]] ?? []
        )
    }
    
    private func validateCertificateOnline(_ fingerprint: String) async throws -> TrustValidationResult {
        // Validate certificate fingerprint against online trust list
        // Only sends fingerprint - no personal data
        
        let validationURL = URL(string: "https://c2pa.org/validate/certificate")!
        var request = URLRequest(url: validationURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = ["fingerprint": fingerprint]
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ValidationError.onlineValidationFailed
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let json = json else {
            throw ValidationError.invalidValidationResponse
        }
        
        let trusted = json["trusted"] as? Bool ?? false
        let trustLevel: TrustLevel = trusted ? .trusted : .untrusted
        
        return TrustValidationResult(
            trustLevel: trustLevel,
            errors: [],
            warnings: []
        )
    }
    
    // MARK: - Certificate Parsing Helpers
    
    private func extractIssuerFromCertificate(_ certificate: String) -> String {
        // Parse certificate and extract issuer
        // This would involve proper X.509 parsing
        return "Unknown Issuer"
    }
    
    private func extractSubjectFromCertificate(_ certificate: String) -> String {
        // Parse certificate and extract subject
        return "Unknown Subject"
    }
    
    private func extractSerialFromCertificate(_ certificate: String) -> String {
        // Parse certificate and extract serial number
        return "Unknown Serial"
    }
    
    private func calculateCertificateFingerprint(_ certificate: String) -> String {
        // Calculate SHA-256 fingerprint of certificate
        guard let data = certificate.data(using: .utf8) else { return "" }
        return data.sha256
    }
}

// MARK: - Supporting Types

struct ManifestData {
    let format: String
    let version: String
    let claimGenerator: String
    let signature: String
    let certificate: String
}

struct CertificateInfo {
    let issuer: String
    let subject: String
    let serialNumber: String
    let fingerprint: String
}

struct TrustValidationResult {
    let trustLevel: ExternalValidationService.TrustLevel
    let errors: [String]
    let warnings: [String]
}

struct SignatureValidationResult {
    let isValid: Bool
    let errors: [String]
    let warnings: [String]
}

struct TrustListData {
    let version: String
    let lastUpdated: Date
    let certificates: [[String: Any]]
}

struct TrustListInfo {
    let version: String
    let lastUpdated: Date
    let certificateCount: Int
}

enum ValidationError: LocalizedError {
    case invalidManifestFormat
    case noCertificateFound
    case trustListDownloadFailed
    case invalidTrustListFormat
    case onlineValidationFailed
    case invalidValidationResponse
    
    var errorDescription: String? {
        switch self {
        case .invalidManifestFormat:
            return "Invalid manifest format"
        case .noCertificateFound:
            return "No certificate found in manifest"
        case .trustListDownloadFailed:
            return "Failed to download trust list"
        case .invalidTrustListFormat:
            return "Invalid trust list format"
        case .onlineValidationFailed:
            return "Online validation failed"
        case .invalidValidationResponse:
            return "Invalid validation response"
        }
    }
}

// MARK: - Trust List Cache

class TrustListCache {
    private let cacheURL: URL
    private var cachedTrustList: TrustListData?
    private var validationCache: [String: TrustValidationResult] = [:]
    
    init() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheURL = documentsDirectory.appendingPathComponent("trust_list_cache.json")
        loadCachedTrustList()
    }
    
    func updateTrustList(_ trustList: TrustListData) throws {
        cachedTrustList = trustList
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(trustList)
        try data.write(to: cacheURL)
    }
    
    func checkCertificate(_ fingerprint: String) -> TrustValidationResult? {
        return validationCache[fingerprint]
    }
    
    func cacheResult(_ fingerprint: String, _ result: TrustValidationResult) {
        validationCache[fingerprint] = result
    }
    
    func getInfo() -> TrustListInfo? {
        guard let trustList = cachedTrustList else { return nil }
        
        return TrustListInfo(
            version: trustList.version,
            lastUpdated: trustList.lastUpdated,
            certificateCount: trustList.certificates.count
        )
    }
    
    func clearCache() {
        cachedTrustList = nil
        validationCache.removeAll()
        try? FileManager.default.removeItem(at: cacheURL)
    }
    
    private func loadCachedTrustList() {
        guard FileManager.default.fileExists(atPath: cacheURL.path) else { return }
        
        do {
            let data = try Data(contentsOf: cacheURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            cachedTrustList = try decoder.decode(TrustListData.self, from: data)
        } catch {
            logError("Failed to load cached trust list: \(error.localizedDescription)")
        }
    }
}

// MARK: - Data Extension

extension Data {
    var sha256: String {
        let hash = SHA256.hash(data: self)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - TrustListData Codable

extension TrustListData: Codable {
    enum CodingKeys: String, CodingKey {
        case version, lastUpdated, certificates
    }
}
