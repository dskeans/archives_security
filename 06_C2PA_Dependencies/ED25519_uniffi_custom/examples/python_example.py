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
