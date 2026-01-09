import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_service.dart';
import '../../core/auth/custom_auth_service.dart';
import '../../core/utils/app_logger.dart';

const _logger = AppLogger('ProfileProvider');

class ProfileState {
  final bool isUpdating;
  final String? error;
  final String? successMessage;

  ProfileState({
    this.isUpdating = false,
    this.error,
    this.successMessage,
  });

  ProfileState copyWith({
    bool? isUpdating,
    String? error,
    String? successMessage,
  }) {
    return ProfileState(
      isUpdating: isUpdating ?? this.isUpdating,
      error: error,
      successMessage: successMessage,
    );
  }
}

class ProfileNotifier extends StateNotifier<ProfileState> {
  final ApiService _api;
  final Ref _ref;

  ProfileNotifier(this._api, this._ref) : super(ProfileState());

  Future<void> updateProfile({
    String? displayName,
    String? avatarUrl,
    String? coverUrl,
  }) async {
    state = state.copyWith(isUpdating: true, error: null, successMessage: null);
    try {
      final authUser = _ref.read(customAuthStateProvider).user;
      if (authUser == null) throw Exception('User not authenticated');

      await _ref.read(customAuthServiceProvider).updateProfile(
            userId: authUser.uid,
            displayName: displayName,
            avatarUrl: avatarUrl,
            coverUrl: coverUrl,
          );

      state = state.copyWith(
        isUpdating: false,
        successMessage: 'Profile updated successfully',
      );
    } catch (e) {
      _logger.error('Error updating profile', e);
      state = state.copyWith(
        isUpdating: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<String?> uploadImage(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final base64Data = base64Encode(bytes);
      final filename = file.path.split('/').last;

      final response = await _api.uploadMediaDirect(
        base64Data: base64Data,
        filename: filename,
        type: 'image',
      );

      if (response['success'] == true) {
        return response['url'] as String?;
      }
      return null;
    } catch (e) {
      _logger.error('Error uploading image', e);
      return null;
    }
  }
}

final profileProvider =
    StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  return ProfileNotifier(ref.watch(apiServiceProvider), ref);
});
