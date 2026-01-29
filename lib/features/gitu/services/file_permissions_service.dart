import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_service.dart';
import '../models/file_audit_log.dart';
import '../models/file_permissions_status.dart';

final filePermissionsServiceProvider = Provider<FilePermissionsService>((ref) {
  return FilePermissionsService(ref);
});

class FilePermissionsService {
  final Ref _ref;

  FilePermissionsService(this._ref);

  Future<FilePermissionsStatus> getStatus() async {
    final apiService = _ref.read(apiServiceProvider);
    final response = await apiService.get<Map<String, dynamic>>('/gitu/files/permissions');
    return FilePermissionsStatus.fromJson(response);
  }

  Future<FilePermissionsStatus> updateAllowedPaths(List<String> allowedPaths) async {
    final apiService = _ref.read(apiServiceProvider);
    final response = await apiService.put<Map<String, dynamic>>('/gitu/files/permissions', {
      'allowedPaths': allowedPaths,
    });
    return FilePermissionsStatus.fromJson(response);
  }

  Future<void> revoke() async {
    final apiService = _ref.read(apiServiceProvider);
    await apiService.post<Map<String, dynamic>>('/gitu/files/permissions/revoke', {});
  }

  Future<List<FileAuditLog>> listAuditLogs({
    int limit = 50,
    int offset = 0,
    String? action,
    bool? success,
    String? pathPrefix,
  }) async {
    final apiService = _ref.read(apiServiceProvider);
    final params = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };
    if (action != null) params['action'] = action;
    if (success != null) params['success'] = success.toString();
    if (pathPrefix != null && pathPrefix.trim().isNotEmpty) params['pathPrefix'] = pathPrefix.trim();

    final response = await apiService.get<Map<String, dynamic>>(
      '/gitu/files/audit-logs',
      queryParameters: params,
    );
    final logs = (response['logs'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? const [];
    return logs.map(FileAuditLog.fromJson).toList();
  }
}

