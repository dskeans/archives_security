//
//  C2PAModels.swift
//  arcHIVE Camera App
//
//  Data models for C2PA (Content Authenticity Initiative) support
//

import Foundation
import SwiftUI

// MARK: - C2PA Models (Using FFI Types)

// Use the simple FFI-compatible C2PA types
public struct C2PAManifest: Codable, Equatable, Hashable {
    public let label: String
    public let format: String
    public let title: String
    public let vendor: String
    public let signature: String
    public let ingredients: [C2PAIngredient]

    public let claimGenerator: String?
    public let signatureTime: Date?
    public let version: String?
    public let assertions: [C2PAAssertion]
    public let ed25519Signature: C2PASignature?
    public let archiveIdentity: ArchiveIdentityAssertion?
    public let signatureStatus: C2PASignatureStatus?
    public let signatureInfo: SignatureInfo?

    public static func == (lhs: C2PAManifest, rhs: C2PAManifest) -> Bool {
        return lhs.label == rhs.label &&
               lhs.format == rhs.format &&
               lhs.title == rhs.title &&
               lhs.vendor == rhs.vendor &&
               lhs.signature == rhs.signature &&
               lhs.ingredients == rhs.ingredients &&
               lhs.claimGenerator == rhs.claimGenerator &&
               lhs.signatureTime == rhs.signatureTime &&
               lhs.version == rhs.version &&
               lhs.assertions == rhs.assertions &&
               lhs.ed25519Signature == rhs.ed25519Signature &&
               lhs.archiveIdentity == rhs.archiveIdentity &&
               lhs.signatureStatus == rhs.signatureStatus
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(label)
        hasher.combine(format)
        hasher.combine(title)
        hasher.combine(vendor)
        hasher.combine(signature)
        hasher.combine(ingredients)
        hasher.combine(claimGenerator)
        hasher.combine(signatureTime)
        hasher.combine(version)
        hasher.combine(assertions)
        hasher.combine(ed25519Signature)
        hasher.combine(archiveIdentity)
        hasher.combine(signatureStatus)
    }
}

public struct C2PAIngredient: Codable, Hashable {
    public let title: String
    public let parentHash: String
    public let thumbnail: String?
    public let role: String
    public let format: String
    public let assertions: [String]

    public init(title: String, parentHash: String, thumbnail: String?, role: String, format: String, assertions: [String]) {
        self.title = title
        self.parentHash = parentHash
        self.thumbnail = thumbnail
        self.role = role
        self.format = format
        self.assertions = assertions
    }
}

// MARK: - Shared FFI Result Types
public struct VerificationResult {
    public let manifest: C2PAManifest?
    public let warnings: [String]
    public let errors: [String]
    public var isVerified: Bool { manifest != nil && errors.isEmpty }
    public init(manifest: C2PAManifest?, warnings: [String] = [], errors: [String] = []) {
        self.manifest = manifest
        self.warnings = warnings
        self.errors = errors
    }
}

// MARK: - Signature & Signing Enums (moved to models)
/**
 Represents the result of a signature verification.
 */
public enum SignatureStatus: String, Codable, Hashable, Equatable {
    case valid   = "Valid"
    case invalid = "Invalid"
    case expired = "Expired"
    case revoked = "Revoked"
    case unknown = "Unknown"
}

/**
 Represents the result of a signing operation.
 */
public enum SigningResult: Equatable {
    case success(manifestPath: String)
    case failure(errors: [String])
}

// MARK: - Media Item

struct MediaItem: Identifiable, Codable, Hashable {
    let id: UUID
    var filePath: String
    var mediaType: MediaType
    var title: String
    var description: String?
    var tags: [String]
    var customMetadata: [String: String]
    let createdAt: Date
    var updatedAt: Date

    // C2PA properties
    var c2paManifestHash: String?
    var c2paJsonPath: String?
    var c2paManifest: C2PAManifest?

    // Tokenization properties
    var tokenId: String?
    var tokenTransactionHash: String?
    var tokenMintedAt: Date?

    // IPFS properties
    var ipfsHash: String?

    // File properties
    var thumbnailPath: String?
    var fileSize: Int64 = 0

    // Computed properties
    var isTokenized: Bool {
        tokenId != nil && !tokenId!.isEmpty
    }

    var hasC2PAManifest: Bool {
        c2paManifest != nil || c2paManifestHash != nil
    }

