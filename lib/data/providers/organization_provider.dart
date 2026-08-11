import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../models/auth_models.dart';
import '../repositories/organization_repository.dart';

class OrganizationProvider extends ChangeNotifier {
  final OrganizationRepository repository;

  OrganizationProvider({required this.repository});

  CheckEmailResponse? _checkEmailResult;
  bool _isLoading = false;
  String? _error;
  bool _isConnectionError = false;

  CheckEmailResponse? get checkEmailResult => _checkEmailResult;
  List<AuthFacilityModel> get facilities => _checkEmailResult?.facilities ?? [];
  bool get exists => _checkEmailResult?.exists ?? false;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// True when [checkEmail] failed because the server couldn't be reached
  /// (no response at all), as opposed to the server responding that the
  /// account doesn't exist. Callers use this to avoid showing a misleading
  /// "no account found" message for what is actually an outage.
  bool get isConnectionError => _isConnectionError;

  Future<CheckEmailResponse?> checkEmail(String email) async {
    _isLoading = true;
    _error = null;
    _isConnectionError = false;
    notifyListeners();

    try {
      final result = await repository.checkEmail(email);
      _checkEmailResult = result;
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _error = e is ApiException ? e.message : e.toString();
      // No status code means Dio never got a response (timeout, DNS
      // failure, connection refused) rather than the server rejecting
      // the request.
      _isConnectionError = e is ApiException ? e.statusCode == null : true;
      _isLoading = false;
      _checkEmailResult = null;
      notifyListeners();
      return null;
    }
  }

  void clear() {
    _checkEmailResult = null;
    _error = null;
    _isConnectionError = false;
    notifyListeners();
  }
}
