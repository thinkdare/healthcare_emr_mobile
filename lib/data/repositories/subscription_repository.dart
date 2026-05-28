import '../../core/api/api_client.dart';
import '../models/subscription_models.dart';

/// SubscriptionRepository
///
/// Covers the billing API under /api/v1/billing/...
///
/// Access rules (enforced server-side):
///   - GET /billing/plans  — public, no auth
///   - All org-scoped routes — org admin or super admin only
///   - Regular staff will receive a 403
///
class SubscriptionRepository {
  final ApiClient apiClient;

  SubscriptionRepository({required this.apiClient});

  // ── Plans (public) ────────────────────────────────────────────────────────

  Future<List<SubscriptionPlanModel>> getPlans() async {
    final response = await apiClient.get('/billing/plans');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to get plans');
    }
    final data = response['data'] as List? ?? [];
    return data
        .map((e) => SubscriptionPlanModel.fromJson(
            Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<SubscriptionPlanModel> getPlan(String planId) async {
    final response = await apiClient.get('/billing/plans/$planId');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to get plan');
    }
    return SubscriptionPlanModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  // ── Subscriptions ─────────────────────────────────────────────────────────

  /// GET /billing/organizations/{orgId}/subscription
  Future<SubscriptionModel?> getSubscription(String orgId) async {
    try {
      final response = await apiClient.get(
          '/billing/organizations/$orgId/subscription');
      if (response['success'] != true) return null;
      return SubscriptionModel.fromJson(
          Map<String, dynamic>.from(response['data'] as Map));
    } catch (_) {
      return null;
    }
  }

  /// POST /billing/organizations/{orgId}/subscriptions/trial
  Future<SubscriptionModel> startTrial(
    String orgId, {
    required String planId,
    int? trialDays,
  }) async {
    final response = await apiClient.post(
      '/billing/organizations/$orgId/subscriptions/trial',
      data: {
        'plan_id': planId,
        'trial_days': ?trialDays,
      },
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to start trial');
    }
    return SubscriptionModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  /// POST /billing/organizations/{orgId}/subscriptions/{subId}/change-plan
  Future<SubscriptionModel> changePlan(
    String orgId,
    String subId, {
    required String planId,
  }) async {
    final response = await apiClient.post(
      '/billing/organizations/$orgId/subscriptions/$subId/change-plan',
      data: {'plan_id': planId},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to change plan');
    }
    return SubscriptionModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  /// DELETE /billing/organizations/{orgId}/subscriptions/{subId}
  Future<void> cancelSubscription(
    String orgId,
    String subId, {
    bool immediately = false,
  }) async {
    final response = await apiClient.delete(
      '/billing/organizations/$orgId/subscriptions/$subId',
      data: {'immediately': immediately},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to cancel subscription');
    }
  }

  // ── Invoices ──────────────────────────────────────────────────────────────

  /// GET /billing/organizations/{orgId}/invoices
  Future<List<InvoiceModel>> getInvoices(
    String orgId, {
    int page = 1,
    String? status,
  }) async {
    final response = await apiClient.get(
      '/billing/organizations/$orgId/invoices',
      queryParameters: {
        'page': page,
        'status': ?status,
      },
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to get invoices');
    }
    // Paginated response — data lives inside data.data
    final rawData = response['data'];
    final list = rawData is Map && rawData.containsKey('data')
        ? rawData['data'] as List? ?? []
        : rawData as List? ?? [];
    return list
        .map((e) =>
            InvoiceModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// GET /billing/organizations/{orgId}/invoices/{id}
  Future<InvoiceModel> getInvoice(String orgId, String invoiceId) async {
    final response = await apiClient.get(
        '/billing/organizations/$orgId/invoices/$invoiceId');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to get invoice');
    }
    return InvoiceModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  /// POST /billing/organizations/{orgId}/checkout-session
  /// Returns { checkout_url, reference, gateway }
  Future<Map<String, dynamic>> createCheckoutSession(
    String orgId, {
    required String planId,
    required String gateway,
  }) async {
    final response = await apiClient.post(
      '/billing/organizations/$orgId/checkout-session',
      data: {'plan_id': planId, 'gateway': gateway},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to create checkout session');
    }
    return Map<String, dynamic>.from(response['data'] as Map);
  }

  /// POST /billing/verify-payment
  /// Called after the deep link return to confirm payment and activate subscription.
  Future<SubscriptionModel> verifyPayment({
    required String reference,
    required String gateway,
    String? transactionId, // Flutterwave
    String? sessionId,     // Stripe
  }) async {
    final response = await apiClient.post('/billing/verify-payment', data: {
      'reference': reference,
      'gateway':   gateway,
      'transaction_id': ?transactionId,
      'session_id':     ?sessionId,
    });
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Payment verification failed');
    }
    return SubscriptionModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }
}
