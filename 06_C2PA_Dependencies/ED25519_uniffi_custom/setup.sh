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

UDL_FILE="src/ed25519_uniffi.udl"

# Generate Python bindings
print_step "Generating Python bindings..."
uniffi-bindgen generate \
    "$UDL_FILE" \
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
    # Create symlink with expected name
    cd bindings/python
    ln -sf libed25519_uniffi.dylib libuniffi_ed25519_uniffi.dylib
    cd ../..
    print_success "Copied libed25519_uniffi.dylib and created symlink"
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "win32" ]]; then
    # Windows
    cp target/release/ed25519_uniffi.dll bindings/python/
    cd bindings/python
    ln -sf ed25519_uniffi.dll uniffi_ed25519_uniffi.dll
    cd ../..
    print_success "Copied ed25519_uniffi.dll and created symlink"
else
    # Linux and others
    cp target/release/libed25519_uniffi.so bindings/python/
    cd bindings/python
    ln -sf libed25519_uniffi.so libuniffi_ed25519_uniffi.so
    cd ../..
    print_success "Copied libed25519_uniffi.so and created symlink"
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
        message = "Hello from Python!".encode('utf-8')
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
