import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../theme/app_theme.dart';
import 'services/shopify_service.dart';

class ShopifyConnectionScreen extends ConsumerStatefulWidget {
  const ShopifyConnectionScreen({super.key});

  @override
  ConsumerState<ShopifyConnectionScreen> createState() => _ShopifyConnectionScreenState();
}

class _ShopifyConnectionScreenState extends ConsumerState<ShopifyConnectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _domainController = TextEditingController();
  final _tokenController = TextEditingController();
  final _apiVersionController = TextEditingController(text: '2024-10');
  bool _busy = false;
  bool _showToken = false;

  @override
  void dispose() {
    _domainController.dispose();
    _tokenController.dispose();
    _apiVersionController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(shopifyStatusProvider);
  }

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;
    if (_busy) return;
    
    setState(() => _busy = true);
    try {
      await ref.read(shopifyServiceProvider).connect(
        _domainController.text.trim(),
        _tokenController.text.trim(),
        _apiVersionController.text.trim(),
      );
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shopify connected successfully')),
      );
      // Clear sensitive fields
      _tokenController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Connection failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    if (_busy) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Disconnect Shopify'),
        content: const Text('Remove Shopify access for this account? This will delete your stored credentials.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Disconnect')),
        ],
      ),
    );
    if (!mounted) return;
    if (confirm != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(shopifyServiceProvider).disconnect();
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shopify disconnected')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Disconnect failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(shopifyStatusProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppTheme.premiumGradient)),
        title: const Text(
          'Shopify Connection',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, color: Colors.white),
            onPressed: _busy ? null : _refresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: statusAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.alertCircle, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text('Error: $err'),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _busy ? null : _refresh,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (status) {
          final info = status.shop;
          
          if (status.connected && info != null) {
            // Connected View
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(LucideIcons.checkCircle2, color: Colors.green, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Connected to ${info.name}',
                                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 32),
                          _buildInfoRow(theme, 'Store Domain', info.storeDomain),
                          if (info.email != null) ...[
                            const SizedBox(height: 12),
                            _buildInfoRow(theme, 'Email', info.email!),
                          ],
                          if (info.plan != null) ...[
                            const SizedBox(height: 12),
                            _buildInfoRow(theme, 'Plan', info.plan!),
                          ],
                          if (info.connectedAt != null) ...[
                            const SizedBox(height: 12),
                            _buildInfoRow(theme, 'Connected', timeago.format(info.connectedAt!)),
                          ],
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _busy ? null : _disconnect,
                              icon: const Icon(LucideIcons.unlink),
                              label: const Text('Disconnect Store'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // Not Connected View
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(LucideIcons.shoppingBag, color: theme.colorScheme.primary, size: 32),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Text(
                              'Connect your Shopify store to manage orders, products, and inventory directly from Gitu.\n\n'
                              'You need to create a custom app in Shopify Admin -> Settings -> Apps and sales channels -> Develop apps.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Connection Details', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _domainController,
                    decoration: const InputDecoration(
                      labelText: 'Store Domain',
                      hintText: 'your-store.myshopify.com',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(LucideIcons.globe),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Store domain is required';
                      if (!v.contains('.')) return 'Invalid domain format';
                      return null;
                    },
                    enabled: !_busy,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _tokenController,
                    decoration: InputDecoration(
                      labelText: 'Admin API Access Token',
                      hintText: 'shpat_...',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(LucideIcons.key),
                      suffixIcon: IconButton(
                        icon: Icon(_showToken ? LucideIcons.eyeOff : LucideIcons.eye),
                        onPressed: () => setState(() => _showToken = !_showToken),
                      ),
                    ),
                    obscureText: !_showToken,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Access token is required';
                      if (!v.startsWith('shpat_')) return 'Token usually starts with shpat_';
                      return null;
                    },
                    enabled: !_busy,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _apiVersionController,
                    decoration: const InputDecoration(
                      labelText: 'API Version',
                      hintText: '2024-10',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(LucideIcons.calendar),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'API version is required' : null,
                    enabled: !_busy,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _busy ? null : _connect,
                      icon: _busy 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(LucideIcons.link),
                      label: Text(_busy ? 'Connecting...' : 'Connect Store'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(ThemeData theme, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
