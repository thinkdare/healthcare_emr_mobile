import '../../core/api/api_client.dart';
import '../models/subscription_models.dart';
import '../models/organization_models_enhanced.dart';

class SubscriptionRepository {
  final ApiClient apiClient;

  SubscriptionRepository({required this.apiClient});

  /// Get pricing information
  Future<PricingDisplayModel> getPricing() async {
    final response = await apiClient.get('/registration/pricing');

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to get pricing');
    }

    return PricingDisplayModel.fromJson(
      Map<String, dynamic>.from(response['data']),
    );
  }

  /// Calculate quote
  Future<QuoteModel> calculateQuote({
    required int numFacilities,
    required int numProviders,
    required String billingCycle,
  }) async {
    final response = await apiClient.post(
      '/registration/calculate-quote',
      data: {
        'num_facilities': numFacilities,
        'num_providers': numProviders,
        'billing_cycle': billingCycle,
      },
    );

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to calculate quote');
    }

    return QuoteModel.fromJson(
      Map<String, dynamic>.from(response['data']),
    );
  }

  /// Register organization
  Future<OrganizationRegistrationResponseModel> registerOrganization({
    required String organizationName,
    required String organizationType,
    required String address,
    required String phone,
    required String email,
    String? taxId,
    required String adminFirstName,
    required String adminLastName,
    required String adminEmail,
    required String adminPhone,
    required String adminPassword,
    required int numFacilities,
    required int numProviders,
    required String billingCycle,
  }) async {
    final response = await apiClient.post(
      '/registration/organization',
      data: {
        'organization_name': organizationName,
        'organization_type': organizationType,
        'address': address,
        'phone': phone,
        'email': email,
        if (taxId != null && taxId.isNotEmpty) 'tax_id': taxId,
        'admin_first_name': adminFirstName,
        'admin_last_name': adminLastName,
        'admin_email': adminEmail,
        'admin_phone': adminPhone,
        'admin_password': adminPassword,
        'admin_password_confirmation': adminPassword,
        'num_facilities': numFacilities,
        'num_providers': numProviders,
        'billing_cycle': billingCycle,
      },
    );

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to register organization');
    }

    final data = Map<String, dynamic>.from(response['data']);
    
    // Save token
    await apiClient.saveToken(data['token']);

    return OrganizationRegistrationResponseModel.fromJson(data);
  }

  /// Get trial status
  Future<TrialStatusModel> getTrialStatus() async {
    final response = await apiClient.get('/registration/trial-status');

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to get trial status');
    }

    return TrialStatusModel.fromJson(
      Map<String, dynamic>.from(response['data']),
    );
  }

  /// Get current subscription
  Future<SubscriptionModel?> getCurrentSubscription() async {
    try {
      final response = await apiClient.get('/subscription');

      if (response['success'] != true) {
        return null;
      }

      final data = response['data'];
      if (data == null || data['subscription'] == null) {
        return null;
      }

      return SubscriptionModel.fromJson(
        Map<String, dynamic>.from(data['subscription']),
      );
    } catch (e) {
      print('Error getting subscription: $e');
      return null;
    }
  }

  /// Create upgrade checkout session
  Future<Map<String, String>> createUpgradeCheckout({
    required String billingCycle,
    String? successUrl,
    String? cancelUrl,
  }) async {
    final response = await apiClient.post(
      '/subscription/upgrade',
      data: {
        'billing_cycle': billingCycle,
        if (successUrl != null) 'success_url': successUrl,
        if (cancelUrl != null) 'cancel_url': cancelUrl,
      },
    );

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to create checkout session');
    }

    final data = Map<String, dynamic>.from(response['data']);
    return {
      'checkout_url': data['checkout_url'] as String,
      'session_id': data['session_id'] as String,
    };
  }

  /// Cancel subscription
  Future<void> cancelSubscription({bool immediately = false}) async {
    final response = await apiClient.post(
      '/subscription/cancel',
      data: {
        'immediately': immediately,
      },
    );

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to cancel subscription');
    }
  }

  /// Resume subscription
  Future<void> resumeSubscription() async {
    final response = await apiClient.post('/subscription/resume');

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to resume subscription');
    }
  }

  /// Get invoices
  Future<List<InvoiceModel>> getInvoices({int page = 1}) async {
    final response = await apiClient.get(
      '/subscription/invoices',
      queryParameters: {'page': page},
    );

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to get invoices');
    }

    final data = response['data'];
    if (data == null) {
      return [];
    }

    // Handle paginated response
    final invoices = data['data'] as List? ?? [];
    return invoices
        .map((e) => InvoiceModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}