import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notebook_llm/features/gitu/models/gitu_permission.dart';
import 'package:notebook_llm/features/gitu/models/gitu_permission_request.dart';
import 'package:notebook_llm/features/gitu/permissions_screen.dart';
import 'package:notebook_llm/features/gitu/services/gitu_permissions_service.dart';

class FakeRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestGituPermissionsService extends GituPermissionsService {
  List<GituPermission> permissions;
  List<GituPermissionRequest> requests;

  TestGituPermissionsService({
    required this.permissions,
    required this.requests,
  }) : super(FakeRef());

  @override
  Future<List<GituPermission>> listPermissions({String? resource}) async {
    final filtered = resource == null ? permissions : permissions.where((p) => p.resource == resource).toList();
    return filtered;
  }

  @override
  Future<void> revokePermission(String permissionId) async {
    permissions = permissions
        .map((p) => p.id == permissionId
            ? GituPermission(
                id: p.id,
                resource: p.resource,
                actions: p.actions,
                scope: p.scope,
                grantedAt: p.grantedAt,
                expiresAt: p.expiresAt,
                revokedAt: DateTime.now(),
              )
            : p)
        .toList();
  }

  @override
  Future<List<GituPermissionRequest>> listRequests({String? status}) async {
    if (status == null) return requests;
    return requests.where((r) => r.status == status).toList();
  }

  @override
  Future<GituPermission> approveRequest(String requestId, {int? expiresInDays}) async {
    final reqIndex = requests.indexWhere((r) => r.id == requestId);
    final req = requests[reqIndex];
    final now = DateTime.now();
    requests = [
      for (final r in requests)
        if (r.id == requestId)
          GituPermissionRequest(
            id: r.id,
            permission: r.permission,
            reason: r.reason,
            status: 'approved',
            requestedAt: r.requestedAt,
            respondedAt: now,
            grantedPermissionId: 'granted-${r.id}',
          )
        else
          r,
    ];
    final granted = GituPermission(
      id: 'granted-${req.id}',
      resource: req.permission.resource,
      actions: req.permission.actions,
      scope: req.permission.scope,
      grantedAt: now,
      expiresAt: req.permission.expiresAt,
      revokedAt: null,
    );
    permissions = [granted, ...permissions];
    return granted;
  }

  @override
  Future<void> denyRequest(String requestId) async {
    final now = DateTime.now();
    requests = [
      for (final r in requests)
        if (r.id == requestId)
          GituPermissionRequest(
            id: r.id,
            permission: r.permission,
            reason: r.reason,
            status: 'denied',
            requestedAt: r.requestedAt,
            respondedAt: now,
            grantedPermissionId: r.grantedPermissionId,
          )
        else
          r,
    ];
  }
}

void main() {
  testWidgets('Permissions screen shows granted permissions and requests', (tester) async {
    final now = DateTime.now();
    final service = TestGituPermissionsService(
      permissions: [
        GituPermission(
          id: 'p1',
          resource: 'files',
          actions: const ['read'],
          scope: const {'allowedPaths': ['*']},
          grantedAt: now,
          expiresAt: now.add(const Duration(days: 1)),
          revokedAt: null,
        ),
        GituPermission(
          id: 'p2',
          resource: 'shell',
          actions: const ['execute'],
          scope: const {'allowedCommands': ['echo']},
          grantedAt: now,
          expiresAt: now.add(const Duration(days: 1)),
          revokedAt: now,
        ),
      ],
      requests: [
        GituPermissionRequest(
          id: 'r1',
          permission: GituRequestedPermission(
            resource: 'gmail',
            actions: const ['read'],
            scope: const {'emailLabels': ['INBOX']},
            expiresAt: now.add(const Duration(days: 2)),
          ),
          reason: 'Need to read emails',
          status: 'pending',
          requestedAt: now,
          respondedAt: null,
          grantedPermissionId: null,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gituPermissionsServiceProvider.overrideWithValue(service),
        ],
        child: const MaterialApp(home: GituPermissionsScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Permissions'), findsOneWidget);
    expect(find.text('Granted'), findsOneWidget);
    expect(find.text('Requests'), findsOneWidget);

    expect(find.text('files'), findsOneWidget);
    expect(find.text('shell'), findsNothing);

    await tester.tap(find.text('Requests'));
    await tester.pumpAndSettle();

    expect(find.textContaining('gmail'), findsOneWidget);
    expect(find.textContaining('Need to read emails'), findsOneWidget);

    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Granted'));
    await tester.pumpAndSettle();

    expect(find.text('gmail'), findsOneWidget);
  });
}

