import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_service.dart';
import '../models/shopify_connection.dart';

final shopifyServiceProvider = Provider<ShopifyService>((ref) {
  return ShopifyService(ref);
});

final shopifyStatusProvider = FutureProvider.autoDispose<ShopifyConnectionStatus>((ref) async {
  final service = ref.watch(shopifyServiceProvider);
  return service.getStatus();
});

class ShopifyService {
  final Ref _ref;
  ShopifyService(this._ref);

  Future<ShopifyConnectionStatus> getStatus() async {
    final api = _ref.read(apiServiceProvider);
    final res = await api.get<Map<String, dynamic>>('/gitu/shopify/status');
    return ShopifyConnectionStatus.fromJson(res);
  }

  Future<void> connect(String storeDomain, String accessToken, String? apiVersion) async {
    final api = _ref.read(apiServiceProvider);
    await api.post<Map<String, dynamic>>('/gitu/shopify/connect', {
      'storeDomain': storeDomain,
      'accessToken': accessToken,
      'apiVersion': apiVersion,
    });
  }

  Future<void> disconnect() async {
    final api = _ref.read(apiServiceProvider);
    await api.post<Map<String, dynamic>>('/gitu/shopify/disconnect', {});
  }
}
