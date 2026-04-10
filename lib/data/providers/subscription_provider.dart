import 'package:flutter/material.dart';
import '../models/subscription_models.dart';
import '../repositories/subscription_repository.dart';

class SubscriptionProvider extends ChangeNotifier {
  final SubscriptionRepository repository;

  SubscriptionProvider({required this.repository});

  List<SubscriptionPlanModel> _plans = [];
  SubscriptionModel? _subscription;
  List<InvoiceModel> _invoices = [];

  bool _isLoading = false;
  String? _error;

  List<SubscriptionPlanModel> get plans => _plans;
  SubscriptionModel? get subscription => _subscription;
  List<InvoiceModel> get invoices => _invoices;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool get isOnTrial => _subscription?.isTrial ?? false;
  bool get isActive => _subscription?.isActive ?? false;
  int get trialDaysRemaining => _subscription?.trialDaysRemaining ?? 0;

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
    _setLoading(true);
    try {
      _subscription = await repository.getSubscription(orgId);
      _error = null;
    } catch (e) {
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
