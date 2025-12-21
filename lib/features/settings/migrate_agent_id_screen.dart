import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../core/audio/elevenlabs_config_secure.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Simple screen to migrate ElevenLabs Agent ID to database
class MigrateAgentIdScreen extends ConsumerStatefulWidget {
  const MigrateAgentIdScreen({super.key});

  @override
  ConsumerState<MigrateAgentIdScreen> createState() =>
      _MigrateAgentIdScreenState();
}

class _MigrateAgentIdScreenState extends ConsumerState<MigrateAgentIdScreen> {
  bool _isMigrating = false;
  String? _status;

  Future<void> _migrateAgentId() async {
    setState(() {
      _isMigrating = true;
      _status = 'Migrating...';
    });

    try {
      final config = ref.read(elevenLabsConfigSecureProvider);

      // Store the agent ID from the description
      await config.storeAgentId('agent_3401kb8m47w8fe99t0etm0zcm2ap');

      setState(() {
        _status = 'Successfully migrated Agent ID to database!';
        _isMigrating = false;
      });

      // Auto-close after 2 seconds
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _isMigrating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.premiumGradient,
          ),
        ),
        title: const Text('Migrate Agent ID',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
            ),
            boxShadow: [
              BoxShadow(
                color:
                    Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.settings_backup_restore,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ).animate().premiumScale(delay: 400.ms),
              const SizedBox(height: 24),
              Text(
                'Migrate Agent ID',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              )
                  .animate()
                  .premiumFade(delay: 200.ms)
                  .premiumSlide(delay: 200.ms),
              const SizedBox(height: 12),
              Text(
                'This will secure your ElevenLabs Agent ID\nby moving it to the encrypted database.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ).animate().premiumFade(delay: 400.ms),
              const SizedBox(height: 32),
              if (_status != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _status!.startsWith('Error')
                          ? Theme.of(context).colorScheme.errorContainer
                          : Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _status!,
                      style: TextStyle(
                        color: _status!.startsWith('Error')
                            ? Theme.of(context).colorScheme.error
                            : Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ).animate().premiumFade(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isMigrating ? null : _migrateAgentId,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: _isMigrating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.cloud_upload),
                  label: Text(
                    _isMigrating ? 'Migrating...' : 'Start Migration',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ).animate().premiumFade(delay: 600.ms),
            ],
          ),
        ),
      ),
    );
  }
}
