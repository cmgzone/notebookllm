import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../core/security/global_credentials_service.dart';

/// Quick deployment screen - Run this once to deploy your API keys
/// API keys are now stored in secure storage instead of database
class QuickDeployKeys extends ConsumerStatefulWidget {
  const QuickDeployKeys({super.key});

  @override
  ConsumerState<QuickDeployKeys> createState() => _QuickDeployKeysState();
}

class _QuickDeployKeysState extends ConsumerState<QuickDeployKeys> {
  bool _isDeploying = false;
  final List<String> _logs = [];

  void _addLog(String message) {
    setState(() {
      _logs.add(message);
    });
  }

  Future<void> _deployKeys() async {
    setState(() {
      _isDeploying = true;
      _logs.clear();
    });

    try {
      _addLog('🚀 Starting deployment...');

      final credService = ref.read(globalCredentialsServiceProvider);

      // Store keys from .env to secure storage
      _addLog('🔐 Encrypting API keys...');

      final geminiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
      final elevenlabsKey = dotenv.env['ELEVENLABS_API_KEY'] ?? '';
      final serperKey = dotenv.env['SERPER_API_KEY'] ?? '';

      if (geminiKey.isEmpty || elevenlabsKey.isEmpty || serperKey.isEmpty) {
        throw Exception('Missing API keys in .env file');
      }

      // Store Gemini key
      _addLog('📤 Storing Gemini API key...');
      await credService.storeApiKey(
        service: 'gemini',
        apiKey: geminiKey,
        description: 'Gemini AI API Key',
      );
      _addLog('✅ Gemini key stored');

      // Store ElevenLabs key
      _addLog('📤 Storing ElevenLabs API key...');
      await credService.storeApiKey(
        service: 'elevenlabs',
        apiKey: elevenlabsKey,
        description: 'ElevenLabs API Key',
      );
      _addLog('✅ ElevenLabs key stored');

      // Store Serper key
      _addLog('📤 Storing Serper API key...');
      await credService.storeApiKey(
        service: 'serper',
        apiKey: serperKey,
        description: 'Serper API Key',
      );
      _addLog('✅ Serper key stored');

      // Store OpenRouter key
      final openrouterKey = dotenv.env['OPENROUTER_API_KEY'] ?? '';
      if (openrouterKey.isNotEmpty &&
          openrouterKey != 'your_openrouter_key_here') {
        _addLog('📤 Storing OpenRouter API key...');
        await credService.storeApiKey(
          service: 'openrouter',
          apiKey: openrouterKey,
          description: 'OpenRouter API Key',
        );
        _addLog('✅ OpenRouter key stored');
      } else {
        _addLog('⚠️ OpenRouter key not found or not set');
      }

      // Store Google Cloud TTS key
      final googleCloudTtsKey = dotenv.env['GOOGLE_CLOUD_TTS_API_KEY'] ?? '';
      if (googleCloudTtsKey.isNotEmpty &&
          googleCloudTtsKey != 'your_google_cloud_tts_key_here') {
        _addLog('📤 Storing Google Cloud TTS API key...');
        await credService.storeApiKey(
          service: 'google_cloud_tts',
          apiKey: googleCloudTtsKey,
          description: 'Google Cloud TTS API Key',
        );
        _addLog('✅ Google Cloud TTS key stored');
      } else {
        _addLog('⚠️ Google Cloud TTS key not found (Optional)');
      }

      // Store Murf API key
      final murfKey = dotenv.env['MURF_API_KEY'] ?? '';
      if (murfKey.isNotEmpty && murfKey != 'your_murf_api_key_here') {
        _addLog('📤 Storing Murf API key...');
        await credService.storeApiKey(
          service: 'murf',
          apiKey: murfKey,
          description: 'Murf AI API Key',
        );
        _addLog('✅ Murf key stored');
      } else {
        _addLog('⚠️ Murf key not found (Optional)');
      }

      // Verify
      _addLog('🔍 Verifying deployment...');
      final services = await credService.listServices();
      _addLog('✅ Found ${services.length} API key configurations');

      for (final service in services) {
        _addLog('  • ${service['service_name']}: ${service['description']}');
      }

      _addLog('');
      _addLog('🎉 Deployment complete!');
      _addLog('Your API keys are now encrypted and stored securely');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('API keys deployed successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e, stackTrace) {
      _addLog('');
      _addLog('❌ Error: $e');
      _addLog('Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deployment failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setState(() => _isDeploying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deploy API Keys'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            color: Colors.blue.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Deploy API Keys',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This will encrypt and store your API keys from .env securely',
                  style: TextStyle(fontSize: 14, color: Colors.blue.shade900),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _isDeploying ? null : _deployKeys,
                  icon: _isDeploying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.rocket_launch),
                  label: Text(_isDeploying ? 'Deploying...' : 'Deploy Now'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              color: Colors.black,
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _logs.map((log) {
                    Color color = Colors.white;
                    if (log.startsWith('✅')) color = Colors.green;
                    if (log.startsWith('❌')) color = Colors.red;
                    if (log.startsWith('🚀') || log.startsWith('🎉')) {
                      color = Colors.yellow;
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        log,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: color,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
