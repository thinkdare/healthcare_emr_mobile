import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/core/api/api_client.dart';
import 'package:healthcare_emr_mobile/core/database/local_database.dart';
import 'package:healthcare_emr_mobile/data/repositories/sync_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakeApiClient extends ApiClient {
  Map<String, dynamic> response;
  _FakeApiClient(this.response) : super();

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async =>
      response;

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async =>
      response;
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalDatabase.teardownForTesting();
    final rawDb = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await LocalDatabase.forTesting(rawDb);
  });

  tearDown(() async {
    await LocalDatabase.teardownForTesting();
  });

  group('SyncRepository.push', () {
    test('removes only resolved items from the local queue, keeps forbidden/rejected',
        () async {
      await LocalDatabase.instance.queuePendingSync(
        id: 'sync-applied',
        resourceType: 'patients',
        resourceId: 'pat-1',
        operation: 'update',
        payload: {'medical_history': 'Applied edit'},
      );
      await LocalDatabase.instance.queuePendingSync(
        id: 'sync-forbidden',
        resourceType: 'patients',
        resourceId: 'pat-2',
        operation: 'update',
        payload: {'medical_history': 'Forbidden edit'},
      );
      await LocalDatabase.instance.queuePendingSync(
        id: 'sync-conflict',
        resourceType: 'patients',
        resourceId: 'pat-3',
        operation: 'update',
        payload: {'medical_history': 'Conflicted edit'},
      );

      final fake = _FakeApiClient({
        'success': true,
        'data': {
          'queued': 3,
          'conflicts': 1,
          'applied': 1,
          'items': [
            {'id': 'sync-applied', 'outcome': 'completed'},
            {'id': 'sync-forbidden', 'outcome': 'forbidden'},
            {'id': 'sync-conflict', 'outcome': 'conflict'},
          ],
        },
      });

      final repo = SyncRepository(apiClient: fake, localDatabase: LocalDatabase.instance);
      await repo.push();

      final remaining = await LocalDatabase.instance.getPendingSyncItems();
      final remainingIds = remaining.map((r) => r['id']).toSet();

      expect(remainingIds, {'sync-forbidden'});
    });
  });
}
