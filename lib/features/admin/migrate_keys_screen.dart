import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../core/security/global_credentials_service.dart';

class MigrateKeysScreen extends ConsumerStatefulWidget {
  const MigrateKeysScreen({super.key});

  @override
  ConsumerState<MigrateKeysScreen> createState() => _MigrateKeysScreenState();
}

class _MigrateKeysScreenState extends ConsumerState<MigrateKeysScreen> {
  bool _isMigrating = false;
  String _status = '';

  Future<void> _migrateKeys() async {
    setState(() {
      _isMigrating = true;
      _status = 'Starting migration...';
    });

    try {
      final credService = ref.read(globalCredentialsServiceProvider);

      // Migrate all keys from .env
      setState(() => _status = 'Encrypting and storing keys...');

      await credService.migrateFromEnv({
        'GEMINI_API_KEY': dotenv.env['GEMINI_API_KEY'] ?? '',
        'OPENROUTER_API_KEY': dotenv.env['OPENROUTER_API_KEY'] ?? '',
        'ELEVENLABS_API_KEY': dotenv.env['ELEVENLABS_API_KEY'] ?? '',
        'SERPER_API_KEY': dotenv.env['SERPER_API_KEY'] ?? '',
      });

      setState(() => _status = 'Migration complete! ✓');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('API keys migrated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _status = 'Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Migration failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isMigrating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Migrate API Keys'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Migrate API Keys to Neon Database',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 16),
            Text(
              'This will encrypt and store your API keys from .env file into the Neon database.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Keys to migrate:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface),
                    ),
                    const SizedBox(height: 8),
                    _buildKeyInfo('Gemini API', dotenv.env['GEMINI_API_KEY']),
                    _buildKeyInfo(
                        'OpenRouter API', dotenv.env['OPENROUTER_API_KEY']),
                    _buildKeyInfo(
                        'ElevenLabs API', dotenv.env['ELEVENLABS_API_KEY']),
                    _buildKeyInfo('Serper API', dotenv.env['SERPER_API_KEY']),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_status.isNotEmpty)
              Card(
                color: _status.contains('Error')
                    ? Colors.red.shade50
                    : Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(_status),
                ),
              ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isMigrating ? null : _migrateKeys,
              icon: _isMigrating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.upload),
              label: Text(_isMigrating ? 'Migrating...' : 'Migrate Keys'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyInfo(String name, String? value) {
    final hasKey = value != null && value.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            hasKey ? Icons.check_circle : Icons.cancel,
            color: hasKey ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
              '$name: ${hasKey ? "${value.substring(0, 20)}..." : "Not found"}'),
        ],
      ),
    );
  }
}
