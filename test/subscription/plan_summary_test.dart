import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/config/app_config.dart';
import 'package:healthcare_emr_mobile/core/api/api_client.dart';
import 'package:healthcare_emr_mobile/data/models/subscription_models.dart';
import 'package:healthcare_emr_mobile/data/providers/subscription_provider.dart';
import 'package:healthcare_emr_mobile/data/repositories/subscription_repository.dart';

class _FakeApiClient extends ApiClient {
  final calls = <String>[];
  final Map<String, Map<String, dynamic>> responses;
  final Set<String> forbidden;

  _FakeApiClient({this.responses = const {}, this.forbidden = const {}}) : super();

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    calls.add(path);
    if (forbidden.contains(path)) throw Exception('ApiException(403): forbidden');
    return responses[path] ?? {'success': false};
  }
}

Map<String, dynamic> _summary({String slug = 'professional', bool trial = false}) => {
      'success': true,
      'data': {
        'organization_id': 'org-1',
        'plan_slug': slug,
        'plan_name': slug,
        'status': trial ? 'trialing' : 'active',
        'is_trial': trial,
      },
    };

SubscriptionProvider _provider(_FakeApiClient client) =>
    SubscriptionProvider(repository: SubscriptionRepository(apiClient: client));

void main() {
  const planPath = '/billing/organizations/org-1/plan';
  const subPath = '/billing/organizations/org-1/subscription';

  test('PlanSummaryModel.fromJson parses the BillingController::planSummary shape', () {
    final m = PlanSummaryModel.fromJson(_summary(slug: 'starter')['data'] as Map<String, dynamic>);
    expect(m.planSlug, 'starter');
    expect(m.isTrial, isFalse);
    expect(m.organizationId, 'org-1');
  });

  test('staff load the plan summary and never call the admin-only subscription endpoint', () async {
    final client = _FakeApiClient(
      responses: {planPath: _summary()},
      forbidden: {subPath},
    );
    final provider = _provider(client);

    await provider.loadForRole('org-1', isOrgAdmin: false);

    expect(client.calls, [planPath]);
    expect(provider.isProfessionalOrHigher, isTrue);
  });

  test('a starter plan is not professional-or-higher', () async {
    final provider = _provider(_FakeApiClient(responses: {planPath: _summary(slug: 'starter')}));
    await provider.loadForRole('org-1', isOrgAdmin: false);
    expect(provider.isProfessionalOrHigher, isFalse);
  });

  test('a trial unlocks professional features whatever the plan', () async {
    final provider = _provider(
        _FakeApiClient(responses: {planPath: _summary(slug: 'starter', trial: true)}));
    await provider.loadForRole('org-1', isOrgAdmin: false);
    expect(provider.isProfessionalOrHigher, isTrue);
  });

  test('a failed summary fails closed (null, not true)', () async {
    final provider = _provider(_FakeApiClient(forbidden: {planPath}));
    await provider.loadForRole('org-1', isOrgAdmin: false);
    expect(provider.subLoadState, SubscriptionLoadState.error);
    expect(provider.isProfessionalOrHigher, isNull);
  });

  test('org admins still load the full subscription', () async {
    final client = _FakeApiClient(responses: {subPath: {'success': false}});
    await _provider(client).loadForRole('org-1', isOrgAdmin: true);
    expect(client.calls, [subPath]);
  });

  test('the debug fallback URL targets the backend dev port, not 8000', () {
    expect(AppConfig.baseUrl, contains(':8180/api/v1'));
    expect(AppConfig.authBaseUrl, contains(':8180'));
  });
}
