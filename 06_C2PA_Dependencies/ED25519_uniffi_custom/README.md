# Ed25519 UniFFI

A modern Rust library providing Ed25519 cryptographic operations with UniFFI bindings for Python and Swift.

## Features

- ✅ Ed25519 key pair generation
- ✅ Message signing and verification
- ✅ Python bindings via UniFFI
- ✅ Swift bindings via UniFFI
- ✅ Comprehensive error handling
- ✅ Cross-platform support (macOS, Linux, Windows)
- ✅ Modern ed25519-dalek 2.x API
- ✅ UniFFI 0.29.4 compatibility

## Quick Start

### Setup

```bash
chmod +x setup.sh
./setup.sh
```

The setup script will:
- Install uniffi-bindgen if needed
- Build the Rust library
- Generate Python and Swift bindings
- Create example scripts
- Run automated tests

### Python Usage

```python
import ed25519_uniffi

# Generate keypair
keypair = ed25519_uniffi.generate_keypair()

# Sign message
message = b"Hello, World!"
signature = ed25519_uniffi.sign_message(list(message), keypair.get_private_key())

# Verify signature
is_valid = ed25519_uniffi.verify_signature(list(message), signature, keypair.get_public_key())
print(f"Signature valid: {is_valid}")

# Get hex representations
print(f"Public key: {keypair.get_public_key_hex()}")
print(f"Private key: {keypair.get_private_key_hex()}")
```

### Swift Usage

```swift
import ed25519_uniffi

// Generate keypair
let keypair = generateKeypair()

// Sign message
let message = Array("Hello, World!".utf8)
let signature = try signMessage(message: message, privateKey: keypair.getPrivateKey())

// Verify signature
let isValid = try verifySignature(message: message, signature: signature, publicKey: keypair.getPublicKey())
print("Signature valid: \(isValid)")
```

## API Reference

### Functions

#### `generate_keypair() -> Ed25519KeyPair`
Generate a new random Ed25519 keypair.

**Returns:** A new keypair with 32-byte public and private keys.

#### `sign_message(message: Vec<u8>, private_key: Vec<u8>) -> Result<Vec<u8>, Ed25519Error>`
Sign a message using an Ed25519 private key.

**Parameters:**
- `message`: The message bytes to sign
- `private_key`: 32-byte private key

**Returns:** 64-byte signature or error

#### `verify_signature(message: Vec<u8>, signature: Vec<u8>, public_key: Vec<u8>) -> Result<bool, Ed25519Error>`
Verify an Ed25519 signature.

**Parameters:**
- `message`: The original message bytes
- `signature`: 64-byte signature to verify
- `public_key`: 32-byte public key

**Returns:** `true` if signature is valid, `false` otherwise, or error

#### `keypair_from_private_key(private_key: Vec<u8>) -> Result<Ed25519KeyPair, Ed25519Error>`
Create a keypair from an existing private key.

**Parameters:**
- `private_key`: 32-byte private key

**Returns:** Keypair with derived public key or error

### Types

#### `Ed25519KeyPair`
Contains an Ed25519 public/private key pair.

**Methods:**
- `get_public_key() -> Vec<u8>` - Get 32-byte public key
- `get_private_key() -> Vec<u8>` - Get 32-byte private key  
- `get_public_key_hex() -> String` - Get public key as hex string
- `get_private_key_hex() -> String` - Get private key as hex string

#### `Ed25519Error`
Error types for cryptographic operations:
- `InvalidPrivateKey` - Invalid private key format or length
- `InvalidPublicKey` - Invalid public key format or length
- `InvalidSignature` - Invalid signature format or length
- `SigningFailed` - Signing operation failed
- `VerificationFailed` - Verification operation failed

## Project Structure

```
ed25519-uniffi/
├── Cargo.toml                 # Rust dependencies and configuration
├── build.rs                   # Build script for UniFFI
├── uniffi-bindgen.rs         # UniFFI bindgen executable
├── setup.sh                   # Automated setup script
├── src/
│   ├── lib.rs                # Main Rust library
│   └── udl/                  # Generated UDL files
├── bindings/
│   ├── python/               # Generated Python bindings
│   └── swift/                # Generated Swift bindings
├── examples/
│   ├── python_example.py     # Python usage example
│   └── swift_example.swift   # Swift usage example
└── README.md                 # This file
```

## Key Improvements Over Original

This implementation fixes several critical issues from the original bash script:

### 1. **UniFFI 0.29.4 Compatibility**
- ✅ Fixed `#[export]` syntax → `#[derive(uniffi::Object)]` for structs
- ✅ Added proper `#[uniffi::export]` for functions
- ✅ Included required `uniffi::setup_scaffolding!()` macro
- ✅ Correct error handling with `#[derive(uniffi::Error)]`

### 2. **Ed25519-dalek 2.x API Updates**
- ✅ Replaced deprecated `Keypair`, `SecretKey`, `PublicKey`
- ✅ Used modern `SigningKey`, `VerifyingKey`, `Signature` types
- ✅ Proper key generation with `SigningKey::generate(&mut OsRng)`
- ✅ Correct signing/verification patterns

### 3. **Comprehensive Error Handling**
- ✅ Custom `Ed25519Error` enum with detailed error messages
- ✅ Proper `Result<T, E>` return types
- ✅ Input validation for key and signature lengths

### 4. **Modern Project Structure**
- ✅ Organized directory layout with `bindings/`, `examples/`, `src/`
- ✅ Proper build configuration with `build.rs`
- ✅ UniFFI bindgen script setup

### 5. **Cross-Platform Setup**
- ✅ Handles macOS, Linux, and Windows
- ✅ Automatic dependency checking and installation
- ✅ Integrated testing and validation
- ✅ Colored output and progress indicators

## Testing

Run the automated test suite:

```bash
./setup.sh
```

Or test Python bindings manually:

```bash
cd examples
python3 python_example.py
```

## Requirements

- Rust 1.70+
- Python 3.7+ (for Python bindings)
- Swift 5.0+ (for Swift bindings)
- uniffi-bindgen 0.29.4 (automatically installed by setup script)

## Dependencies

### Rust Dependencies
- `uniffi = "0.29.4"` - UniFFI framework
- `ed25519-dalek = "2.2.0"` - Ed25519 cryptography
- `rand = "0.8"` - Random number generation
- `hex = "0.4"` - Hex encoding utilities
- `thiserror = "1.0"` - Error handling

## License

MIT OR Apache-2.0

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests with `./setup.sh`
5. Submit a pull request

## Troubleshooting

### Build Errors

If you encounter build errors:

1. Ensure you have Rust 1.70+ installed
2. Update your Rust toolchain: `rustup update`
3. Clean and rebuild: `cargo clean && cargo build --release`

### Python Import Errors

If Python can't find the module:

1. Ensure the shared library is in `bindings/python/`
2. Check that Python can access the bindings directory
3. Verify Python version compatibility (3.7+)

### Swift Compilation Issues

For Swift bindings:

1. Create a proper Swift package or Xcode project
2. Include all generated files from `bindings/swift/`
3. Link against the shared library
4. Ensure Swift 5.0+ compatibility

## Examples

See the `examples/` directory for complete usage examples in both Python and Swift.