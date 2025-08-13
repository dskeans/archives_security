# C2PA Dependencies Note

The ArchiveC2PA.xcframework has been removed from this repository due to GitHub file size limits.

## Missing Dependencies:
- **ArchiveC2PA.xcframework** (52-106 MB binary files)
  - Contains C2PA Rust implementation compiled for iOS/macOS
  - Required for C2PA manifest generation and validation
  - Available in the original submission package

## For Complete Implementation:
The full C2PA implementation requires the ArchiveC2PA.xcframework which contains:
- C2PA manifest generation libraries
- Cryptographic signature validation
- CBOR encoding/decoding
- Certificate chain validation

Contact: dhskeans@gmail.com for complete implementation package.
