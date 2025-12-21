# ElevenLabs API Key - Cross-Platform Compatibility

## Overview

The ElevenLabs API key implementation has been upgraded to use secure, encrypted database storage that works across all platforms (Web, Android, iOS, Desktop).

## What Changed

### Before
- ❌ Hardcoded API keys in code (security risk)
- ❌ Web-specific workarounds
- ❌ Keys exposed in source code
- ❌ Different behavior per platform

### After
- ✅ Encrypted storage in Neon database
- ✅ Consistent behavior across all platforms
- ✅ Secure key management
- ✅ Easy key rotation
- ✅ Falls back to .env for local development

## Architecture

```
┌─────────────────────────────────────────┐
│  ElevenLabsService                      │
│  (Text-to-Speech operations)            │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  ElevenLabsConfigSecure                 │
│  (API key management)                   │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  GlobalCredentialsService               │
│  (Encrypted storage with AES-256)       │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  Neon Database (api_keys table)         │
│  (Encrypted values only)                │
└─────────────────────────────────────────┘
```

## Setup Options

### Option 1: Use Database Storage (Recommended for Production)

1. **Migrate your existing key:**
   ```powershell
   .\scripts\migrate_elevenlabs_key.ps1
   ```

2. **Or add manually via SQL:**
   ```sql
   -- The script will encrypt it properly
   INSERT INTO api_keys (service_name, encrypted_value, description)
   VALUES ('elevenlabs', 'your_encrypted_key', 'ElevenLabs TTS API Key');
   ```

3. **Or use the admin UI** (if available):
   - Go to Settings → API Keys
   - Add ElevenLabs API key
   - It will be encrypted automatically

### Option 2: Use .env File (Local Development)

1. Add to your `.env` file:
   ```env
   ELEVENLABS_API_KEY=sk_your_key_here
   ```

2. The app will automatically use this if no database key exists

## How It Works

### Key Retrieval Priority

1. **First**: Try to get encrypted key from database
2. **Fallback**: Use key from .env file
3. **Cache**: Key is cached in memory after first retrieval

### Encryption Details

- **Algorithm**: AES-256
- **Key Derivation**: SHA-256 hash of secret salt
- **IV**: Random 16-byte initialization vector
- **Storage**: Base64-encoded (IV + encrypted data)

### Code Example

```dart
// Old way (hardcoded)
static String get apiKey {
  if (kIsWeb) {
    return 'sk_hardcoded_key'; // ❌ Security risk
  }
  return dotenv.env['ELEVENLABS_API_KEY'] ?? '';
}

// New way (secure)
Future<String> get apiKey async {
  if (_cachedApiKey != null) return _cachedApiKey!;
  
  final config = ref.read(elevenLabsConfigSecureProvider);
  _cachedApiKey = await config.getApiKey(); // ✅ Encrypted from DB
  return _cachedApiKey ?? '';
}
```

## Platform Compatibility

| Platform | Storage Method | Status |
|----------|---------------|--------|
| Web | Neon Database | ✅ Working |
| Android | Neon Database | ✅ Working |
| iOS | Neon Database | ✅ Working |
| Windows | Neon Database | ✅ Working |
| macOS | Neon Database | ✅ Working |
| Linux | Neon Database | ✅ Working |

## Migration Guide

### For Existing Users

If you're upgrading from the old implementation:

1. **Run the migration script:**
   ```powershell
   .\scripts\migrate_elevenlabs_key.ps1
   ```

2. **Verify it works:**
   - Open the app
   - Try voice mode
   - Check that TTS works

3. **Optional: Remove from .env**
   - Once confirmed working, you can remove the key from .env
   - The app will continue using the database key

### For New Users

1. **Get your ElevenLabs API key:**
   - Sign up at https://elevenlabs.io/
   - Go to Profile → API Keys
   - Copy your key

2. **Add it to the database:**
   ```powershell
   .\scripts\migrate_elevenlabs_key.ps1
   ```

3. **Or add to .env for development:**
   ```env
   ELEVENLABS_API_KEY=sk_your_key_here
   ```

## Security Benefits

### Before
```dart
// Exposed in source code
if (kIsWeb) {
  return 'sk_2c1856ff5ee088b118c5b5175ccc73bc56f38e475b988354';
}
```
- ❌ Key visible in source code
- ❌ Key in version control
- ❌ Key in compiled app
- ❌ Easy to extract

### After
```dart
// Encrypted in database
final dbKey = await credService.getApiKey('elevenlabs');
```
- ✅ Key encrypted at rest
- ✅ Not in source code
- ✅ Not in version control
- ✅ Requires database access to decrypt

## API Key Rotation

To rotate your ElevenLabs API key:

1. **Get new key from ElevenLabs**
2. **Update in database:**
   ```powershell
   .\scripts\migrate_elevenlabs_key.ps1
   ```
3. **Restart the app**
4. **Old key is immediately replaced**

## Troubleshooting

### "Missing ELEVENLABS_API_KEY" Error

**Cause**: No key found in database or .env

**Solution**:
1. Check if key exists in database:
   ```sql
   SELECT * FROM api_keys WHERE service_name = 'elevenlabs';
   ```
2. If not, run migration script
3. Or add to .env file

### Voice Mode Not Working

**Cause**: Invalid or expired API key

**Solution**:
1. Verify your key at https://elevenlabs.io/
2. Check your usage quota
3. Update key using migration script

### Web Platform Issues

**Cause**: Database connection issues

**Solution**:
1. Check Neon database credentials
2. Verify network connectivity
3. Check browser console for errors

## Files Changed

### New Files
- `lib/core/audio/elevenlabs_config_secure.dart` - Secure configuration
- `scripts/migrate_elevenlabs_key.ps1` - Migration script
- `ELEVENLABS_COMPATIBILITY.md` - This documentation

### Modified Files
- `lib/core/audio/elevenlabs_service.dart` - Uses secure config
- `lib/core/config/env_config.dart` - Removed hardcoded key

## Testing

### Test Database Storage
```dart
final config = ref.read(elevenLabsConfigSecureProvider);
await config.storeApiKey('sk_test_key');
final retrieved = await config.getApiKey();
print(retrieved); // Should print: sk_test_key
```

### Test Voice Generation
```dart
final service = ref.read(elevenLabsServiceProvider);
final audio = await service.textToSpeech('Hello world');
// Should return audio bytes
```

## Best Practices

1. **Production**: Always use database storage
2. **Development**: Use .env for convenience
3. **Never**: Commit API keys to version control
4. **Rotate**: Change keys periodically
5. **Monitor**: Check ElevenLabs usage dashboard

## Support

If you encounter issues:
1. Check this documentation
2. Verify database connection
3. Check ElevenLabs API status
4. Review app logs for errors

## Related Documentation

- `SECURITY_FIXES.md` - Overall security improvements
- `API_KEY_FIXES.md` - API key management guide
- `BACKEND_IMPLEMENTATION_COMPLETE.md` - Database setup
