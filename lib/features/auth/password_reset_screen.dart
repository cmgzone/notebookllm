import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/auth/custom_auth_service.dart';
import '../../ui/components/glass_container.dart';
import '../../ui/components/premium_button.dart';
import '../../ui/components/premium_input.dart';
import '../../theme/app_theme.dart';

class PasswordResetScreen extends ConsumerStatefulWidget {
  final String token;

  const PasswordResetScreen({super.key, required this.token});

  @override
  ConsumerState<PasswordResetScreen> createState() =>
      _PasswordResetScreenState();
}

class _PasswordResetScreenState extends ConsumerState<PasswordResetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _resetComplete = false;
  PasswordStrength? _passwordStrength;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _checkPasswordStrength(String password) {
    if (password.isNotEmpty) {
      final authService = ref.read(customAuthServiceProvider);
      setState(() {
        _passwordStrength = authService.checkPasswordStrength(password);
      });
    } else {
      setState(() => _passwordStrength = null);
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(customAuthServiceProvider).resetPassword(
            widget.token,
            _passwordController.text,
          );
      setState(() => _resetComplete = true);
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Failed to reset password. The link may have expired.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(LucideIcons.alertCircle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.premiumGradient,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: GlassContainer(
                  padding: const EdgeInsets.all(32),
                  child: _resetComplete
                      ? _buildSuccessContent(Theme.of(context))
                      : _buildResetForm(Theme.of(context)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResetForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.refreshCw,
              size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          Text('Create New Password', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Enter your new password below',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          PremiumInput(
            controller: _passwordController,
            label: 'New Password',
            icon: LucideIcons.lock,
            obscureText: _obscurePassword,
            onChanged: _checkPasswordStrength,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? LucideIcons.eye : LucideIcons.eyeOff,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (value) {
              if (value?.isEmpty ?? true) return 'Please enter a password';
              if ((value?.length ?? 0) < 8) {
                return 'Password must be at least 8 characters';
              }
              if (_passwordStrength != null && !_passwordStrength!.isStrong) {
                return 'Password is too weak';
              }
              return null;
            },
          ),
          if (_passwordStrength != null) ...[
            const SizedBox(height: 8),
            _buildPasswordStrengthIndicator(theme),
          ],
          const SizedBox(height: 16),
          PremiumInput(
            controller: _confirmController,
            label: 'Confirm Password',
            icon: LucideIcons.lock,
            obscureText: _obscureConfirm,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirm ? LucideIcons.eye : LucideIcons.eyeOff,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            validator: (value) {
              if (value != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          PremiumButton(
            onPressed: () => _resetPassword(),
            label: 'Reset Password',
            isLoading: _isLoading,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.go('/login'),
            child: const Text('Back to Login'),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordStrengthIndicator(ThemeData theme) {
    final strength = _passwordStrength!;
    final colors = [
      Colors.red,
      Colors.orange,
      Colors.yellow,
      Colors.lightGreen,
      Colors.green
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (strength.score + 1) / 5,
                  backgroundColor:
                      theme.colorScheme.outline.withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation(colors[strength.score]),
                  minHeight: 6,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              strength.label,
              style: TextStyle(
                  color: colors[strength.score],
                  fontWeight: FontWeight.w600,
                  fontSize: 12),
            ),
          ],
        ),
        if (strength.suggestions.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(strength.suggestions.first,
              style: TextStyle(
                  fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
        ],
      ],
    );
  }

  Widget _buildSuccessContent(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
          ),
          child: const Icon(LucideIcons.checkCircle,
              size: 64, color: Colors.green),
        ),
        const SizedBox(height: 24),
        Text('Password Reset!', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Your password has been successfully reset. You can now sign in with your new password.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        PremiumButton(
          onPressed: () => context.go('/login'),
          label: 'Go to Login',
        ),
      ],
    );
  }
}
