import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_service.dart';
import '../models/linked_account.dart';

final identityServiceProvider = Provider<IdentityService>((ref) {
  return IdentityService(ref);
});

final linkedAccountsProvider = FutureProvider.autoDispose<List<LinkedAccount>>((ref) async {
  final service = ref.watch(identityServiceProvider);
  return service.listLinked();
});

class IdentityService {
  final Ref _ref;
  IdentityService(this._ref);

  Future<List<LinkedAccount>> listLinked() async {
    final api = _ref.read(apiServiceProvider);
    final res = await api.get<Map<String, dynamic>>('/gitu/identity/linked');
    final List<dynamic> arr = res['accounts'] ?? [];
    return arr.map((j) => LinkedAccount.fromJson(j)).toList();
  }

  Future<LinkedAccount> link(String platform, String platformUserId, {String? displayName}) async {
    final api = _ref.read(apiServiceProvider);
    final res = await api.post<Map<String, dynamic>>('/gitu/identity/link', {
      'platform': platform,
      'platformUserId': platformUserId,
      'displayName': displayName,
    });
    return LinkedAccount.fromJson(res['account']);
  }

  Future<void> unlink(String platform, String platformUserId) async {
    final api = _ref.read(apiServiceProvider);
    await api.post<Map<String, dynamic>>('/gitu/identity/unlink', {
      'platform': platform,
      'platformUserId': platformUserId,
    });
  }

  Future<LinkedAccount> setPrimary(String platform, String platformUserId) async {
    final api = _ref.read(apiServiceProvider);
    final res = await api.post<Map<String, dynamic>>('/gitu/identity/set-primary', {
      'platform': platform,
      'platformUserId': platformUserId,
    });
    return LinkedAccount.fromJson(res['account']);
  }

  Future<LinkedAccount> verify(String platform, String platformUserId) async {
    final api = _ref.read(apiServiceProvider);
    final res = await api.post<Map<String, dynamic>>('/gitu/identity/verify', {
      'platform': platform,
      'platformUserId': platformUserId,
    });
    return LinkedAccount.fromJson(res['account']);
  }
}
