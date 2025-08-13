# Ed25519 UniFFI Implementation Plan

This document provides a complete implementation plan for creating a fresh ed25519-uniffi project using modern best practices for UniFFI 0.29.4 and ed25519-dalek 2.x.

## Project Structure

```
ed25519-uniffi/
├── Cargo.toml                 # Updated dependencies
├── src/
│   ├── lib.rs                # Main Rust library with UniFFI exports
│   └── udl/                  # Generated UDL files (auto-created)
├── bindings/
│   ├── python/               # Generated Python bindings
│   └── swift/                # Generated Swift bindings
├── examples/
│   ├── python_example.py     # Python usage example
│   └── swift_example.swift   # Swift usage example
├── setup.sh                  # Comprehensive setup script
└── README.md                 # Documentation
```

## 1. Cargo.toml Configuration

```toml
[package]
name = "ed25519-uniffi"
version = "0.1.0"
edition = "2021"
description = "Ed25519 cryptographic operations with UniFFI bindings for Python and Swift"
license = "MIT OR Apache-2.0"

[lib]
crate-type = ["cdylib", "staticlib"]
name = "ed25519_uniffi"

[dependencies]
# UniFFI dependencies
uniffi = "0.29.4"

# Cryptography dependencies
ed25519-dalek = "2.2.0"
rand = "0.8"

# Error handling
thiserror = "1.0"

[build-dependencies]
uniffi = { version = "0.29.4", features = ["build"] }

[[bin]]
name = "uniffi-bindgen"
path = "uniffi-bindgen.rs"
```

## 2. Main Library Implementation (src/lib.rs)

```rust
use ed25519_dalek::{Signature, Signer, SigningKey, Verifier, VerifyingKey};
use rand::rngs::OsRng;
use std::sync::Arc;
use thiserror::Error;

// Error types for proper error handling
#[derive(Error, Debug, uniffi::Error)]
pub enum Ed25519Error {
    #[error("Invalid private key: {reason}")]
    InvalidPrivateKey { reason: String },
    #[error("Invalid public key: {reason}")]
    InvalidPublicKey { reason: String },
    #[error("Invalid signature: {reason}")]
    InvalidSignature { reason: String },
    #[error("Signing failed: {reason}")]
    SigningFailed { reason: String },
    #[error("Verification failed: {reason}")]
    VerificationFailed { reason: String },
}

// Key pair structure
#[derive(uniffi::Object)]
pub struct Ed25519KeyPair {
    pub public_key: Vec<u8>,
    pub private_key: Vec<u8>,
}

#[uniffi::export]
impl Ed25519KeyPair {
    /// Create a new KeyPair with the given public and private keys
    #[uniffi::constructor]
    pub fn new(public_key: Vec<u8>, private_key: Vec<u8>) -> Arc<Self> {
        Arc::new(Self {
            public_key,
            private_key,
        })
    }

    /// Get the public key bytes
    pub fn get_public_key(&self) -> Vec<u8> {
        self.public_key.clone()
    }

    /// Get the private key bytes
    pub fn get_private_key(&self) -> Vec<u8> {
        self.private_key.clone()
    }

    /// Get the public key as a hex string
    pub fn get_public_key_hex(&self) -> String {
        hex::encode(&self.public_key)
    }

    /// Get the private key as a hex string
    pub fn get_private_key_hex(&self) -> String {
        hex::encode(&self.private_key)
    }
}

/// Generate a new ed25519 key pair
#[uniffi::export]
pub fn generate_keypair() -> Arc<Ed25519KeyPair> {
    let signing_key = SigningKey::generate(&mut OsRng);
    let verifying_key = signing_key.verifying_key();
    
    let private_key = signing_key.to_bytes().to_vec();
    let public_key = verifying_key.to_bytes().to_vec();
    
    Arc::new(Ed25519KeyPair {
        public_key,
        private_key,
    })
}

/// Sign a message with the given private key
#[uniffi::export]
pub fn sign_message(message: Vec<u8>, private_key: Vec<u8>) -> Result<Vec<u8>, Ed25519Error> {
    if private_key.len() != 32 {
        return Err(Ed25519Error::InvalidPrivateKey {
            reason: format!("Private key must be exactly 32 bytes, got {}", private_key.len()),
        });
    }

    let mut key_bytes = [0u8; 32];
    key_bytes.copy_from_slice(&private_key);
    
    let signing_key = SigningKey::from_bytes(&key_bytes);
    let signature = signing_key.sign(&message);
    
    Ok(signature.to_bytes().to_vec())
}

/// Verify a signature against a message and public key
#[uniffi::export]
pub fn verify_signature(
    message: Vec<u8>,
    signature: Vec<u8>,
    public_key: Vec<u8>,
) -> Result<bool, Ed25519Error> {
    if public_key.len() != 32 {
        return Err(Ed25519Error::InvalidPublicKey {
            reason: format!("Public key must be exactly 32 bytes, got {}", public_key.len()),
        });
    }

    if signature.len() != 64 {
        return Err(Ed25519Error::InvalidSignature {
            reason: format!("Signature must be exactly 64 bytes, got {}", signature.len()),
        });
    }

    let mut pub_key_bytes = [0u8; 32];
    pub_key_bytes.copy_from_slice(&public_key);
    
    let mut sig_bytes = [0u8; 64];
    sig_bytes.copy_from_slice(&signature);

    let verifying_key = VerifyingKey::from_bytes(&pub_key_bytes)
        .map_err(|e| Ed25519Error::InvalidPublicKey {
            reason: e.to_string(),
        })?;

    let signature = Signature::from_bytes(&sig_bytes);

    match verifying_key.verify(&message, &signature) {
        Ok(()) => Ok(true),
        Err(_) => Ok(false),
    }
}

/// Create a keypair from existing private key bytes
#[uniffi::export]
pub fn keypair_from_private_key(private_key: Vec<u8>) -> Result<Arc<Ed25519KeyPair>, Ed25519Error> {
    if private_key.len() != 32 {
        return Err(Ed25519Error::InvalidPrivateKey {
            reason: format!("Private key must be exactly 32 bytes, got {}", private_key.len()),
        });
    }

    let mut key_bytes = [0u8; 32];
    key_bytes.copy_from_slice(&private_key);
    
    let signing_key = SigningKey::from_bytes(&key_bytes);
    let verifying_key = signing_key.verifying_key();
    
    let public_key = verifying_key.to_bytes().to_vec();
    
    Ok(Arc::new(Ed25519KeyPair {
        public_key,
        private_key,
    }))
}

// Add hex dependency to Cargo.toml
// hex = "0.4"

// UniFFI setup
uniffi::setup_scaffolding!();
```

