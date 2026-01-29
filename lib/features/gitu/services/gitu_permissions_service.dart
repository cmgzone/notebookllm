import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_service.dart';
import '../models/gitu_permission.dart';
import '../models/gitu_permission_request.dart';

final gituPermissionsServiceProvider = Provider<GituPermissionsService>((ref) {
  return GituPermissionsService(ref);
});

class GituPermissionsService {
  final Ref _ref;

  GituPermissionsService(this._ref);

  Future<List<GituPermission>> listPermissions({String? resource}) async {
    final apiService = _ref.read(apiServiceProvider);
    final response = await apiService.get<Map<String, dynamic>>(
      '/gitu/permissions',
      queryParameters: resource != null ? {'resource': resource} : null,
    );
    final items = (response['permissions'] as List?)?.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList() ?? const [];
    return items.map(GituPermission.fromJson).toList();
  }

  Future<void> revokePermission(String permissionId) async {
    final apiService = _ref.read(apiServiceProvider);
    await apiService.post<Map<String, dynamic>>('/gitu/permissions/$permissionId/revoke', {});
  }

  Future<List<GituPermissionRequest>> listRequests({String? status}) async {
    final apiService = _ref.read(apiServiceProvider);
    final response = await apiService.get<Map<String, dynamic>>(
      '/gitu/permissions/requests',
      queryParameters: status != null ? {'status': status} : null,
    );
    final items = (response['requests'] as List?)?.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList() ?? const [];
    return items.map(GituPermissionRequest.fromJson).toList();
  }

  Future<GituPermission> approveRequest(String requestId, {int? expiresInDays}) async {
    final apiService = _ref.read(apiServiceProvider);
    final body = <String, dynamic>{};
    if (expiresInDays != null) body['expiresInDays'] = expiresInDays;
    final response = await apiService.post<Map<String, dynamic>>('/gitu/permissions/requests/$requestId/approve', body);
    return GituPermission.fromJson((response['permission'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{});
  }

  Future<void> denyRequest(String requestId) async {
    final apiService = _ref.read(apiServiceProvider);
    await apiService.post<Map<String, dynamic>>('/gitu/permissions/requests/$requestId/deny', {});
  }
}

