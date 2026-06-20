import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/core/api/api_client.dart';
import 'package:healthcare_emr_mobile/core/database/local_database.dart';
import 'package:healthcare_emr_mobile/data/repositories/patient_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _NetworkErrorApiClient extends ApiClient {
  _NetworkErrorApiClient() : super();

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    throw Exception('SocketException: OS Error: Connection refused, errno = 111');
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    await LocalDatabase.teardownForTesting();
    final rawDb = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await LocalDatabase.forTesting(rawDb);
  });

  tearDown(() async {
    await LocalDatabase.teardownForTesting();
  });

  group('PatientRepository.createPatient offline', () {
    test('caches a local placeholder and queues the write with a client-generated resource id',
        () async {
      final repo = PatientRepository(
        apiClient: _NetworkErrorApiClient(),
        localDatabase: LocalDatabase.instance,
      );

      await expectLater(
        repo.createPatient({
          'first_name': 'Offline',
          'last_name': 'Patient',
          'date_of_birth': '1990-01-01',
          'gender': 'male',
          'emergency_contact_name': 'Contact',
          'emergency_contact_phone': '000',
          'allergies': [
            {'name': 'Penicillin', 'severity': 'severe'},
          ],
        }, providerId: 'prov-1'),
        throwsA(isA<Exception>()),
      );

      // Visible locally immediately, including allergies — not silently
      // dropped, and not invisible until the next sync.
      final cached = await LocalDatabase.instance.getPatients(providerId: 'prov-1');
      expect(cached, hasLength(1));
      expect(cached.first.firstName, 'Offline');
      expect(cached.first.allergies, hasLength(1));
      expect(cached.first.allergies.first.name, 'Penicillin');

      // Queued with the SAME id as the local placeholder — the server will
      // create the record with this exact id (see
      // SyncController::createOfflinePatient()), so no reconciliation step
      // is needed once it syncs.
      final pending = await LocalDatabase.instance.getPendingSyncItems();
      expect(pending, hasLength(1));
      expect(pending.first['resource_id'], cached.first.id);
      expect(pending.first['operation'], 'create');
    });
  });
}
