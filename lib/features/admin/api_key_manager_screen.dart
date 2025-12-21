import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/security/global_credentials_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';

class ApiKeyManagerScreen extends ConsumerStatefulWidget {
  const ApiKeyManagerScreen({super.key});

  @override
  ConsumerState<ApiKeyManagerScreen> createState() =>
      _ApiKeyManagerScreenState();
}

class _ApiKeyManagerScreenState extends ConsumerState<ApiKeyManagerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serviceController = TextEditingController();
  final _keyController = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _storedKeys = [];

  // Predefined supported services
  final List<String> _supportedServices = [
    'gemini',
    'elevenlabs',
    'murf',
    'google_cloud_tts',
    'openrouter',
    'serper',
  ];

  String? _selectedService;

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    setState(() => _isLoading = true);
    try {
      final creds = ref.read(globalCredentialsServiceProvider);
      final keys = await creds.listServices();
      setState(() {
        _storedKeys = keys;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load keys: $e')),
        );
      }
    }
  }

  Future<void> _saveKey() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedService == null && _serviceController.text.isEmpty) return;

    final service =
        _selectedService ?? _serviceController.text.toLowerCase().trim();
    final key = _keyController.text.trim();

    setState(() => _isLoading = true);
    try {
      final creds = ref.read(globalCredentialsServiceProvider);
      await creds.storeApiKey(
        service: service,
        apiKey: key,
        description:
            '${service[0].toUpperCase()}${service.substring(1)} API Key (Manual Entry)',
      );

      _serviceController.clear();
      _keyController.clear();
      setState(() => _selectedService = null);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('API Key saved successfully!'),
              backgroundColor: Colors.green),
        );
      }
      await _loadKeys();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error saving key: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteKey(String service) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete API Key?'),
        content:
            Text('Are you sure you want to delete the key for "$service"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final creds = ref.read(globalCredentialsServiceProvider);
      await creds.deleteApiKey(service);
      await _loadKeys();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting key: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage API Keys'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.premiumGradient,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
      ),
      body: _isLoading && _storedKeys.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Add New Key Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: scheme.outline.withValues(alpha: 0.1)),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.shadow.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add New API Key',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: scheme.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            // ignore: deprecated_member_use
                            value: _selectedService,
                            decoration: InputDecoration(
                              labelText: 'Service',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              prefixIcon: const Icon(Icons.apps),
                            ),
                            hint: const Text('Select Service or type below'),
                            items: [
                              ..._supportedServices.map((s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(
                                        s.toUpperCase().replaceAll('_', ' ')),
                                  )),
                              const DropdownMenuItem(
                                  value: 'custom',
                                  child: Text('Other (Custom)')),
                            ],
                            onChanged: (val) {
                              setState(() {
                                if (val == 'custom') {
                                  _selectedService = null;
                                } else {
                                  _selectedService = val;
                                }
                              });
                            },
                          ),
                          if (_selectedService == null) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _serviceController,
                              decoration: InputDecoration(
                                labelText: 'Custom Service Name',
                                hintText: 'e.g. openai',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                prefixIcon: const Icon(Icons.edit),
                              ),
                              validator: (value) {
                                if (_selectedService == null &&
                                    (value == null || value.isEmpty)) {
                                  return 'Please select a service or enter a name';
                                }
                                return null;
                              },
                            ),
                          ],
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _keyController,
                            decoration: InputDecoration(
                              labelText: 'API Key',
                              hintText: 'sk-...',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              prefixIcon: const Icon(Icons.key),
                            ),
                            obscureText: true,
                            validator: (value) => value == null || value.isEmpty
                                ? 'Please enter the API key'
                                : null,
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _isLoading ? null : _saveKey,
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.save),
                              label: const Text('Save Securely'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.all(16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().premiumFade().premiumSlide(),

                  const SizedBox(height: 32),
                  Text(
                    'Stored Keys',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface.withValues(alpha: 0.7),
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_storedKeys.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.vpn_key_off,
                                size: 48,
                                color: scheme.outline.withValues(alpha: 0.3)),
                            const SizedBox(height: 16),
                            Text(
                              'No keys stored yet',
                              style: TextStyle(color: scheme.outline),
                            ),
                          ],
                        ),
                      ),
                    ),

                  ..._storedKeys.map((key) {
                    final service = key['service_name'] as String;
                    final desc = key['description'] as String?;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                            color: scheme.outline.withValues(alpha: 0.1)),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: scheme.primaryContainer,
                          child: Icon(Icons.vpn_key,
                              color: scheme.primary, size: 20),
                        ),
                        title: Text(service.toUpperCase().replaceAll('_', ' ')),
                        subtitle: Text(desc ?? 'No description'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          onPressed: () => _deleteKey(service),
                        ),
                      ),
                    ).animate().premiumFade(delay: 100.ms);
                  }),
                ],
              ),
            ),
    );
  }
}
