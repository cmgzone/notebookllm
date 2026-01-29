import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_service.dart';
import '../models/gmail_connection.dart';

final gmailServiceProvider = Provider<GmailService>((ref) {
  return GmailService(ref);
});

final gmailStatusProvider = FutureProvider.autoDispose<GmailStatus>((ref) async {
  final service = ref.watch(gmailServiceProvider);
  return service.getStatus();
});

class GmailService {
  final Ref _ref;
  GmailService(this._ref);

  Future<GmailStatus> getStatus() async {
    final api = _ref.read(apiServiceProvider);
    final res = await api.get<Map<String, dynamic>>('/gitu/gmail/status');
    return GmailStatus.fromJson(res);
  }

  Future<String> getAuthUrl() async {
    final api = _ref.read(apiServiceProvider);
    final res = await api.get<Map<String, dynamic>>('/gitu/gmail/auth-url');
    return res['authUrl'] as String;
  }

  Future<void> disconnect() async {
    final api = _ref.read(apiServiceProvider);
    await api.post<Map<String, dynamic>>('/gitu/gmail/disconnect', {});
  }
}
