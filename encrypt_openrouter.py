#!/usr/bin/env python3
"""
Encrypt OpenRouter API key for Neon database storage
"""
import hashlib
import base64
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.backends import default_backend
import os

# Your OpenRouter API key
OPENROUTER_KEY = "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"

# Same secret as in the app
SECRET = "notebook_llm_global_secret_key_2024"

# Generate encryption key from secret (same as app)
key_bytes = hashlib.sha256(SECRET.encode()).digest()

# Generate random IV
iv = os.urandom(16)

# Create cipher
cipher = Cipher(
    algorithms.AES(key_bytes),
    modes.CBC(iv),
    backend=default_backend()
)

# Encrypt
encryptor = cipher.encryptor()

# Pad the plaintext to be multiple of 16 bytes
plaintext = OPENROUTER_KEY.encode()
padding_length = 16 - (len(plaintext) % 16)
padded_plaintext = plaintext + bytes([padding_length] * padding_length)

encrypted = encryptor.update(padded_plaintext) + encryptor.finalize()

# Combine IV + encrypted data
combined = iv + encrypted

# Base64 encode
encrypted_base64 = base64.b64encode(combined).decode()

print("=" * 60)
print("ENCRYPTED OPENROUTER API KEY")
print("=" * 60)
print()
print("Run this SQL in Neon Console:")
print()
print(f"INSERT INTO api_keys (service_name, encrypted_value, description, updated_at)")
print(f"VALUES ('openrouter', '{encrypted_base64}', 'OpenRouter API Key', CURRENT_TIMESTAMP)")
print(f"ON CONFLICT (service_name)")
print(f"DO UPDATE SET encrypted_value = EXCLUDED.encrypted_value, updated_at = CURRENT_TIMESTAMP;")
print()
print("=" * 60)
print("Verify with:")
print("SELECT service_name, description, updated_at FROM api_keys;")
print("=" * 60)
