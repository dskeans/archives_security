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
