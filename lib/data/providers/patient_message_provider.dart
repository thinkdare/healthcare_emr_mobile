// lib/data/providers/patient_message_provider.dart

import 'package:flutter/foundation.dart';
import '../models/patient_message_models.dart';
import '../repositories/patient_message_repository.dart';

class PatientMessageProvider extends ChangeNotifier {
  final PatientMessageRepository repository;

  PatientMessageProvider({required this.repository});

  List<PatientMessageModel> _messages = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _error;

  List<PatientMessageModel> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get error => _error;

  Future<void> loadInbox(String patientId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _messages = await repository.getInbox(patientId);
    } catch (e) {
      _error = _friendly(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> reply(String patientId, String messageId, String body) async {
    _isSubmitting = true;
    _error = null;
    notifyListeners();
    try {
      final created = await repository.reply(patientId, messageId, body);
      _messages = [created, ..._messages];
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
    final match = RegExp(r'ApiException\(\d+\): (.+)').firstMatch(msg);
    if (match != null) return match.group(1)!;
    return msg.contains('Exception:') ? msg.split('Exception:').last.trim() : msg;
  }
}
