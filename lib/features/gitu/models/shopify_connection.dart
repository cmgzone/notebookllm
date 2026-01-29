class ShopifyConnectionStatus {
  final bool connected;
  final ShopifyShop? shop;

  ShopifyConnectionStatus({required this.connected, this.shop});

  factory ShopifyConnectionStatus.fromJson(Map<String, dynamic> json) {
    return ShopifyConnectionStatus(
      connected: json['connected'] ?? false,
      shop: json['shop'] != null ? ShopifyShop.fromJson(json['shop']) : null,
    );
  }
}

class ShopifyShop {
  final String storeDomain;
  final String name;
  final String? email;
  final String? plan;
  final DateTime? connectedAt;

  ShopifyShop({
    required this.storeDomain,
    required this.name,
    this.email,
    this.plan,
    this.connectedAt,
  });

  factory ShopifyShop.fromJson(Map<String, dynamic> json) {
    return ShopifyShop(
      storeDomain: json['storeDomain'] ?? '',
      name: json['name'] ?? '',
      email: json['email'],
      plan: json['plan'],
      connectedAt: json['connectedAt'] != null ? DateTime.parse(json['connectedAt']) : null,
    );
  }
}
