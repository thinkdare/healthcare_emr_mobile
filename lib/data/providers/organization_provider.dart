import 'package:flutter/material.dart';
import '../models/models.dart';
import '../repositories/organization_repository.dart';

class OrganizationProvider extends ChangeNotifier {
  final OrganizationRepository repository;

  OrganizationProvider({required this.repository});

  List<OrganizationLiteModel> _organizations = [];
  bool _isLoading = false;
  String? _error;

  List<OrganizationLiteModel> get organizations => _organizations;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<List<OrganizationLiteModel>?> checkEmail(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await repository.checkEmail(email);
      _organizations = result;
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      _organizations = [];
      notifyListeners();
      return null;
    }
  }

  void clearOrganizations() {
    _organizations = [];
    _error = null;
    notifyListeners();
  }
}