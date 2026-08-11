import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/core/api/api_client.dart';
import 'package:healthcare_emr_mobile/data/repositories/subscription_repository.dart';

class _FakeApiClient extends ApiClient {
  final Map<String, dynamic> Function(String path)? getHandler;
  final Map<String, dynamic> Function(String path, dynamic data)? postHandler;

  _FakeApiClient({this.getHandler, this.postHandler}) : super();

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async =>
      getHandler!(path);

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async =>
      postHandler!(path, data);
}

void main() {
  group('SubscriptionRepository.getPlans', () {
    test('returns plans on success', () async {
      final fake = _FakeApiClient(getHandler: (_) => {
            'success': true,
            'data': [
              {'id': 'plan-1', 'name': 'Starter', 'slug': 'starter'},
              {'id': 'plan-2', 'name': 'Professional', 'slug': 'pro'},
            ],
          });
      final repo = SubscriptionRepository(apiClient: fake);
      final plans = await repo.getPlans();
      expect(plans, hasLength(2));
      expect(plans.first.name, 'Starter');
    });

    test('throws on API failure', () async {
      final fake = _FakeApiClient(
        getHandler: (_) => {'success': false, 'message': 'Server error'},
      );
      final repo = SubscriptionRepository(apiClient: fake);
      expect(() => repo.getPlans(), throwsException);
    });
  });

  group('SubscriptionRepository.getSubscription', () {
    test('returns SubscriptionModel on success', () async {
      final fake = _FakeApiClient(getHandler: (_) => {
            'success': true,
            'data': {
              'id': 'sub-1',
              'organization_id': 'org-1',
              'plan_id': 'plan-1',
              'status': 'trial',
            },
          });
      final repo = SubscriptionRepository(apiClient: fake);
      final sub = await repo.getSubscription('org-1');
      expect(sub, isNotNull);
      expect(sub!.status, 'trial');
    });

    // Edge case: staff (non-org-admin) get a 403 on this endpoint per the
    // class doc — getSubscription() swallows that as "no subscription to
    // show" (null) rather than surfacing an error, since dashboard widgets
    // call this unconditionally regardless of the caller's role.
    test('returns null (not an exception) when forbidden', () async {
      final fake = _FakeApiClient(getHandler: (_) => {
            'success': false,
            'message': 'Forbidden',
            'error': {'code': 'FORBIDDEN'},
          });
      final repo = SubscriptionRepository(apiClient: fake);
      final sub = await repo.getSubscription('org-1');
      expect(sub, isNull);
    });

    test('returns null when the API client throws', () async {
      final fake = _FakeApiClient(
        getHandler: (_) => throw Exception('Network error'),
      );
      final repo = SubscriptionRepository(apiClient: fake);
      final sub = await repo.getSubscription('org-1');
      expect(sub, isNull);
    });
  });

  group('SubscriptionRepository.startTrial', () {
    test('sends plan_id and trial_days and returns the new subscription',
        () async {
      Map<String, dynamic>? sentData;
      final fake = _FakeApiClient(postHandler: (path, data) {
        sentData = Map<String, dynamic>.from(data as Map);
        return {
          'success': true,
          'data': {
            'id': 'sub-2',
            'organization_id': 'org-1',
            'plan_id': 'plan-1',
            'status': 'trial',
          },
        };
      });
      final repo = SubscriptionRepository(apiClient: fake);
      final sub =
          await repo.startTrial('org-1', planId: 'plan-1', trialDays: 14);
      expect(sub.id, 'sub-2');
      expect(sentData, {'plan_id': 'plan-1', 'trial_days': 14});
    });
  });
}
