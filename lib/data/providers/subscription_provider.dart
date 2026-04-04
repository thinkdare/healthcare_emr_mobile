import 'package:flutter/material.dart';
import '../models/subscription_models.dart';
import '../models/organization_models_enhanced.dart';
import '../repositories/subscription_repository.dart';

class SubscriptionProvider extends ChangeNotifier {
  final SubscriptionRepository repository;

  SubscriptionProvider({required this.repository});

  TrialStatusModel? _trialStatus;
  SubscriptionModel? _subscription;
  PricingDisplayModel? _pricing;
  QuoteModel? _quote;
  List<InvoiceModel> _invoices = [];
  
  bool _isLoading = false;
  String? _error;

  TrialStatusModel? get trialStatus => _trialStatus;
  SubscriptionModel? get subscription => _subscription;
  PricingDisplayModel? get pricing => _pricing;
  QuoteModel? get quote => _quote;
  List<InvoiceModel> get invoices => _invoices;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool get isOnTrial => _trialStatus?.onTrial ?? false;
  bool get isActive => _trialStatus?.isActive ?? false;
  int get trialDaysRemaining => _trialStatus?.trialDaysRemaining ?? 0;

  /// Load trial status
  Future<void> loadTrialStatus() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _trialStatus = await repository.getTrialStatus();
      _error = null;
    } catch (e) {
      _error = e.toString();
      _trialStatus = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load current subscription
  Future<void> loadSubscription() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _subscription = await repository.getCurrentSubscription();
      _error = null;
    } catch (e) {
      _error = e.toString();
      _subscription = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load pricing
  Future<void> loadPricing() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _pricing = await repository.getPricing();
      _error = null;
    } catch (e) {
      _error = e.toString();
      _pricing = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Calculate quote
  Future<void> calculateQuote({
    required int numFacilities,
    required int numProviders,
    required String billingCycle,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _quote = await repository.calculateQuote(
        numFacilities: numFacilities,
        numProviders: numProviders,
        billingCycle: billingCycle,
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
      _quote = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Register organization
  Future<OrganizationRegistrationResponseModel?> registerOrganization({
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
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await repository.registerOrganization(
        organizationName: organizationName,
        organizationType: organizationType,
        address: address,
        phone: phone,
        email: email,
        taxId: taxId,
        adminFirstName: adminFirstName,
        adminLastName: adminLastName,
        adminEmail: adminEmail,
        adminPhone: adminPhone,
        adminPassword: adminPassword,
        numFacilities: numFacilities,
        numProviders: numProviders,
        billingCycle: billingCycle,
      );
      _error = null;
      _isLoading = false;
      notifyListeners();
      return response;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Create upgrade checkout
  Future<Map<String, String>?> createUpgradeCheckout({
    required String billingCycle,
    String? successUrl,
    String? cancelUrl,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await repository.createUpgradeCheckout(
        billingCycle: billingCycle,
        successUrl: successUrl,
        cancelUrl: cancelUrl,
      );
      _error = null;
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Cancel subscription
  Future<bool> cancelSubscription({bool immediately = false}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await repository.cancelSubscription(immediately: immediately);
      // Reload subscription status
      await loadSubscription();
      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Resume subscription
  Future<bool> resumeSubscription() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await repository.resumeSubscription();
      // Reload subscription status
      await loadSubscription();
      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Load invoices
  Future<void> loadInvoices({int page = 1}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _invoices = await repository.getInvoices(page: page);
      _error = null;
    } catch (e) {
      _error = e.toString();
      _invoices = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}