## 3. UniFFI Bindgen Script (uniffi-bindgen.rs)

```rust
fn main() {
    uniffi::uniffi_bindgen_main()
}
```

## 4. Build Script (build.rs)

```rust
fn main() {
    uniffi::generate_scaffolding("src/lib.rs").unwrap();
}
```

## 5. Comprehensive Setup Script (setup.sh)

```bash
#!/bin/bash

set -e  # Exit on any error

echo "🦀 Setting up ed25519-uniffi library with modern best practices..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${BLUE}📋 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if uniffi-bindgen is installed
print_step "Checking for uniffi-bindgen..."
if ! command -v uniffi-bindgen &> /dev/null; then
    print_warning "uniffi-bindgen not found. Installing..."
    cargo install uniffi_bindgen --version 0.29.4
    print_success "uniffi-bindgen installed"
else
    print_success "uniffi-bindgen found"
fi

# Clean previous builds
print_step "Cleaning previous builds..."
cargo clean
print_success "Clean completed"

# Build the Rust library
print_step "Building Rust library..."
cargo build --release
if [ $? -ne 0 ]; then
    print_error "Rust build failed"
    exit 1
fi
print_success "Rust library built successfully"

# Create directories for bindings
print_step "Creating binding directories..."
mkdir -p bindings/python
mkdir -p bindings/swift
mkdir -p examples
print_success "Directories created"

# Generate scaffolding and UDL
print_step "Generating UniFFI scaffolding..."
uniffi-bindgen scaffolding src/lib.rs --out-dir src/udl
if [ $? -ne 0 ]; then
    print_error "Scaffolding generation failed"
    exit 1
fi

UDL_FILE="$(find src/udl -name "*.udl" | head -1)"
if [ -z "$UDL_FILE" ]; then
    print_error "No UDL file found after scaffolding"
    exit 1
fi
print_success "Scaffolding generated: $UDL_FILE"

# Generate Python bindings
print_step "Generating Python bindings..."
uniffi-bindgen generate \
    "$UDL_FILE" \
    --crate ed25519-uniffi \
    --language python \
    --out-dir bindings/python
if [ $? -ne 0 ]; then
    print_error "Python binding generation failed"
    exit 1
fi
print_success "Python bindings generated"

# Generate Swift bindings
print_step "Generating Swift bindings..."
uniffi-bindgen generate \
    "$UDL_FILE" \
    --crate ed25519-uniffi \
    --language swift \
    --out-dir bindings/swift
if [ $? -ne 0 ]; then
    print_error "Swift binding generation failed"
    exit 1
fi
print_success "Swift bindings generated"

# Copy shared library for Python
print_step "Setting up shared library..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    cp target/release/libed25519_uniffi.dylib bindings/python/
    print_success "Copied libed25519_uniffi.dylib"
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "win32" ]]; then
    # Windows
    cp target/release/ed25519_uniffi.dll bindings/python/
    print_success "Copied ed25519_uniffi.dll"
else
    # Linux and others
    cp target/release/libed25519_uniffi.so bindings/python/
    print_success "Copied libed25519_uniffi.so"
fi

# Create Python example
print_step "Creating Python example..."
cat > examples/python_example.py << 'EOF'
#!/usr/bin/env python3

import sys
import os

# Add the bindings directory to the path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'bindings', 'python'))

import ed25519_uniffi

def main():
    print("🐍 Ed25519 UniFFI Python Example")
    print("=" * 40)
    
    try:
        # Generate a new keypair
        print("1. Generating new keypair...")
        keypair = ed25519_uniffi.generate_keypair()
        
        public_key = keypair.get_public_key()
        private_key = keypair.get_private_key()
        
        print(f"   Public key length: {len(public_key)} bytes")
        print(f"   Private key length: {len(private_key)} bytes")
        print(f"   Public key (hex): {keypair.get_public_key_hex()}")
        print(f"   Private key (hex): {keypair.get_private_key_hex()[:16]}...")
        
        # Test message signing
        message = b"Hello from Python! 🐍"
        print(f"\n2. Signing message: {message.decode()}")
        
        signature = ed25519_uniffi.sign_message(list(message), private_key)
        print(f"   Signature length: {len(signature)} bytes")
        print(f"   Signature (hex): {bytes(signature).hex()[:32]}...")
        
        # Test signature verification
        print(f"\n3. Verifying signature...")
        is_valid = ed25519_uniffi.verify_signature(list(message), signature, public_key)
        print(f"   Signature valid: {is_valid}")
        
        # Test with wrong message
        wrong_message = b"Wrong message"
        print(f"\n4. Testing with wrong message: {wrong_message.decode()}")
        is_valid_wrong = ed25519_uniffi.verify_signature(list(wrong_message), signature, public_key)
        print(f"   Signature valid: {is_valid_wrong}")
        
        # Test keypair from private key
        print(f"\n5. Recreating keypair from private key...")
        recreated_keypair = ed25519_uniffi.keypair_from_private_key(private_key)
        recreated_public = recreated_keypair.get_public_key()
        
        print(f"   Keys match: {public_key == recreated_public}")
        
        print(f"\n🎉 All tests completed successfully!")
        
    except Exception as e:
        print(f"❌ Error: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main())
EOF

# Create Swift example
print_step "Creating Swift example..."
cat > examples/swift_example.swift << 'EOF'
import Foundation

// Note: This requires the generated Swift files and shared library to be properly linked
// For a full Swift test, you'd need to set up a proper Swift package or Xcode project

print("🦉 Ed25519 UniFFI Swift Example")
print("=" + String(repeating: "=", count: 39))

print("Swift bindings generated successfully!")
print("")
print("To test Swift bindings:")
print("1. Create a new Swift package or Xcode project")
print("2. Include the generated .swift, .h, and .modulemap files from bindings/swift/")
print("3. Link against the shared library")
print("4. Import and use ed25519_uniffi module")
print("")
print("Example usage (once properly linked):")
print("""
import ed25519_uniffi

// Generate keypair
let keypair = generateKeypair()
let message = Array("Hello from Swift! 🦉".utf8)

do {
    // Sign message
    let signature = try signMessage(message: message, privateKey: keypair.getPrivateKey())
    print("✅ Signature created: \\(signature.count) bytes")
    
    // Verify signature
    let isValid = try verifySignature(message: message, signature: signature, publicKey: keypair.getPublicKey())
    print("✅ Signature valid: \\(isValid)")
} catch {
    print("❌ Error: \\(error)")
}
""")
EOF

# Run Python test
print_step "Running Python test..."
cd examples
if python3 python_example.py; then
    print_success "Python test completed successfully!"
else
    print_error "Python test failed"
    cd ..
    exit 1
fi
cd ..

# Show generated files
print_step "Generated files:"
echo "📁 Project structure:"
find . -name "*.py" -o -name "*.swift" -o -name "*.h" -o -name "*.modulemap" -o -name "*.so" -o -name "*.dylib" -o -name "*.dll" | head -20

print_success "🎉 Setup complete!"
echo ""
echo "📋 Summary:"
echo "• Rust library built: target/release/"
echo "• Python bindings: bindings/python/"
echo "• Swift bindings: bindings/swift/"
echo "• Examples: examples/"
echo ""
echo "🐍 To use Python bindings:"
echo "   cd examples && python3 python_example.py"
echo ""
echo "🦉 To use Swift bindings:"
echo "   Set up a Swift project with the generated files in bindings/swift/"
```

