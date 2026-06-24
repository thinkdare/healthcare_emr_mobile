// lib/data/providers/patient_consent_provider.dart

import 'package:flutter/foundation.dart';
import '../models/patient_consent_models.dart';
import '../repositories/patient_consent_repository.dart';

class PatientConsentProvider extends ChangeNotifier {
  final PatientConsentRepository repository;

  PatientConsentProvider({required this.repository});

  List<PatientConsentModel> _consents = [];
  List<PatientConsentEventModel> _history = [];
  NotificationPreferencesModel _preferences = const NotificationPreferencesModel();

  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _error;

  List<PatientConsentModel> get consents => _consents;
  List<PatientConsentEventModel> get history => _history;
  NotificationPreferencesModel get preferences => _preferences;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get error => _error;

  Future<void> load(String patientId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        repository.list(patientId),
        repository.history(patientId),
      ]);
      _consents = results[0] as List<PatientConsentModel>;
      _history = results[1] as List<PatientConsentEventModel>;
    } catch (e) {
      _error = _friendly(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> recordConsent(
    String patientId, {
    required String consentType,
    required String legalBasis,
    required bool given,
    required String documentVersion,
    String? notes,
  }) =>
      _run(() async {
        final updated = await repository.record(
          patientId,
          consentType: consentType,
          legalBasis: legalBasis,
          given: given,
          documentVersion: documentVersion,
          notes: notes,
        );
        _consents = [
          ..._consents.where((c) => c.consentType != consentType),
          updated,
        ];
        _history = await repository.history(patientId);
      });

  Future<bool> revokeConsent(
    String patientId,
    String consentType, {
    required String documentVersion,
    String? notes,
  }) =>
      _run(() async {
        await repository.revoke(patientId, consentType,
            documentVersion: documentVersion, notes: notes);
        _consents = await repository.list(patientId);
        _history = await repository.history(patientId);
      });

  Future<bool> updatePreferences(String patientId, NotificationPreferencesModel prefs) =>
      _run(() async {
        _preferences = await repository.updatePreferences(patientId, prefs);
      });

  Future<bool> _run(Future<void> Function() call) async {
    _isSubmitting = true;
    _error = null;
    notifyListeners();
    try {
      await call();
      _isSubmitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendly(e);
      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _friendly(Object e) {
    final msg = e.toString();
    if (msg.contains('SocketException') || msg.contains('Connection')) {
      return 'No internet connection.';
    }
    if (msg.contains('401')) return 'Session expired. Please log in again.';
    if (msg.contains('403')) {
      return 'You do not have permission to perform this action.';
    }
    if (msg.contains('ALREADY_REVOKED')) {
      return 'This consent is already revoked.';
    }
    final match = RegExp(r'ApiException\(\d+\): (.+)').firstMatch(msg);
    if (match != null) return match.group(1)!;
    return msg.contains('Exception:') ? msg.split('Exception:').last.trim() : msg;
  }
}
