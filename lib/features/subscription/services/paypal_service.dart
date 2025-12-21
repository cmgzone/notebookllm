import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_paypal_payment/flutter_paypal_payment.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/credit_package_model.dart';
import '../services/subscription_service.dart';

class PayPalService {
  final SubscriptionService _subscriptionService;
  static const _storage = FlutterSecureStorage();

  String? _clientId;
  String? _secretKey;
  bool _sandboxMode = true;

  PayPalService(this._subscriptionService);

  /// Initialize PayPal with credentials from secure storage
  Future<void> initialize() async {
    try {
      _clientId = await _storage.read(key: 'paypal_client_id');
      _secretKey = await _storage.read(key: 'paypal_secret');

      // Default to sandbox mode for safety
      final sandboxModeStr = await _storage.read(key: 'paypal_sandbox_mode');
      _sandboxMode = sandboxModeStr != 'false';

      developer.log(
        'PayPal initialized: clientId=${_clientId != null}, sandbox=$_sandboxMode',
        name: 'PayPalService',
      );
    } catch (e) {
      developer.log('Failed to initialize PayPal: $e', name: 'PayPalService');
    }
  }

  bool get isConfigured => _clientId != null && _secretKey != null;

  /// Process payment for a credit package
  Future<void> purchasePackage({
    required BuildContext context,
    required CreditPackageModel package,
    required String userId,
    required Function(String transactionId) onSuccess,
    required Function(String error) onError,
  }) async {
    if (!isConfigured) {
      onError(
          'PayPal is not configured. Please add credentials in admin panel.');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (BuildContext ctx) => PaypalCheckoutView(
          sandboxMode: _sandboxMode,
          clientId: _clientId!,
          secretKey: _secretKey!,
          transactions: [
            {
              "amount": {
                "total": package.price.toStringAsFixed(2),
                "currency": "USD",
                "details": {
                  "subtotal": package.price.toStringAsFixed(2),
                  "shipping": '0',
                  "shipping_discount": 0,
                }
              },
              "description":
                  "Purchase ${package.credits} credits - ${package.name}",
              "item_list": {
                "items": [
                  {
                    "name": package.name,
                    "quantity": 1,
                    "price": package.price.toStringAsFixed(2),
                    "currency": "USD"
                  }
                ],
              }
            }
          ],
          note: "Credit purchase for ${package.name}",
          onSuccess: (Map params) async {
            developer.log('Payment successful: $params', name: 'PayPalService');

            final paymentId = params["paymentId"] as String? ?? '';

            try {
              // Add credits via the subscription service
              await _subscriptionService.addCredits(
                userId: userId,
                amount: package.credits,
                packageId: package.id,
                transactionId: paymentId,
              );

              if (ctx.mounted) {
                Navigator.pop(ctx);
                onSuccess(paymentId);
              }
            } catch (e) {
              developer.log('Error completing purchase: $e',
                  name: 'PayPalService');
              if (ctx.mounted) {
                Navigator.pop(ctx);
                onError('Payment succeeded but failed to add credits: $e');
              }
            }
          },
          onError: (error) {
            developer.log('Payment error: $error', name: 'PayPalService');
            Navigator.pop(ctx);
            onError(error.toString());
          },
          onCancel: () {
            developer.log('Payment cancelled', name: 'PayPalService');
            Navigator.pop(ctx);
            onError('Payment was cancelled');
          },
        ),
      ),
    );
  }

  /// Process a generic payment (for plan upgrades)
  /// Returns transaction ID on success, null on failure/cancel
  Future<String?> processPayment({
    required BuildContext context,
    required double amount,
    required String currency,
    required String description,
  }) async {
    if (!isConfigured) {
      throw Exception('PayPal is not configured');
    }

    String? transactionId;
    bool completed = false;
    String? errorMessage;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => PaypalCheckoutView(
          sandboxMode: _sandboxMode,
          clientId: _clientId!,
          secretKey: _secretKey!,
          transactions: [
            {
              'amount': {
                'total': amount.toStringAsFixed(2),
                'currency': currency,
              },
              'description': description,
            }
          ],
          note: description,
          onSuccess: (data) {
            developer.log('PayPal success: $data', name: 'PayPalService');
            transactionId =
                data['id'] ?? 'paypal_${DateTime.now().millisecondsSinceEpoch}';
            completed = true;
            Navigator.pop(ctx);
          },
          onError: (error) {
            developer.log('PayPal error: $error', name: 'PayPalService');
            errorMessage = error.toString();
            Navigator.pop(ctx);
          },
          onCancel: () {
            developer.log('PayPal cancelled', name: 'PayPalService');
            Navigator.pop(ctx);
          },
        ),
      ),
    );

    if (errorMessage != null) {
      throw Exception(errorMessage);
    }

    return completed ? transactionId : null;
  }
}
