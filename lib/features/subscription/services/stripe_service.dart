import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/credit_package_model.dart';
import 'subscription_service.dart';

class StripeService {
  final SubscriptionService _subscriptionService;

  // Backend API URL
  static const String _baseUrl = 'https://notebookllm-ufj7.onrender.com/api';

  String? _publishableKey;
  String? _secretKey;
  bool _testMode = true;
  bool _initialized = false;

  StripeService(this._subscriptionService, dynamic _);

  /// Initialize Stripe with credentials from backend
  Future<void> initialize() async {
    try {
      developer.log('Stripe: Fetching config from backend...',
          name: 'StripeService');

      final response = await http.get(
        Uri.parse('$_baseUrl/subscriptions/payment-config'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final stripeConfig = data['config']?['stripe'];

        if (stripeConfig != null) {
          _publishableKey = stripeConfig['publishableKey'];
          _secretKey = stripeConfig['secretKey'];
          _testMode = stripeConfig['testMode'] ?? true;

          // Initialize Stripe SDK if we have a key
          if (_publishableKey != null && _publishableKey!.isNotEmpty) {
            Stripe.publishableKey = _publishableKey!;
            await Stripe.instance.applySettings();
            _initialized = true;
          }

          developer.log(
            'Stripe initialized from backend: publishableKey=${_publishableKey != null && _publishableKey!.isNotEmpty}, secretKey=${_secretKey != null && _secretKey!.isNotEmpty}, testMode=$_testMode',
            name: 'StripeService',
          );
        } else {
          developer.log('Stripe: No config in response', name: 'StripeService');
        }
      } else {
        developer.log('Stripe: Failed to fetch config - ${response.statusCode}',
            name: 'StripeService');
      }
    } catch (e) {
      developer.log('Failed to initialize Stripe: $e', name: 'StripeService');
    }
  }

  bool get isConfigured =>
      _initialized && _secretKey != null && _secretKey!.isNotEmpty;

  /// Create a payment intent on the server
  Future<Map<String, dynamic>?> _createPaymentIntent({
    required double amount,
    required String currency,
    required String userId,
    required String packageId,
  }) async {
    if (_secretKey == null) return null;

    try {
      // In production, this should call your backend server
      // For now, we'll create a simple payment intent
      final response = await http.post(
        Uri.parse('https://api.stripe.com/v1/payment_intents'),
        headers: {
          'Authorization': 'Bearer $_secretKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'amount': (amount * 100).toInt().toString(), // Convert to cents
          'currency': currency.toLowerCase(),
          'metadata[user_id]': userId,
          'metadata[package_id]': packageId,
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        developer.log(
          'Failed to create payment intent: ${response.body}',
          name: 'StripeService',
        );
        return null;
      }
    } catch (e) {
      developer.log('Error creating payment intent: $e', name: 'StripeService');
      return null;
    }
  }

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
          'Stripe is not configured. Please add credentials in admin panel.');
      return;
    }

    // Capture theme color before async operations
    final primaryColor = Theme.of(context).colorScheme.primary;

    try {
      // Create payment intent
      final paymentIntent = await _createPaymentIntent(
        amount: package.price,
        currency: 'USD',
        userId: userId,
        packageId: package.id,
      );

      if (paymentIntent == null) {
        onError('Failed to create payment. Please try again.');
        return;
      }

      final clientSecret = paymentIntent['client_secret'] as String;

      // Initialize payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Notebook LLM',
          style: ThemeMode.system,
          appearance: PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: primaryColor,
            ),
            shapes: const PaymentSheetShape(
              borderRadius: 12,
            ),
          ),
        ),
      );

      // Present payment sheet
      await Stripe.instance.presentPaymentSheet();

      // Payment successful - add credits
      final paymentIntentId = paymentIntent['id'] as String;

      final success = await _subscriptionService.addCredits(
        userId: userId,
        amount: package.credits,
        packageId: package.id,
        transactionId: paymentIntentId,
        paymentMethod: 'stripe',
      );

      if (success) {
        onSuccess(paymentIntentId);
      } else {
        onError('Payment succeeded but failed to add credits');
      }
    } on StripeException catch (e) {
      developer.log('Stripe error: ${e.error.message}', name: 'StripeService');

      if (e.error.code == FailureCode.Canceled) {
        onError('Payment was cancelled');
      } else {
        onError(e.error.message ?? 'Payment failed');
      }
    } catch (e) {
      developer.log('Payment error: $e', name: 'StripeService');
      onError('An unexpected error occurred: $e');
    }
  }

  /// Process a generic payment (for plan upgrades)
  Future<bool> processPayment({
    required BuildContext context,
    required double amount,
    required String currency,
    required String description,
  }) async {
    if (!isConfigured) {
      throw Exception('Stripe is not configured');
    }

    final primaryColor = Theme.of(context).colorScheme.primary;

    try {
      // Create payment intent
      final paymentIntent = await _createPaymentIntent(
        amount: amount,
        currency: currency,
        userId: 'plan_upgrade',
        packageId: 'upgrade',
      );

      if (paymentIntent == null) {
        throw Exception('Failed to create payment intent');
      }

      final clientSecret = paymentIntent['client_secret'] as String;

      // Initialize payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Notebook LLM',
          style: ThemeMode.system,
          appearance: PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: primaryColor,
            ),
            shapes: const PaymentSheetShape(
              borderRadius: 12,
            ),
          ),
        ),
      );

      // Present payment sheet
      await Stripe.instance.presentPaymentSheet();

      return true;
    } on StripeException catch (e) {
      developer.log('Stripe error: ${e.error.message}', name: 'StripeService');
      if (e.error.code == FailureCode.Canceled) {
        return false;
      }
      throw Exception(e.error.message ?? 'Payment failed');
    }
  }
}
