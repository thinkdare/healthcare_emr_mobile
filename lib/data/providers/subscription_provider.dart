import 'package:flutter/material.dart';
import '../models/subscription_models.dart';
import '../repositories/subscription_repository.dart';

enum SubscriptionLoadState { initial, loading, loaded, error }

class SubscriptionProvider extends ChangeNotifier {
  final SubscriptionRepository repository;

  SubscriptionProvider({required this.repository});

  List<SubscriptionPlanModel> _plans = [];
  SubscriptionModel? _subscription;
  List<InvoiceModel> _invoices = [];

  bool _isLoading = false;
  String? _error;
  SubscriptionLoadState _subLoadState = SubscriptionLoadState.initial;

  List<SubscriptionPlanModel> get plans => _plans;
  SubscriptionModel? get subscription => _subscription;
  List<InvoiceModel> get invoices => _invoices;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool get isOnTrial => _subscription?.isTrial ?? false;
  bool get isActive => _subscription?.isActive ?? false;
  int get trialDaysRemaining => _subscription?.trialDaysRemaining ?? 0;
  SubscriptionLoadState get subLoadState => _subLoadState;

  /// Whether the org's plan includes Professional-tier features
  /// (cross-facility referrals, emergency access controls).
  ///
  /// Returns `null` while subscription data is loading or not yet fetched —
  /// callers MUST treat null as hidden/disabled (fail closed). Never renders
  /// a Professional feature to an unknown-plan user; a brief gap in a nav item
  /// is preferable to a Starter user accessing gated screens.
  ///
  /// Returns `true` during a trial — PROJECT_BRIEF grants full access for
  /// the 30-day free trial period regardless of which plan is being trialed.
  bool? get isProfessionalOrHigher {
    if (_subLoadState != SubscriptionLoadState.loaded) return null;
    if (_subscription == null) return null;
    if (_subscription!.isTrial) return true;
    final slug = _subscription!.plan?.slug.toLowerCase() ?? '';
    return !slug.contains('starter');
  }

  // ── Plans ─────────────────────────────────────────────────────────────────

  Future<void> loadPlans() async {
    _setLoading(true);
    try {
      _plans = await repository.getPlans();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // ── Subscription ──────────────────────────────────────────────────────────

  Future<void> loadSubscription(String orgId) async {
    _subLoadState = SubscriptionLoadState.loading;
    _setLoading(true);
    try {
      _subscription = await repository.getSubscription(orgId);
      _subLoadState = SubscriptionLoadState.loaded;
      _error = null;
    } catch (e) {
      _subLoadState = SubscriptionLoadState.error;
      _error = e.toString();
      _subscription = null;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> startTrial(
    String orgId, {
    required String planId,
    int? trialDays,
  }) async {
    _setLoading(true);
    try {
      _subscription = await repository.startTrial(
        orgId,
        planId: planId,
        trialDays: trialDays,
      );
      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> changePlan(
    String orgId,
    String subId, {
    required String planId,
  }) async {
    _setLoading(true);
    try {
      _subscription = await repository.changePlan(orgId, subId, planId: planId);
      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> cancelSubscription(
    String orgId,
    String subId, {
    bool immediately = false,
  }) async {
    _setLoading(true);
    try {
      await repository.cancelSubscription(orgId, subId, immediately: immediately);
      // Refresh after cancel
      _subscription = await repository.getSubscription(orgId);
      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Invoices ──────────────────────────────────────────────────────────────

  Future<void> loadInvoices(String orgId, {int page = 1, String? status}) async {
    _setLoading(true);
    try {
      _invoices = await repository.getInvoices(orgId, page: page, status: status);
      _error = null;
    } catch (e) {
      _error = e.toString();
      _invoices = [];
    } finally {
      _setLoading(false);
    }
  }

  // ── Payment gateway checkout ──────────────────────────────────────────────

  /// Returns { checkout_url, reference, gateway } or null on error.
  Future<Map<String, dynamic>?> createCheckoutSession(
    String orgId, {
    required String planId,
    required String gateway,
  }) async {
    _error = null;
    try {
      return await repository.createCheckoutSession(orgId,
          planId: planId, gateway: gateway);
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  Future<bool> verifyPayment({
    required String reference,
    required String gateway,
    String? transactionId,
    String? sessionId,
  }) async {
    _error = null;
    _setLoading(true);
    try {
      _subscription = await repository.verifyPayment(
        reference:     reference,
        gateway:       gateway,
        transactionId: transactionId,
        sessionId:     sessionId,
      );
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
