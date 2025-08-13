import XCTest
import CoreLocation
import ImageIO
import AVFoundation
@testable import arcHIVE_Camera_App

/// Comprehensive tests for metadata sanitization
/// Verifies GPS, owner, serial removal while preserving orientation
class MetadataSanitizationTests: XCTestCase {
    
    var sanitizer: MetadataSanitizer!
    var testImageURL: URL!
    var testVideoURL: URL!
    
    override func setUp() {
        super.setUp()
        sanitizer = MetadataSanitizer()
        
        // Create test URLs
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        testImageURL = documentsPath.appendingPathComponent("test_image.jpg")
        testVideoURL = documentsPath.appendingPathComponent("test_video.mov")
        
        createTestImageWithMetadata()
        createTestVideoWithMetadata()
    }
    
    override func tearDown() {
        // Clean up test files
        try? FileManager.default.removeItem(at: testImageURL)
        try? FileManager.default.removeItem(at: testVideoURL)
        sanitizer = nil
        super.tearDown()
    }
    
    // MARK: - GPS Removal Tests
    
    func testGPSRemovalFromImage() async {
        // Verify test image has GPS data
        let originalMetadata = getImageMetadata(from: testImageURL)
        XCTAssertNotNil(originalMetadata?[kCGImagePropertyGPSDictionary as String], "Test image should have GPS data")

        // Sanitize the image (GPS removal enabled by default)
        let policy = MetadataSanitizer.RedactionPolicy(sanitize: true, includeGPS: false)
        let sanitizedURL = await MetadataSanitizer.sanitizeCopy(of: testImageURL, policy: policy)
        XCTAssertNotEqual(sanitizedURL, testImageURL, "Should return different URL for sanitized copy")

        // Verify GPS data is removed
        let sanitizedMetadata = getImageMetadata(from: sanitizedURL)
        XCTAssertNil(sanitizedMetadata?[kCGImagePropertyGPSDictionary as String], "GPS data should be removed")
    }
    
    func testSpecificGPSFieldsRemoved() async {
        let policy = MetadataSanitizer.RedactionPolicy(sanitize: true, includeGPS: false)
        let sanitizedURL = await MetadataSanitizer.sanitizeCopy(of: testImageURL, policy: policy)
        let metadata = getImageMetadata(from: sanitizedURL)

        // Check that GPS dictionary is completely removed
        XCTAssertNil(metadata?[kCGImagePropertyGPSDictionary as String], "Entire GPS dictionary should be removed")
    }

    func testGPSPreservationWhenAllowed() async {
        let policy = MetadataSanitizer.RedactionPolicy(sanitize: true, includeGPS: true)
        let sanitizedURL = await MetadataSanitizer.sanitizeCopy(of: testImageURL, policy: policy)
        let metadata = getImageMetadata(from: sanitizedURL)

        // Check that GPS data is preserved when policy allows it
        XCTAssertNotNil(metadata?[kCGImagePropertyGPSDictionary as String], "GPS data should be preserved when policy allows")
    }

    // MARK: - Camera Owner/Serial Removal Tests

