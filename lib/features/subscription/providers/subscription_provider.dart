import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_service.dart';
import '../services/subscription_service.dart';
import '../models/subscription_model.dart';
import '../models/credit_package_model.dart';
import '../models/credit_transaction_model.dart';

// Current User Subscription Provider
final userSubscriptionProvider =
    StreamProvider<SubscriptionModel?>((ref) async* {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    developer.log('[SUB] No user logged in', name: 'SubscriptionProvider');
    yield null;
    return;
  }

  final service = ref.watch(subscriptionServiceProvider);
  final userId = user['id'] as String;
  developer.log('[SUB] Fetching subscription for user: $userId',
      name: 'SubscriptionProvider');

  // Initial fetch
  try {
    final subscription = await service.getUserSubscription(userId);
    developer.log('[SUB] Got subscription: ${subscription?.planName ?? "null"}',
        name: 'SubscriptionProvider');
    yield subscription;
  } catch (e) {
    developer.log('[SUB] Error fetching subscription: $e',
        name: 'SubscriptionProvider');
    yield null;
  }

  // Refresh every 30 seconds
  await for (final _ in Stream.periodic(const Duration(seconds: 30))) {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;
    try {
      yield await service.getUserSubscription(currentUser['id'] as String);
    } catch (e) {
      developer.log('[SUB] Error refreshing subscription: $e',
          name: 'SubscriptionProvider');
    }
  }
});

// Credit Balance Provider (simplified access)
final creditBalanceProvider = Provider<int>((ref) {
  final subscription = ref.watch(userSubscriptionProvider).value;
  return subscription?.currentCredits ?? 0;
});

// Active Credit Packages Provider
final creditPackagesProvider =
    FutureProvider<List<CreditPackageModel>>((ref) async {
  final service = ref.watch(subscriptionServiceProvider);
  return await service.getActivePackages();
});

// Transaction History Provider
final transactionHistoryProvider =
    FutureProvider.family<List<CreditTransactionModel>, String>(
        (ref, userId) async {
  final service = ref.watch(subscriptionServiceProvider);
  return await service.getTransactionHistory(userId);
});

// Check if user has enough credits
final hasEnoughCreditsProvider =
    FutureProvider.family<bool, int>((ref, required) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;

  final service = ref.watch(subscriptionServiceProvider);
  return await service.hasEnoughCredits(user['id'] as String, required);
});

// Available Subscription Plans Provider
final subscriptionPlansProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final service = ref.watch(subscriptionServiceProvider);
  return await service.getPublicPlans();
});