    init(filePath: String, mediaType: MediaType, title: String) {
        self.id = UUID()
        self.filePath = filePath
        self.mediaType = mediaType
        self.title = title
        self.tags = []
        self.customMetadata = [:]
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // Comprehensive initializer for all properties
    init(
        id: UUID = UUID(),
        filePath: String,
        mediaType: MediaType,
        title: String,
        description: String? = nil,
        tags: [String] = [],
        customMetadata: [String: String] = [:],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        c2paManifestHash: String? = nil,
        c2paJsonPath: String? = nil,
        c2paManifest: C2PAManifest? = nil,
        tokenId: String? = nil,
        tokenTransactionHash: String? = nil,
        tokenMintedAt: Date? = nil,
        ipfsHash: String? = nil,
        thumbnailPath: String? = nil,
        fileSize: Int64 = 0
    ) {
        self.id = id
        self.filePath = filePath
        self.mediaType = mediaType
        self.title = title
        self.description = description
        self.tags = tags
        self.customMetadata = customMetadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.c2paManifestHash = c2paManifestHash
        self.c2paJsonPath = c2paJsonPath
        self.c2paManifest = c2paManifest
        self.tokenId = tokenId
        self.tokenTransactionHash = tokenTransactionHash
        self.tokenMintedAt = tokenMintedAt
        self.ipfsHash = ipfsHash
        self.thumbnailPath = thumbnailPath
        self.fileSize = fileSize
    }

    // MARK: - Hashable Implementation

    static func == (lhs: MediaItem, rhs: MediaItem) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    enum MediaType: String, Codable, CaseIterable {
        case photo = "photo"
        case video = "video"

        var icon: String {
            switch self {
            case .photo:
                return "photo"
            case .video:
                return "video"
            }
        }
    }
}

struct MediaMetadata {
    let fileSize: Int64
    let duration: TimeInterval? // For videos
    let dimensions: CGSize?
    let location: Location?
    
    struct Location {
        let latitude: Double
        let longitude: Double
    }
}

// MARK: - C2PA Models

/// Ed25519 signature structure for C2PA manifests
public struct C2PASignature: Codable, Hashable, Equatable {
    let algorithm: String
    let value: String
    let publicKey: String
    let timestamp: String?

    enum CodingKeys: String, CodingKey {
        case algorithm
        case value
        case publicKey = "public_key"
        case timestamp
    }
}

/// arcHIVE identity assertion for blockchain binding
public struct ArchiveIdentityAssertion: Codable, Hashable, Equatable {
    let ethAddress: String
    let manifestHash: String
    let tokenId: String
    let signingAlgorithm: String
    let publicKey: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case ethAddress = "eth_address"
        case manifestHash = "manifest_hash"
        case tokenId = "token_id"
        case signingAlgorithm = "signing_algorithm"
        case publicKey = "public_key"
        case createdAt = "created_at"
    }
}



public enum C2PASignatureStatus: String, Codable, Equatable {
    case verified = "verified"
    case tampered = "tampered"
    case unknown = "unknown"
    case none = "none"
    
    var color: Color {
        switch self {
        case .verified:
            return .green
        case .tampered:
            return .red
        case .unknown:
            return .gray
        case .none:
            return .gray
        }
    }
    
    var icon: String {
        switch self {
        case .verified:
            return "checkmark.seal.fill"
        case .tampered:
            return "exclamationmark.triangle.fill"
        case .unknown:
            return "questionmark.circle.fill"
        case .none:
            return "questionmark.circle"
        }
    }

    var label: String {
        switch self {
        case .verified:
            return "Verified"
        case .tampered:
            return "Tampered"
        case .unknown:
            return "Unknown"
        case .none:
            return "No C2PA"
        }
    }
}

public struct SignatureInfo: Codable, Equatable, Hashable {
    let algorithm: String?
    let issuer: String?
    let time: Date?
    let certChain: [String]?

    init(algorithm: String? = nil, issuer: String? = nil, time: Date? = nil, certChain: [String]? = nil) {
        self.algorithm = algorithm
        self.issuer = issuer
        self.time = time
        self.certChain = certChain
    }

    enum CodingKeys: String, CodingKey {
        case algorithm = "alg"
        case issuer
        case time
        case certChain = "cert_chain"
    }
}

public struct C2PAAssertion: Codable, Hashable, Equatable {
    let label: String
    let data: [String: String]
}



// MARK: - Album Models