    func testCameraOwnerRemoval() async {
        let policy = MetadataSanitizer.RedactionPolicy(sanitize: true, includeGPS: false)
        let sanitizedURL = await MetadataSanitizer.sanitizeCopy(of: testImageURL, policy: policy)
        let metadata = getImageMetadata(from: sanitizedURL)

        // Check that sensitive EXIF data is removed (entire EXIF dict should be minimal)
        let exifDict = metadata?[kCGImagePropertyExifDictionary as String] as? [String: Any]
        XCTAssertNil(exifDict?[kCGImagePropertyExifCameraOwnerName as String], "Camera owner name should be removed")
        XCTAssertNil(exifDict?["OwnerName"], "Owner name should be removed")
        XCTAssertNil(exifDict?["Artist"], "Artist field should be removed")
        
        // Check TIFF dictionary
        let tiffDict = metadata?[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
        XCTAssertNil(tiffDict?[kCGImagePropertyTIFFArtist as String], "TIFF Artist should be removed")
        XCTAssertNil(tiffDict?["Copyright"], "Copyright should be removed")
    }
    
    func testDeviceSerialRemoval() {
        let sanitizedURL = sanitizer.sanitizeImage(at: testImageURL)
        let metadata = getImageMetadata(from: sanitizedURL!)
        
        // Check for device serial numbers
        let exifDict = metadata?[kCGImagePropertyExifDictionary as String] as? [String: Any]
        XCTAssertNil(exifDict?["SerialNumber"], "Device serial number should be removed")
        XCTAssertNil(exifDict?["BodySerialNumber"], "Body serial number should be removed")
        XCTAssertNil(exifDict?["LensSerialNumber"], "Lens serial number should be removed")
        
        // Check maker notes (often contains serial info)
        XCTAssertNil(exifDict?[kCGImagePropertyExifMakerNote as String], "Maker notes should be removed")
    }
    
    func testDeviceIdentifiersRemoval() {
        let sanitizedURL = sanitizer.sanitizeImage(at: testImageURL)
        let metadata = getImageMetadata(from: sanitizedURL!)
        
        // Check for device-specific identifiers
        let exifDict = metadata?[kCGImagePropertyExifDictionary as String] as? [String: Any]
        XCTAssertNil(exifDict?["UniqueCameraModel"], "Unique camera model should be removed")
        XCTAssertNil(exifDict?["CameraSerialNumber"], "Camera serial should be removed")
        
        // Check TIFF for device info
        let tiffDict = metadata?[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
        XCTAssertNil(tiffDict?["HostComputer"], "Host computer should be removed")
        XCTAssertNil(tiffDict?["Software"], "Software info should be removed")
    }
    
    // MARK: - Orientation Preservation Tests
    
    func testOrientationPreserved() {
        // Get original orientation
        let originalMetadata = getImageMetadata(from: testImageURL)
        let originalOrientation = originalMetadata?[kCGImagePropertyOrientation as String] as? Int
        
        // Sanitize image
        let sanitizedURL = sanitizer.sanitizeImage(at: testImageURL)
        
        // Verify orientation is preserved
        let sanitizedMetadata = getImageMetadata(from: sanitizedURL!)
        let sanitizedOrientation = sanitizedMetadata?[kCGImagePropertyOrientation as String] as? Int
        
        XCTAssertEqual(originalOrientation, sanitizedOrientation, "Image orientation should be preserved")
    }
    
    func testTIFFOrientationPreserved() {
        let originalMetadata = getImageMetadata(from: testImageURL)
        let originalTIFF = originalMetadata?[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
        let originalOrientation = originalTIFF?[kCGImagePropertyTIFFOrientation as String] as? Int
        
        let sanitizedURL = sanitizer.sanitizeImage(at: testImageURL)
        let sanitizedMetadata = getImageMetadata(from: sanitizedURL!)
        let sanitizedTIFF = sanitizedMetadata?[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
        let sanitizedOrientation = sanitizedTIFF?[kCGImagePropertyTIFFOrientation as String] as? Int
        
        XCTAssertEqual(originalOrientation, sanitizedOrientation, "TIFF orientation should be preserved")
    }
    
    // MARK: - Video Metadata Tests
    
    func testVideoGPSRemoval() {
        let sanitizedURL = sanitizer.sanitizeVideo(at: testVideoURL)
        XCTAssertNotNil(sanitizedURL, "Video sanitization should succeed")
        
        // Check video metadata
        let asset = AVAsset(url: sanitizedURL!)
        let metadata = asset.metadata
        
        // Verify GPS metadata is removed
        let gpsItems = metadata.filter { $0.commonKey?.rawValue.contains("location") == true }
        XCTAssertTrue(gpsItems.isEmpty, "GPS metadata should be removed from video")
    }
    
    func testVideoDeviceInfoRemoval() {
        let sanitizedURL = sanitizer.sanitizeVideo(at: testVideoURL)
        let asset = AVAsset(url: sanitizedURL!)
        let metadata = asset.metadata
        
        // Check for device-specific metadata
        let deviceItems = metadata.filter { item in
            guard let key = item.commonKey?.rawValue else { return false }
            return key.contains("device") || key.contains("serial") || key.contains("model")
        }
        
        XCTAssertTrue(deviceItems.isEmpty, "Device info should be removed from video")
    }
    
    // MARK: - XMP Metadata Tests
    
    func testXMPMetadataRemoval() {
        let sanitizedURL = sanitizer.sanitizeImage(at: testImageURL)
        let metadata = getImageMetadata(from: sanitizedURL!)
        
        // XMP often contains privacy-sensitive data
        XCTAssertNil(metadata?["XMP"], "XMP metadata should be removed")
        XCTAssertNil(metadata?[kCGImagePropertyIPTCDictionary as String], "IPTC metadata should be removed")
    }
    
    // MARK: - Essential Metadata Preservation Tests
    
    func testEssentialMetadataPreserved() {
        let sanitizedURL = sanitizer.sanitizeImage(at: testImageURL)
        let metadata = getImageMetadata(from: sanitizedURL!)
        
        // These should be preserved for proper image display
        XCTAssertNotNil(metadata?[kCGImagePropertyPixelWidth as String], "Pixel width should be preserved")
        XCTAssertNotNil(metadata?[kCGImagePropertyPixelHeight as String], "Pixel height should be preserved")
        XCTAssertNotNil(metadata?[kCGImagePropertyColorModel as String], "Color model should be preserved")
        
        // Basic EXIF for image quality
        let exifDict = metadata?[kCGImagePropertyExifDictionary as String] as? [String: Any]
        XCTAssertNotNil(exifDict?[kCGImagePropertyExifDateTimeOriginal as String], "Creation date should be preserved")
        XCTAssertNotNil(exifDict?[kCGImagePropertyExifPixelXDimension as String], "Pixel dimensions should be preserved")
    }
    
    // MARK: - Performance Tests
    
    func testSanitizationPerformance() {
        measure {
            _ = sanitizer.sanitizeImage(at: testImageURL)
        }
    }
    
    func testBatchSanitizationPerformance() {
        let urls = Array(repeating: testImageURL!, count: 10)
        
        measure {
            for url in urls {
                _ = sanitizer.sanitizeImage(at: url)
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidImageHandling() {
        let invalidURL = URL(fileURLWithPath: "/nonexistent/file.jpg")
        let result = sanitizer.sanitizeImage(at: invalidURL)
        XCTAssertNil(result, "Should return nil for invalid image")
    }
    
    func testCorruptedImageHandling() {
        // Create a corrupted image file
        let corruptedURL = testImageURL.appendingPathExtension("corrupt")
        let corruptedData = Data([0xFF, 0xD8, 0xFF, 0xE0]) // Incomplete JPEG header
        try! corruptedData.write(to: corruptedURL)
        
        let result = sanitizer.sanitizeImage(at: corruptedURL)
        XCTAssertNil(result, "Should handle corrupted images gracefully")
        
        try? FileManager.default.removeItem(at: corruptedURL)
    }
    
    // MARK: - Helper Methods
    
    private func createTestImageWithMetadata() {
        // Create a simple test image with comprehensive metadata
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        
        guard let imageData = image.jpegData(compressionQuality: 1.0) else { return }
        
        // Add metadata using ImageIO
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let imageRef = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return }
        
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, kUTTypeJPEG, 1, nil) else { return }
        
        // Create comprehensive test metadata
        let metadata: [String: Any] = [
            kCGImagePropertyGPSDictionary as String: [
                kCGImagePropertyGPSLatitude as String: 37.7749,
                kCGImagePropertyGPSLongitude as String: -122.4194,
                kCGImagePropertyGPSAltitude as String: 100.0,
                kCGImagePropertyGPSTimeStamp as String: "12:34:56"
            ],
            kCGImagePropertyExifDictionary as String: [
                kCGImagePropertyExifCameraOwnerName as String: "Test Owner",
                "SerialNumber": "ABC123456789",
                "BodySerialNumber": "BODY123",
                "LensSerialNumber": "LENS456",
                kCGImagePropertyExifMakerNote as String: Data([1, 2, 3, 4]),
                kCGImagePropertyExifDateTimeOriginal as String: "2025:01:10 12:00:00"
            ],
            kCGImagePropertyTIFFDictionary as String: [
                kCGImagePropertyTIFFArtist as String: "Test Artist",
                kCGImagePropertyTIFFOrientation as String: 1,
                "Copyright": "Test Copyright",
                "HostComputer": "Test Computer",
                "Software": "Test Software"
            ],
            kCGImagePropertyOrientation as String: 1
        ]
        
        CGImageDestinationAddImage(destination, imageRef, metadata as CFDictionary)
        CGImageDestinationFinalize(destination)
        
        mutableData.write(to: testImageURL)
    }
    
    private func createTestVideoWithMetadata() {
        // Create a minimal test video file
        // In a real implementation, this would create a proper video with metadata
        let testData = Data("test video data".utf8)
        try! testData.write(to: testVideoURL)
    }
    
    private func getImageMetadata(from url: URL) -> [String: Any]? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]
    }
}
