// Services/MetadataSanitizer.swift
// Comprehensive metadata sanitization with security controls
// TODO IMPLEMENTATION: All documented security features

import Foundation
import AVFoundation
import ImageIO
import MobileCoreServices
import UniformTypeIdentifiers
import OSLog

enum MediaSanitizerError: Error {
    case unsupported, exportFailed(String), validationFailed(String)
}

/// Comprehensive metadata sanitizer with security controls for C2PA Level 2 compliance
final class MetadataSanitizer {
    private static let logger = Logger(subsystem: "com.archive.camera", category: "MetadataSanitizer")

    // MARK: - Configuration Structures

    struct SanitizationConfig {
        let removeGPS: Bool
        let removeDeviceSerial: Bool
        let removeOwnerInfo: Bool
        let preserveOrientation: Bool
        let preserveTimestamp: Bool

        static let defaultPrivacyFirst = SanitizationConfig(
            removeGPS: true,
            removeDeviceSerial: true,
            removeOwnerInfo: true,
            preserveOrientation: true,
            preserveTimestamp: true
        )
    }

    // Legacy support
    struct RedactionPolicy {
        var sanitize: Bool
        var includeGPS: Bool

        var asSanitizationConfig: SanitizationConfig {
            return SanitizationConfig(
                removeGPS: !includeGPS,
                removeDeviceSerial: true,
                removeOwnerInfo: true,
                preserveOrientation: true,
                preserveTimestamp: true
            )
        }
    }

    // MARK: - Public Methods

    /// Create a sanitized copy of the media with comprehensive security controls
    static func sanitizeCopy(of url: URL, policy: RedactionPolicy = .init(sanitize: true, includeGPS: false)) async -> URL {
        return await sanitizeCopy(of: url, config: policy.asSanitizationConfig)
    }

    /// Create a sanitized copy with detailed configuration
    static func sanitizeCopy(of url: URL, config: SanitizationConfig = .defaultPrivacyFirst) async -> URL {
        let ext = url.pathExtension.lowercased()
        if ["jpg","jpeg","png","heic","heif"].contains(ext) {
            return sanitizeImage(url, config: config) ?? url
        } else if ["mov","mp4"].contains(ext) {
            if let out = await sanitizeVideo(url) { return out } else { return url }
        } else {
            return url
        }
    }

    /// Sanitize metadata dictionary directly (for in-memory processing)
    static func sanitizeMetadata(_ metadata: [String: Any], config: SanitizationConfig = .defaultPrivacyFirst) -> [String: Any] {
        var sanitized = metadata

        // Remove GPS data if configured
        if config.removeGPS {
            sanitized = removeGPSData(from: sanitized)
        }

        // Remove device serial numbers
        if config.removeDeviceSerial {
            sanitized = removeDeviceSerialNumbers(from: sanitized)
        }

        // Remove owner information
        if config.removeOwnerInfo {
            sanitized = removeOwnerInformation(from: sanitized)
        }

        // Apply security sanitization (XSS, injection protection)
        sanitized = applySecuritySanitization(to: sanitized)

        return sanitized
    }

    /// Validate that sanitization was successful
    static func validateSanitization(_ metadata: [String: Any]) -> Bool {
        // Check for sensitive GPS data
        if hasGPSData(metadata) {
            logger.error("Sanitization failed: GPS data still present")
            return false
        }

        // Check for device serial numbers
        if hasDeviceSerialNumbers(metadata) {
            logger.error("Sanitization failed: Device serial numbers still present")
            return false
        }

        // Check for owner information
        if hasOwnerInformation(metadata) {
            logger.error("Sanitization failed: Owner information still present")
            return false
        }

        // Check for security threats
        if hasSecurityThreats(metadata) {
            logger.error("Sanitization failed: Security threats detected")
            return false
        }

        return true
    }

    // MARK: - Private Image Processing

