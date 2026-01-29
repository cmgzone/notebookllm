import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_service.dart';
import 'gitu_settings_model.dart';

final gituSettingsProvider =
    StateNotifierProvider<GituSettingsNotifier, AsyncValue<GituSettings>>(
  (ref) => GituSettingsNotifier(ref),
);

class GituSettingsNotifier extends StateNotifier<AsyncValue<GituSettings>> {
  final Ref _ref;

  GituSettingsNotifier(this._ref) : super(const AsyncValue.loading()) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    try {
      state = const AsyncValue.loading();
      final apiService = _ref.read(apiServiceProvider);
      final response = await apiService.get<Map<String, dynamic>>('/gitu/settings');
      
      final settings = GituSettings.fromJson(response);
      state = AsyncValue.data(settings);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateSettings(GituSettings newSettings) async {
    final previous = state;
    state = AsyncValue.data(newSettings);
    try {
      final apiService = _ref.read(apiServiceProvider);
      await apiService.post('/gitu/settings', newSettings.toJson());
    } catch (_) {
      state = previous;
    }
  }
  
  Future<void> toggleEnabled(bool enabled) async {
    final current = state.value;
    if (current == null) return;
    
    await updateSettings(current.copyWith(enabled: enabled));
  }
  
  Future<void> updateModelPreferences(ModelPreferences prefs) async {
    final current = state.value;
    if (current == null) return;
    
    await updateSettings(current.copyWith(modelPreferences: prefs));
  }
}
