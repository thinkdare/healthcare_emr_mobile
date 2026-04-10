import 'package:flutter/material.dart';
import '../models/auth_models.dart';
import '../repositories/organization_repository.dart';

class OrganizationProvider extends ChangeNotifier {
  final OrganizationRepository repository;

  OrganizationProvider({required this.repository});

  CheckEmailResponse? _checkEmailResult;
  bool _isLoading = false;
  String? _error;

  CheckEmailResponse? get checkEmailResult => _checkEmailResult;
  List<AuthFacilityModel> get facilities => _checkEmailResult?.facilities ?? [];
  bool get exists => _checkEmailResult?.exists ?? false;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<CheckEmailResponse?> checkEmail(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await repository.checkEmail(email);
      _checkEmailResult = result;
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      _checkEmailResult = null;
      notifyListeners();
      return null;
    }
  }

  void clear() {
    _checkEmailResult = null;
    _error = null;
    notifyListeners();
  }
}
