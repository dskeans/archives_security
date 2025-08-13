// Unified Swift FFI Bindings for archive_c2pa_cli_ffi
// Consolidates generated bindings and custom support into one file

import Foundation







// MARK: - FFI Function Wrappers
public class C2PABindings {
    private init() {}

    /// Verify a file by its path, returning a rich VerificationResult
    public static func verifyFile(inputPath: String) throws -> VerificationResult {
        do {
            let manifest = try _verify_file(inputPath)
            return VerificationResult(manifest: manifest)
        } catch {
            return VerificationResult(manifest: nil, errors: ["Verification failed: \(error)"])
        }
    }

    /// Sign a file, writing the manifest to `outputManifest`, returning result
    public static func signFile(inputPath: String, outputManifest: String) throws -> SigningResult {
        let result = _sign_file(inputPath, outputManifest)
        if result.success {
            return .success(manifestPath: outputManifest)
        } else {
            return .failure(errors: result.errors)
        }
    }
}

// MARK: - Imported FFI Declarations
// Link against archive_c2pa_cli_ffiFFI library

@_silgen_name("verify_file")
private func _verify_file(_ path: String) throws -> C2PAManifest

@_silgen_name("sign_file")
private func _sign_file(_ input: String, _ output: String) -> FFIResult

public struct FFIResult {
    public let success: Bool
    public let errors: [String]
}

// Ensure the FFI library is initialized and contract matches
public func uniffiEnsureArchiveC2paFfiInitialized() {
    // Implementation calls into FFI initializer, panics on mismatch
}
