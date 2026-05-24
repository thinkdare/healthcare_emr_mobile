import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/core/api/api_client.dart';
import 'package:healthcare_emr_mobile/data/repositories/organization_repository.dart';
import 'package:healthcare_emr_mobile/data/models/organization_models_enhanced.dart';

class _FakeApiClient extends ApiClient {
  final Map<String, dynamic> Function(String path)? getHandler;
  final Map<String, dynamic> Function(String path, dynamic data)? putHandler;

  _FakeApiClient({this.getHandler, this.putHandler}) : super();

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async =>
      getHandler!(path);

  @override
  Future<Map<String, dynamic>> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async =>
      putHandler!(path, data);
}

void main() {
  group('OrganizationRepository.getOrgStats', () {
    test('returns OrgStatsModel on success', () async {
      final fake = _FakeApiClient(
        getHandler: (_) => {
          'success': true,
          'data': {
            'total_facilities': 3,
            'total_staff': 12,
            'total_patients': 500,
            'active_subscriptions': 1,
          },
        },
      );
      final repo = OrganizationRepository(apiClient: fake);
      final stats = await repo.getOrgStats('org-1');
      expect(stats.totalFacilities, 3);
      expect(stats.totalPatients, 500);
    });

    test('throws on API failure', () async {
      final fake = _FakeApiClient(
        getHandler: (_) => {'success': false, 'message': 'Not found'},
      );
      final repo = OrganizationRepository(apiClient: fake);
      expect(() => repo.getOrgStats('org-1'), throwsException);
    });
  });

  group('OrganizationRepository.updateOrganization', () {
    test('sends request and returns updated model', () async {
      final fake = _FakeApiClient(
        getHandler: (_) => {'success': true, 'data': {}},
        putHandler: (_, __) => {
          'success': true,
          'data': {
            'id': 'org-1',
            'name': 'Updated',
            'type': 'hospital',
            'address': 'X',
            'subscription_status': 'active',
            'max_facilities': 5,
            'max_providers': 50,
          },
        },
      );
      final repo = OrganizationRepository(apiClient: fake);
      final req = UpdateOrganizationRequest(name: 'Updated', type: 'hospital');
      final result = await repo.updateOrganization('org-1', req);
      expect(result.name, 'Updated');
    });
  });
}
