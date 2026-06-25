// lib/data/repositories/intra_grant_repository.dart

import 'package:uuid/uuid.dart';

import '../models/intra_grant_models.dart';
import '../../core/api/api_client.dart';
import '../../core/database/local_database.dart';

class IntraGrantRepository {
  final ApiClient apiClient;
  final LocalDatabase _db;

  IntraGrantRepository({required this.apiClient, LocalDatabase? localDatabase})
      : _db = localDatabase ?? LocalDatabase.instance;

  bool _isNetworkError(Object e) {
    final msg = e.toString();
    return msg.contains('SocketException') ||
        msg.contains('Connection refused') ||
        msg.contains('Connection reset') ||
        msg.contains('Network is unreachable') ||
        msg.contains('HandshakeException');
  }

  Future<({List<IntraAccessGrantModel> incoming, List<IntraAccessGrantModel> outgoing})>
      getGrants() async {
    final response = await apiClient.get('/intra-grants');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load consultation requests');
    }
    final data = response['data'] as Map<String, dynamic>;

    List<IntraAccessGrantModel> parse(dynamic raw) =>
        (raw as List? ?? [])
            .map((e) => IntraAccessGrantModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();

    return (
      incoming: parse(data['incoming']),
      outgoing: parse(data['outgoing']),
    );
  }

  Future<IntraAccessGrantModel> create(Map<String, dynamic> data) async {
    final response = await apiClient.post('/intra-grants', data: data);
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to create consultation request');
    }
    return IntraAccessGrantModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  Future<IntraAccessGrantModel> accept(String id) async {
    final response = await apiClient.post('/intra-grants/$id/accept', data: {});
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to accept request');
    }
    return IntraAccessGrantModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  Future<IntraAccessGrantModel> decline(String id, String responseNote) async {
    final response = await apiClient.post(
      '/intra-grants/$id/decline',
      data: {'response': responseNote},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to decline request');
    }
    return IntraAccessGrantModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  Future<IntraAccessGrantModel> complete(String id, String responseNote) async {
    final response = await apiClient.post(
      '/intra-grants/$id/complete',
      data: {'response': responseNote},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to complete consultation');
    }
    return IntraAccessGrantModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  Future<void> cancel(String id) async {
    final response = await apiClient.post('/intra-grants/$id/cancel', data: {});
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to cancel request');
    }
  }

  Future<List<ConsultationMessageModel>> getMessages(String grantId) async {
    final response = await apiClient.get('/intra-grants/$grantId/messages');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to load messages');
    }
    final data = response['data'] as Map<String, dynamic>;
    final items = data['messages'] as List? ?? [];
    return items
        .map((e) => ConsultationMessageModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<ConsultationMessageModel> sendMessage(String grantId, String body) async {
    final response = await apiClient.post(
      '/intra-grants/$grantId/messages',
      data: {'message': body},
    );
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to send message');
    }
    return ConsultationMessageModel.fromJson(
        Map<String, dynamic>.from(response['data'] as Map));
  }

  Future<List<ClinicalNoteModel>> getPatientNotes(String patientId,
      {int page = 1}) async {
    try {
      final response = await apiClient
          .get('/patients/$patientId/notes?page=$page&per_page=20');
      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Failed to load clinical notes');
      }
      final items = (response['data'] as List? ?? []);
      final notes = items
          .map((e) => ClinicalNoteModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      for (final n in notes) {
        await _db.upsertClinicalNote(n);
      }
      return notes;
    } catch (e) {
      if (!_isNetworkError(e)) rethrow;
      final cached = await _db.getClinicalNotesByPatient(patientId);
      if (cached.isEmpty) rethrow;
      return cached;
    }
  }

  Future<ClinicalNoteModel> createNote(String patientId, {
    required String body,
    required String authoredById,
    required String authoredByName,
    String? title,
  }) async {
    try {
      final response = await apiClient.post(
        '/patients/$patientId/notes',
        data: {
          'body': body,
          'title': ?title,
        },
      );
      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Failed to save note');
      }
      final note = ClinicalNoteModel.fromJson(
          Map<String, dynamic>.from(response['data'] as Map));
      await _db.upsertClinicalNote(note);
      return note;
    } catch (e) {
      if (!_isNetworkError(e)) rethrow;

      final newId = const Uuid().v4();
      final placeholder = ClinicalNoteModel(
        id: newId,
        patientId: patientId,
        noteType: 'general',
        title: title,
        body: body,
        authoredById: authoredById,
        authoredByName: authoredByName,
        authoredAt: DateTime.now(),
      );
      await _db.upsertClinicalNote(placeholder);

      await _db.queuePendingSync(
        id: const Uuid().v4(),
        resourceType: 'clinical_notes',
        resourceId: newId,
        operation: 'create',
        payload: {'patient_id': patientId, 'body': body, 'title': ?title},
      );
      throw Exception('Offline — note will be saved when you reconnect.');
    }
  }
}
