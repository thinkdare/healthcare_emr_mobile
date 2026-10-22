import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/core/api/api_client.dart';
import 'package:healthcare_emr_mobile/data/providers/emergency_access_provider.dart';
import 'package:healthcare_emr_mobile/data/repositories/emergency_access_repository.dart';

class _FakeApiClient extends ApiClient {
  final calls = <String>[];
  Map<String, dynamic>? lastData;
  final Object? authorizeError;

  _FakeApiClient({this.authorizeError}) : super();

  Map<String, dynamic> getResponse = const {'success': true, 'data': []};

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    calls.add('GET $path');
    return getResponse;
  }

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    calls.add('POST $path');
    lastData = data as Map<String, dynamic>?;
    if (path == '/emergency-access/authorize') {
      if (authorizeError != null) throw authorizeError!;
      return {
        'success': true,
        'data': {'method': 'email', 'expires_in_minutes': 10},
      };
    }
    return {
      'success': true,
      'data': {
        'id': 'log-1',
        'master_patient_id': 'p-1',
        'emergency_type': 'life_threatening',
        'emergency_details': 'x' * 20,
        'accessed_at': '2026-10-22T12:00:00Z',
      },
    };
  }
}

void main() {
  group('EmergencyAuthorization.fromJson', () {
    test('parses an emailed-code challenge', () {
      final a = EmergencyAuthorization.fromJson(
          {'method': 'email', 'expires_in_minutes': 10});
      expect(a.isTotp, isFalse);
      expect(a.expiresInMinutes, 10);
    });

    test('parses a TOTP challenge with no expiry', () {
      final a = EmergencyAuthorization.fromJson(
          {'method': 'totp', 'expires_in_minutes': null});
      expect(a.isTotp, isTrue);
      expect(a.expiresInMinutes, isNull);
    });
  });

  group('EmergencyAccessRepository.getLogs', () {
    test('parses the paginated envelope (data is a list, paging is in meta)', () async {
      final client = _FakeApiClient()
        ..getResponse = {
          'success': true,
          'data': [
            {
              'id': 'log-1',
              'master_patient_id': 'p-1',
              'emergency_type': 'life_threatening',
              'reviewed_by_primary': false,
              'accessed_at': '2026-10-22T12:00:00+00:00',
            },
          ],
          'meta': {
            'pagination': {
              'current_page': 1,
              'per_page': 20,
              'total': 25,
              'last_page': 2,
              'has_more': true,
            },
          },
        };

      final result =
          await EmergencyAccessRepository(apiClient: client).getLogs();

      expect(result.items.single.id, 'log-1');
      expect(result.hasMore, isTrue);
      expect(result.currentPage, 1);
    });

    test('an empty page has no more results', () async {
      final result = await EmergencyAccessRepository(apiClient: _FakeApiClient())
          .getLogs();
      expect(result.items, isEmpty);
      expect(result.hasMore, isFalse);
    });
  });

  group('EmergencyAccessRepository', () {
    test('requestAuthorization calls POST /emergency-access/authorize', () async {
      final client = _FakeApiClient();
      final repo = EmergencyAccessRepository(apiClient: client);

      final a = await repo.requestAuthorization();

      expect(client.calls, ['POST /emergency-access/authorize']);
      expect(a.method, 'email');
    });

    test('trigger sends the authorization code through unchanged', () async {
      final client = _FakeApiClient();
      final repo = EmergencyAccessRepository(apiClient: client);

      await repo.trigger({
        'master_patient_id': 'p-1',
        'emergency_type': 'life_threatening',
        'emergency_details': 'x' * 20,
        'authorization_code': '123456',
      });

      expect(client.calls, ['POST /emergency-access']);
      expect(client.lastData!['authorization_code'], '123456');
    });
  });

  group('EmergencyAccessProvider.requestAuthorization', () {
    test('returns the challenge on success', () async {
      final provider = EmergencyAccessProvider(
          repository: EmergencyAccessRepository(apiClient: _FakeApiClient()));

      final a = await provider.requestAuthorization();

      expect(a, isNotNull);
      expect(provider.error, isNull);
    });

    test('shows the server message when the code email could not be sent', () async {
      const message =
          'We could not email your authorization code. Try again in a moment, or contact your administrator.';
      final provider = EmergencyAccessProvider(
        repository: EmergencyAccessRepository(
          apiClient: _FakeApiClient(authorizeError: Exception('ApiException(503): $message')),
        ),
      );

      expect(await provider.requestAuthorization(), isNull);
      expect(provider.error, message);
    });

    test('maps a rate limit to a friendly message and returns null', () async {
      final provider = EmergencyAccessProvider(
        repository: EmergencyAccessRepository(
          apiClient: _FakeApiClient(
              authorizeError: Exception('ApiException(429): Too many requests')),
        ),
      );

      expect(await provider.requestAuthorization(), isNull);
      expect(provider.error, contains('Too many emergency access attempts'));
    });
  });
}