struct Album: Identifiable, Codable, Hashable {
    let id = UUID()
    var name: String
    var description: String?
    var coverImagePath: String?
    var mediaItems: [MediaItem] = []
    var username: String
    var isPublic: Bool = true
    var isHidden: Bool = false
    let createdAt: Date
    var updatedAt: Date

    // Computed properties for FilesMenuView compatibility
    var itemCount: Int {
        return mediaItems.count
    }

    var tokenizedCount: Int {
        return mediaItems.filter { $0.tokenId != nil }.count
    }

    init(name: String, username: String, isPublic: Bool = true, isHidden: Bool = false) {
        self.name = name
        self.username = username
        self.isPublic = isPublic
        self.isHidden = isHidden
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - Hashable Implementation

    static func == (lhs: Album, rhs: Album) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, description, coverImagePath, mediaItems, username, isPublic, isHidden, createdAt, updatedAt
    }
}

// MARK: - Settings Models

struct C2PAAppSettings: Codable {
    var enableC2PA: Bool = true
    var autoVerifySignatures: Bool = true
    var saveOriginalFiles: Bool = true
    var defaultVideoQuality: VideoQuality = .high
    var enableGeotagging: Bool = true
    var enableDebugMode: Bool = false
    
    enum VideoQuality: String, Codable, CaseIterable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        case ultra = "Ultra"
    }
}

// MARK: - Token Models

struct TokenMetadata: Codable {
    let name: String
    let description: String
    let image: String // IPFS URL
    let externalURL: String?
    let attributes: [TokenAttribute]

    // Ed25519 cryptographic signature data for blockchain trust binding
    let ed25519Signature: String?
    let publicKey: String?
    let manifestHash: String?
    let ethAddress: String?
    let signingAlgorithm: String?

    enum CodingKeys: String, CodingKey {
        case name, description, image
        case externalURL = "external_url"
        case attributes
        case ed25519Signature = "ed25519_signature"
        case publicKey = "public_key"
        case manifestHash = "manifest_hash"
        case ethAddress = "eth_address"
        case signingAlgorithm = "signing_algorithm"
    }
}

struct TokenAttribute: Codable {
    let traitType: String
    let value: String
    
    enum CodingKeys: String, CodingKey {
        case traitType = "trait_type"
        case value
    }
}

struct TokenizationResult {
    let transactionHash: String
    let tokenId: String
    let ipfsHash: String
    let contractAddress: String
    let timestamp: Date
}

// MARK: - Error Types

enum C2PAError: LocalizedError {
    case manifestNotFound
    case invalidManifestFormat
    case signatureVerificationFailed
    case fileNotFound
    case parsingError(String)
    
    var errorDescription: String? {
        switch self {
        case .manifestNotFound:
            return "C2PA manifest not found"
        case .invalidManifestFormat:
            return "Invalid C2PA manifest format"
        case .signatureVerificationFailed:
            return "Signature verification failed"
        case .fileNotFound:
            return "File not found"
        case .parsingError(let message):
            return "Parsing error: \(message)"
        }
    }
}

// MARK: - Trust Level and Verification Result

public enum TrustLevel: String, CaseIterable {
    case fully = "Fully Trusted"
    case partial = "Partially Trusted"
    case basic = "Basic Verification"
    case failed = "Verification Failed"

    public var color: Color {
        switch self {
        case .fully: return .green
        case .partial: return .yellow
        case .basic: return .blue
        case .failed: return .red
        }
    }

    public var icon: String {
        switch self {
        case .fully: return "checkmark.seal.fill"
        case .partial: return "checkmark.seal"
        case .basic: return "seal"
        case .failed: return "xmark.seal.fill"
        }
    }
}

public struct UIVerificationResult {
    public let filename: String
    public let hasC2PA: Bool
    public let trustLevel: TrustLevel
    public let signerInfo: String
    public let verificationDate: Date
    public let details: String
    public let isVerified: Bool
    public let manifest: String?
    public let errors: [String]
    public let warnings: [String]

    public init(filename: String, hasC2PA: Bool, trustLevel: TrustLevel, signerInfo: String, verificationDate: Date, details: String, isVerified: Bool = true, manifest: String? = nil, errors: [String] = [], warnings: [String] = []) {
        self.filename = filename
        self.hasC2PA = hasC2PA
        self.trustLevel = trustLevel
        self.signerInfo = signerInfo
        self.verificationDate = verificationDate
        self.details = details
        self.isVerified = isVerified
        self.manifest = manifest
        self.errors = errors
        self.warnings = warnings
    }
}


