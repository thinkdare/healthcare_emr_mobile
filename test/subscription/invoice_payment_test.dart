import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthcare_emr_mobile/core/api/api_client.dart';
import 'package:healthcare_emr_mobile/data/models/subscription_models.dart';
import 'package:healthcare_emr_mobile/data/repositories/subscription_repository.dart';

class _RecordingApiClient extends ApiClient {
  String? lastPath;
  dynamic lastData;
  Map<String, dynamic> response;

  _RecordingApiClient(this.response) : super();

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    lastPath = path;
    lastData = data;
    return response;
  }
}

void main() {
  group('PaymentModel.fromJson', () {
    test('parses the BillingController::formatPayment shape', () {
      final payment = PaymentModel.fromJson({
        'id': 'pay-1',
        'invoice_id': 'inv-1',
        'amount': 50000,
        'currency': 'NGN',
        'payment_method': 'bank_transfer',
        'payment_provider': null,
        'status': 'succeeded',
        'receipt_number': 'RCT-001',
        'payment_date': '2026-06-20',
        'processed_at': '2026-06-20T10:00:00Z',
      });

      expect(payment.id, 'pay-1');
      expect(payment.invoiceId, 'inv-1');
      expect(payment.amount, 50000);
      expect(payment.paymentMethod, 'bank_transfer');
      expect(payment.receiptNumber, 'RCT-001');
    });
  });

  group('SubscriptionRepository.recordPayment', () {
    test('POSTs to the invoice payments endpoint with amount/method/reference', () async {
      final fake = _RecordingApiClient({
        'success': true,
        'data': {
          'id': 'pay-1',
          'invoice_id': 'inv-1',
          'amount': 50000,
          'currency': 'NGN',
          'payment_method': 'bank_transfer',
          'status': 'succeeded',
        },
      });
      final repo = SubscriptionRepository(apiClient: fake);

      final result = await repo.recordPayment(
        'org-1',
        'inv-1',
        amount: 50000,
        method: 'bank_transfer',
        reference: 'TX-123',
      );

      expect(fake.lastPath, '/billing/organizations/org-1/invoices/inv-1/payments');
      expect(fake.lastData, {
        'amount': 50000,
        'method': 'bank_transfer',
        'reference': 'TX-123',
      });
      expect(result.id, 'pay-1');
    });

    test('throws when the invoice is already paid', () async {
      final fake = _RecordingApiClient({'success': false, 'message': 'Invoice is already fully paid.'});
      final repo = SubscriptionRepository(apiClient: fake);

      expect(
        () => repo.recordPayment('org-1', 'inv-1', amount: 1000, method: 'card'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
