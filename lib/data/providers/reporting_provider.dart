import 'package:flutter/material.dart';
import '../repositories/reporting_repository.dart';

class ReportingProvider extends ChangeNotifier {
  final ReportingRepository repository;

  ReportingProvider({required this.repository});

  // ── Org dashboard ─────────────────────────────────────────────────────────

  Map<String, dynamic>? _orgStats;
  Map<String, dynamic>? get orgStats => _orgStats;

  bool _loadingOrg = false;
  bool get loadingOrg => _loadingOrg;

  // ── Tenant dashboard ──────────────────────────────────────────────────────

  Map<String, dynamic>? _tenantStats;
  Map<String, dynamic>? get tenantStats => _tenantStats;

  bool _loadingTenant = false;
  bool get loadingTenant => _loadingTenant;

  // ── Audit log ─────────────────────────────────────────────────────────────

  List<AuditLogEntry> _auditLogs = [];
  List<AuditLogEntry> get auditLogs => _auditLogs;

  bool _loadingAudit = false;
  bool get loadingAudit => _loadingAudit;

  bool _auditHasMore = false;
  bool get auditHasMore => _auditHasMore;

  int _auditTotal = 0;
  int get auditTotal => _auditTotal;

  int _auditPage = 1;

  // Active filters
  String? auditActionFilter;
  String? auditAuthorityFilter;
  bool? auditEmergencyFilter;

  // ── Error ─────────────────────────────────────────────────────────────────

  String? _error;
  String? get error => _error;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── Loaders ───────────────────────────────────────────────────────────────

  Future<void> loadOrgDashboard(String orgId) async {
    _loadingOrg = true;
    _error = null;
    notifyListeners();

    try {
      _orgStats = await repository.orgDashboard(orgId);
    } on Exception catch (e) {
      _error = _msg(e);
    } finally {
      _loadingOrg = false;
      notifyListeners();
    }
  }

  Future<void> loadTenantDashboard(String tenantId) async {
    _loadingTenant = true;
    _error = null;
    notifyListeners();

    try {
      _tenantStats = await repository.tenantDashboard(tenantId);
    } on Exception catch (e) {
      _error = _msg(e);
    } finally {
      _loadingTenant = false;
      notifyListeners();
    }
  }

  Future<void> loadAuditLog(
    String tenantId, {
    bool refresh = false,
  }) async {
    if (_loadingAudit) return;

    if (refresh) {
      _auditPage = 1;
      _auditLogs = [];
      _auditHasMore = false;
    }

    _loadingAudit = true;
    _error = null;
    notifyListeners();

    try {
      final result = await repository.auditLog(
        tenantId,
        page: _auditPage,
        action: auditActionFilter,
        accessAuthority: auditAuthorityFilter,
        wasEmergency: auditEmergencyFilter,
      );
      _auditLogs = refresh
          ? result.items
          : [..._auditLogs, ...result.items];
      _auditHasMore = result.hasMore;
      _auditTotal = result.total;
      if (result.hasMore) _auditPage++;
    } on Exception catch (e) {
      _error = _msg(e);
    } finally {
      _loadingAudit = false;
      notifyListeners();
    }
  }

  Future<void> loadMore(String tenantId) async {
    if (!_auditHasMore || _loadingAudit) return;
    await loadAuditLog(tenantId);
  }

  void applyFilters(
    String tenantId, {
    String? action,
    String? authority,
    bool? emergency,
  }) {
    auditActionFilter = action;
    auditAuthorityFilter = authority;
    auditEmergencyFilter = emergency;
    loadAuditLog(tenantId, refresh: true);
  }

  String _msg(Exception e) {
    final s = e.toString();
    if (s.contains('403')) return 'Access denied. Admins only.';
    if (s.contains('404')) return 'Resource not found.';
    if (s.contains('SocketException') || s.contains('Connection')) {
      return 'Cannot reach server. Check your connection.';
    }
    return 'Something went wrong. Please try again.';
  }
}