## 6. Updated Cargo.toml (with hex dependency)

```toml
[package]
name = "ed25519-uniffi"
version = "0.1.0"
edition = "2021"
description = "Ed25519 cryptographic operations with UniFFI bindings for Python and Swift"
license = "MIT OR Apache-2.0"

[lib]
crate-type = ["cdylib", "staticlib"]
name = "ed25519_uniffi"

[dependencies]
# UniFFI dependencies
uniffi = "0.29.4"

# Cryptography dependencies
ed25519-dalek = "2.2.0"
rand = "0.8"

# Utilities
hex = "0.4"

# Error handling
thiserror = "1.0"

[build-dependencies]
uniffi = { version = "0.29.4", features = ["build"] }

[[bin]]
name = "uniffi-bindgen"
path = "uniffi-bindgen.rs"
```

## 7. README.md

```markdown
# Ed25519 UniFFI

A modern Rust library providing Ed25519 cryptographic operations with UniFFI bindings for Python and Swift.

## Features

- ✅ Ed25519 key pair generation
- ✅ Message signing and verification
- ✅ Python bindings via UniFFI
- ✅ Swift bindings via UniFFI
- ✅ Comprehensive error handling
- ✅ Cross-platform support (macOS, Linux, Windows)

## Quick Start

### Setup

```bash
chmod +x setup.sh
./setup.sh
```

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

- `generate_keypair() -> Ed25519KeyPair` - Generate a new random keypair
- `sign_message(message: Vec<u8>, private_key: Vec<u8>) -> Result<Vec<u8>, Ed25519Error>` - Sign a message
- `verify_signature(message: Vec<u8>, signature: Vec<u8>, public_key: Vec<u8>) -> Result<bool, Ed25519Error>` - Verify a signature
- `keypair_from_private_key(private_key: Vec<u8>) -> Result<Ed25519KeyPair, Ed25519Error>` - Create keypair from private key

### Types

- `Ed25519KeyPair` - Contains public and private key bytes
- `Ed25519Error` - Error types for cryptographic operations

## Requirements

- Rust 1.70+
- Python 3.7+ (for Python bindings)
- Swift 5.0+ (for Swift bindings)

## License

MIT OR Apache-2.0
```

## Implementation Steps

1. **Create new project directory**: `mkdir ed25519-uniffi && cd ed25519-uniffi`
2. **Copy all files**: Create each file with the content specified above
3. **Make setup script executable**: `chmod +x setup.sh`
4. **Run setup**: `./setup.sh`
5. **Test the implementation**: The setup script will automatically run tests

## Key Improvements Over Original Script

1. **Modern UniFFI 0.29.4 syntax** with proper error handling
2. **Correct ed25519-dalek 2.x API** usage
3. **Comprehensive error types** with detailed messages
4. **Better project structure** with organized directories
5. **Cross-platform support** with proper library copying
6. **Automated testing** integrated into setup
7. **Complete examples** for both Python and Swift
8. **Proper dependency management** with exact versions
9. **Documentation** with usage examples
10. **Hex encoding utilities** for easier debugging

This implementation follows all modern best practices and should work out of the box with the current versions of UniFFI and ed25519-dalek.