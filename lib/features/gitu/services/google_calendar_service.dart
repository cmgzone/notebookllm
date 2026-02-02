import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_service.dart';
import '../models/google_calendar_connection.dart';

final googleCalendarServiceProvider = Provider<GoogleCalendarService>((ref) {
  return GoogleCalendarService(ref);
});

final googleCalendarStatusProvider =
    FutureProvider.autoDispose<GoogleCalendarStatus>((ref) async {
  final service = ref.watch(googleCalendarServiceProvider);
  return service.getStatus();
});

class GoogleCalendarService {
  final Ref _ref;
  GoogleCalendarService(this._ref);

  Future<GoogleCalendarStatus> getStatus() async {
    final api = _ref.read(apiServiceProvider);
    final res = await api.get<Map<String, dynamic>>('/gitu/calendar/status');
    return GoogleCalendarStatus.fromJson(res);
  }

  Future<String> getAuthUrl() async {
    final api = _ref.read(apiServiceProvider);
    final res = await api.get<Map<String, dynamic>>('/gitu/calendar/auth-url');
    return res['authUrl'] as String;
  }

  Future<void> disconnect() async {
    final api = _ref.read(apiServiceProvider);
    await api.post<Map<String, dynamic>>('/gitu/calendar/disconnect', {});
  }
}

