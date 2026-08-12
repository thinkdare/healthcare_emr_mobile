import 'package:flutter/foundation.dart';
import '../models/intra_transfer_model.dart';
import '../repositories/intra_transfer_repository.dart';

class IntraTransferProvider extends ChangeNotifier {
  final IntraTransferRepository repository;

  IntraTransferProvider({required this.repository});

  bool _isSending = false;
  String? _error;

  bool get isSending => _isSending;
  String? get error => _error;

  Future<IntraTransferModel?> create(
    String patientId,
    Map<String, dynamic> data,
  ) async {
    _isSending = true;
    _error = null;
    notifyListeners();
    try {
      final transfer = await repository.create(patientId, data);
      return transfer;
    } catch (e) {
      _error = _friendlyError(e);
      return null;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('SocketException') || msg.contains('Connection')) {
      return 'No internet connection.';
    }
    return msg.replaceFirst('Exception: ', '');
  }
}
