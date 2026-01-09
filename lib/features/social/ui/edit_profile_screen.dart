import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/auth/custom_auth_service.dart';
import '../profile_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _displayNameController = TextEditingController();
  final _imagePicker = ImagePicker();

  String? _avatarUrl;
  String? _coverUrl;
  File? _localAvatar;
  File? _localCover;
  bool _isInit = false;

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  void _init() {
    if (_isInit) return;
    final user = ref.read(customAuthStateProvider).user;
    if (user != null) {
      _displayNameController.text = user.displayName ?? '';
      _avatarUrl = user.avatarUrl;
      _coverUrl = user.coverUrl;
      _isInit = true;
    }
  }

  Future<void> _pickAvatar() async {
    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 85,
    );
    if (pickedFile != null) {
      setState(() {
        _localAvatar = File(pickedFile.path);
      });
    }
  }

  Future<void> _pickCover() async {
    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 400,
      imageQuality: 85,
    );
    if (pickedFile != null) {
      setState(() {
        _localCover = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    final notifier = ref.read(profileProvider.notifier);

    // Show loading
    setState(() {});

    String? finalAvatarUrl = _avatarUrl;
    String? finalCoverUrl = _coverUrl;

    if (_localAvatar != null) {
      finalAvatarUrl = await notifier.uploadImage(_localAvatar!);
    }

    if (_localCover != null) {
      finalCoverUrl = await notifier.uploadImage(_localCover!);
    }

    await notifier.updateProfile(
      displayName: _displayNameController.text.trim(),
      avatarUrl: finalAvatarUrl,
      coverUrl: finalCoverUrl,
    );

    if (mounted) {
      final state = ref.read(profileProvider);
      if (state.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.error!), backgroundColor: Colors.red),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _init();
    final profileState = ref.watch(profileProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          if (profileState.isUpdating)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveProfile,
              child: const Text('Save'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cover Photo Section
            Stack(
              children: [
                GestureDetector(
                  onTap: _pickCover,
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      image: _localCover != null
                          ? DecorationImage(
                              image: FileImage(_localCover!),
                              fit: BoxFit.cover,
                            )
                          : (_coverUrl != null
                              ? DecorationImage(
                                  image: CachedNetworkImageProvider(_coverUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null),
                    ),
                    child: _localCover == null && _coverUrl == null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(LucideIcons.image,
                                    size: 40,
                                    color: scheme.onSurfaceVariant
                                        .withValues(alpha: 0.5)),
                                const SizedBox(height: 8),
                                Text(
                                  'Add Cover Photo',
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                            ),
                            child: const Center(
                              child: Icon(LucideIcons.camera,
                                  color: Colors.white, size: 30),
                            ),
                          ),
                  ),
                ),

                // Profile Picture (Circle)
                Positioned(
                  bottom: 0,
                  left: 24,
                  child: GestureDetector(
                    onTap: _pickAvatar,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: scheme.primaryContainer,
                        backgroundImage: _localAvatar != null
                            ? FileImage(_localAvatar!) as ImageProvider
                            : (_avatarUrl != null
                                ? CachedNetworkImageProvider(_avatarUrl!)
                                    as ImageProvider
                                : null),
                        child: _localAvatar == null && _avatarUrl == null
                            ? Icon(LucideIcons.user,
                                size: 40, color: scheme.onPrimaryContainer)
                            : Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Icon(LucideIcons.camera,
                                      color: Colors.white, size: 24),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 60), // Space for the overlapping avatar

            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Display Name',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _displayNameController,
                    decoration: InputDecoration(
                      hintText: 'Enter your name',
                      filled: true,
                      fillColor: scheme.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(LucideIcons.user),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Info Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.info, color: scheme.primary),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Your profile picture and cover photo are public. Others can see them when you interact in study groups or share plans.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
