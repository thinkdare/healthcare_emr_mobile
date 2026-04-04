import 'package:flutter/material.dart';
import '../models/models.dart';
import '../repositories/auth_repository.dart';

class AuthError {
  final String message;
  final String userMessage;

  AuthError({required this.message, required this.userMessage});
}

class AuthProvider extends ChangeNotifier {
  final AuthRepository repository;

  bool isAuthenticated = false;
  bool isLoading = true;
  UserModel? _currentUser;
  ProviderModel? _currentProvider;
  AuthError? _error;

  UserModel? get currentUser => _currentUser;
  ProviderModel? get currentProvider => _currentProvider;
  AuthError? get error => _error;

  AuthProvider({required this.repository});

  void initialize() async {
    isLoading = false;
    notifyListeners();
  }

  Future<bool> login({
    required String email,
    required String password,
    required String organizationId,
  }) async {
    try {
      _error = null;
      final loginResponse = await repository.login(
        email: email,
        password: password,
        organizationId: organizationId,
      );

      _currentUser = loginResponse.user;
      _currentProvider = loginResponse.provider;
      isAuthenticated = true;
      notifyListeners();
      return true;
    } catch (e) {
      _error = AuthError(
        message: e.toString(),
        userMessage: 'Invalid email or password',
      );
      isAuthenticated = false;
      _currentUser = null;
      _currentProvider = null;
      notifyListeners();
      return false;
    }
  }

  Future<void> refreshCurrentUser() async {
    try {
      // This would typically call an API to refresh user data
      // For now, we'll just trigger a notifyListeners
      notifyListeners();
    } catch (e) {
      _error = AuthError(
        message: e.toString(),
        userMessage: 'Failed to refresh user data',
      );
      notifyListeners();
    }
  }

  Future<void> logout() async {
    isAuthenticated = false;
    _currentUser = null;
    _currentProvider = null;
    _error = null;
    notifyListeners();
  }
}