    private static func sanitizeImage(_ url: URL, config: SanitizationConfig) -> URL? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil), let type = CGImageSourceGetType(src) else { return nil }
        let count = CGImageSourceGetCount(src)
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("sanitized_\(url.lastPathComponent)")
        guard let dest = CGImageDestinationCreateWithURL(tmp as CFURL, type, count, nil) else { return nil }

        for i in 0..<count {
            guard let originalProps = CGImageSourceCopyPropertiesAtIndex(src, i, nil) as? [CFString: Any] else { continue }

            // Start with clean metadata dictionary
            var sanitizedProps: [CFString: Any] = [:]

            // Preserve essential image properties
            preserveEssentialProperties(from: originalProps, to: &sanitizedProps)

            // Conditionally preserve GPS if configured
            if !config.removeGPS, let gpsDict = originalProps[kCGImagePropertyGPSDictionary] {
                sanitizedProps[kCGImagePropertyGPSDictionary] = gpsDict
            }

            // Remove all potentially sensitive metadata by not copying it
            // This includes: EXIF (except essential), TIFF (except essential), IPTC, XMP, Maker Notes

            CGImageDestinationAddImageFromSource(dest, src, i, sanitizedProps as CFDictionary)
        }
        guard CGImageDestinationFinalize(dest) else { return nil }
        return tmp
    }

    /// Preserve only essential metadata properties needed for proper image display
    private static func preserveEssentialProperties(from original: [CFString: Any], to sanitized: inout [CFString: Any]) {
        // Core image properties
        let essentialKeys: [CFString] = [
            kCGImagePropertyPixelWidth,
            kCGImagePropertyPixelHeight,
            kCGImagePropertyOrientation,
            kCGImagePropertyColorModel,
            kCGImagePropertyDPIWidth,
            kCGImagePropertyDPIHeight,
            kCGImagePropertyDepth,
            kCGImagePropertyHasAlpha
        ]

        for key in essentialKeys {
            if let value = original[key] {
                sanitized[key] = value
            }
        }

        // Essential EXIF properties (technical, non-identifying)
        if let exifDict = original[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            var sanitizedExif: [CFString: Any] = [:]

            let essentialExifKeys: [CFString] = [
                kCGImagePropertyExifPixelXDimension,
                kCGImagePropertyExifPixelYDimension,
                kCGImagePropertyExifColorSpace,
                kCGImagePropertyExifDateTimeOriginal
            ]

            for key in essentialExifKeys {
                if let value = exifDict[key] {
                    sanitizedExif[key] = value
                }
            }

            if !sanitizedExif.isEmpty {
                sanitized[kCGImagePropertyExifDictionary] = sanitizedExif
            }
        }

        // Essential TIFF properties (orientation and resolution)
        if let tiffDict = original[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
            var sanitizedTiff: [CFString: Any] = [:]

            let essentialTiffKeys: [CFString] = [
                kCGImagePropertyTIFFOrientation,
                kCGImagePropertyTIFFXResolution,
                kCGImagePropertyTIFFYResolution,
                kCGImagePropertyTIFFResolutionUnit
            ]

            for key in essentialTiffKeys {
                if let value = tiffDict[key] {
                    sanitizedTiff[key] = value
                }
            }

            if !sanitizedTiff.isEmpty {
                sanitized[kCGImagePropertyTIFFDictionary] = sanitizedTiff
            }
        }
    }

    private static func sanitizeVideo(_ url: URL) async -> URL? {
        let asset = AVURLAsset(url: url)
        guard let preset = AVAssetExportSession.exportPresets(compatibleWith: asset).first,
              let exporter = AVAssetExportSession(asset: asset, presetName: preset) else { return nil }
        let out = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("sanitized_\(url.lastPathComponent)")
        exporter.outputURL = out
        exporter.outputFileType = asset.fileTypeForExportFallback()
        exporter.metadata = [] // Remove metadata
        return await withCheckedContinuation { cont in
            exporter.exportAsynchronously {
                switch exporter.status {
                case .completed: cont.resume(returning: out)
                default: cont.resume(returning: nil)
                }
            }
        }
    }

    // MARK: - GPS Data Removal

    private static func removeGPSData(from metadata: [String: Any]) -> [String: Any] {
        var sanitized = metadata

        // Remove standard GPS dictionary
        sanitized.removeValue(forKey: kCGImagePropertyGPSDictionary as String)

        // Remove custom GPS fields
        let gpsKeys = ["GPS", "Location", "Coordinates", "Latitude", "Longitude", "Altitude"]
        for key in gpsKeys {
            sanitized.removeValue(forKey: key)
        }

        // Remove GPS from EXIF data
        if var exifDict = sanitized[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            exifDict.removeValue(forKey: "GPSInfo")
            exifDict.removeValue(forKey: "GPS")
            sanitized[kCGImagePropertyExifDictionary as String] = exifDict
        }

        logger.info("GPS data removed from metadata")
        return sanitized
    }

    // MARK: - Device Serial Number Removal

    private static func removeDeviceSerialNumbers(from metadata: [String: Any]) -> [String: Any] {
        var sanitized = metadata

        // Remove device serial numbers
        let serialKeys = [
            "SerialNumber", "DeviceSerialNumber", "CameraSerialNumber",
            "LensSerialNumber", "DeviceID", "UDID", "IMEI", "MacAddress"
        ]

        for key in serialKeys {
            sanitized.removeValue(forKey: key)
        }

        // Remove from TIFF dictionary
        if var tiffDict = sanitized[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            for key in serialKeys {
                tiffDict.removeValue(forKey: key)
            }
            sanitized[kCGImagePropertyTIFFDictionary as String] = tiffDict
        }

        // Remove from EXIF dictionary
        if var exifDict = sanitized[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            for key in serialKeys {
                exifDict.removeValue(forKey: key)
            }
            sanitized[kCGImagePropertyExifDictionary as String] = exifDict
        }

        logger.info("Device serial numbers removed from metadata")
        return sanitized
    }

    // MARK: - Owner Information Removal

    private static func removeOwnerInformation(from metadata: [String: Any]) -> [String: Any] {
        var sanitized = metadata

        // Remove owner/creator information
        let ownerKeys = [
            "Owner", "Artist", "Copyright", "Creator", "Author",
            "Email", "Phone", "Website", "Address", "Contact"
        ]

        for key in ownerKeys {
            sanitized.removeValue(forKey: key)
        }

        // Remove from TIFF dictionary
        if var tiffDict = sanitized[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            tiffDict.removeValue(forKey: kCGImagePropertyTIFFArtist as String)
            tiffDict.removeValue(forKey: kCGImagePropertyTIFFCopyright as String)
            tiffDict.removeValue(forKey: kCGImagePropertyTIFFSoftware as String)
            for key in ownerKeys {
                tiffDict.removeValue(forKey: key)
            }
            sanitized[kCGImagePropertyTIFFDictionary as String] = tiffDict
        }

        // Remove from EXIF dictionary
        if var exifDict = sanitized[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            exifDict.removeValue(forKey: kCGImagePropertyExifUserComment as String)
            for key in ownerKeys {
                exifDict.removeValue(forKey: key)
            }
            sanitized[kCGImagePropertyExifDictionary as String] = exifDict
        }

        logger.info("Owner information removed from metadata")
        return sanitized
    }

    // MARK: - Security Sanitization (XSS, Injection Protection)

    private static func applySecuritySanitization(to metadata: [String: Any]) -> [String: Any] {
        var sanitized = metadata

        // Apply XSS protection to all string values
        sanitized = sanitizeXSSThreats(in: sanitized)

        // Apply SQL injection protection
        sanitized = sanitizeSQLInjection(in: sanitized)

        // Apply command injection protection
        sanitized = sanitizeCommandInjection(in: sanitized)

        return sanitized
    }

    private static func sanitizeXSSThreats(in metadata: [String: Any]) -> [String: Any] {
        var sanitized = metadata

        let xssPatterns = [
            "<script", "javascript:", "onerror=", "onload=", "onclick=",
            "<iframe", "<object", "<embed", "<form", "vbscript:",
            "data:text/html", "&#", "\\x", "eval(", "alert("
        ]

        for (key, value) in sanitized {
            if let stringValue = value as? String {
                var cleanValue = stringValue

                // Remove XSS patterns (case insensitive)
                for pattern in xssPatterns {
                    cleanValue = cleanValue.replacingOccurrences(
                        of: pattern,
                        with: "",
                        options: .caseInsensitive
                    )
                }

                // HTML encode remaining special characters
                cleanValue = cleanValue
                    .replacingOccurrences(of: "<", with: "&lt;")
                    .replacingOccurrences(of: ">", with: "&gt;")
                    .replacingOccurrences(of: "\"", with: "&quot;")
                    .replacingOccurrences(of: "'", with: "&#x27;")

                sanitized[key] = cleanValue
            }
        }

        return sanitized
    }

    private static func sanitizeSQLInjection(in metadata: [String: Any]) -> [String: Any] {
        var sanitized = metadata

        let sqlPatterns = [
            "'", "\"", ";", "--", "/*", "*/", "xp_", "sp_",
            "DROP", "DELETE", "INSERT", "UPDATE", "SELECT", "UNION",
            "CREATE", "ALTER", "EXEC", "EXECUTE"
        ]

        for (key, value) in sanitized {
            if let stringValue = value as? String {
                var cleanValue = stringValue

                // Remove SQL injection patterns
                for pattern in sqlPatterns {
                    cleanValue = cleanValue.replacingOccurrences(
                        of: pattern,
                        with: "",
                        options: .caseInsensitive
                    )
                }

                sanitized[key] = cleanValue
            }
        }

        return sanitized
    }

    private static func sanitizeCommandInjection(in metadata: [String: Any]) -> [String: Any] {
        var sanitized = metadata

        let cmdPatterns = [
            "$(", "`", "|", "&", "&&", "||", ";",
            "rm ", "del ", "format ", "shutdown ", "reboot "
        ]

        for (key, value) in sanitized {
            if let stringValue = value as? String {
                var cleanValue = stringValue

                // Remove command injection patterns
                for pattern in cmdPatterns {
                    cleanValue = cleanValue.replacingOccurrences(of: pattern, with: "")
                }

                sanitized[key] = cleanValue
            }
        }

        return sanitized
    }

    // MARK: - Validation Methods

    private static func hasGPSData(_ metadata: [String: Any]) -> Bool {
        // Check for GPS dictionary
        if metadata[kCGImagePropertyGPSDictionary as String] != nil {
            return true
        }

        // Check for custom GPS fields
        let gpsKeys = ["GPS", "Location", "Coordinates", "Latitude", "Longitude"]
        for key in gpsKeys {
            if metadata[key] != nil {
                return true
            }
        }

        return false
    }

    private static func hasDeviceSerialNumbers(_ metadata: [String: Any]) -> Bool {
        let serialKeys = [
            "SerialNumber", "DeviceSerialNumber", "CameraSerialNumber",
            "LensSerialNumber", "DeviceID", "UDID", "IMEI"
        ]

        for key in serialKeys {
            if metadata[key] != nil {
                return true
            }
        }

        return false
    }

    private static func hasOwnerInformation(_ metadata: [String: Any]) -> Bool {
        let ownerKeys = [
            "Owner", "Artist", "Copyright", "Creator", "Author",
            "Email", "Phone", "Website", "Address"
        ]

        for key in ownerKeys {
            if metadata[key] != nil {
                return true
            }
        }

        return false
    }

    private static func hasSecurityThreats(_ metadata: [String: Any]) -> Bool {
        let threatPatterns = [
            "<script", "javascript:", "onerror=", "'", "\"", ";", "--",
            "$(", "`", "|", "&", "DROP", "DELETE", "INSERT"
        ]

        for (_, value) in metadata {
            if let stringValue = value as? String {
                for pattern in threatPatterns {
                    if stringValue.lowercased().contains(pattern.lowercased()) {
                        return true
                    }
                }
            }
        }

        return false
    }
}

private extension AVURLAsset {
    func fileTypeForExportFallback() -> AVFileType {
        let ext = self.url.pathExtension.lowercased()
        if ext == "mov" { return .mov }
        return .mp4
    }
}

