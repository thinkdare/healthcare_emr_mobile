// lib/presentation/subscription/widgets/gateway_picker_sheet.dart

import 'package:flutter/material.dart';
import '../../../config/theme.dart';

enum PaymentGateway { paystack, flutterwave, stripe }

extension PaymentGatewayExt on PaymentGateway {
  String get id => name; // 'paystack' | 'flutterwave' | 'stripe'

  String get label => switch (this) {
    PaymentGateway.paystack    => 'Paystack',
    PaymentGateway.flutterwave => 'Flutterwave',
    PaymentGateway.stripe      => 'Stripe',
  };

  String get subtitle => switch (this) {
    PaymentGateway.paystack    => 'Nigeria & West Africa · NGN',
    PaymentGateway.flutterwave => 'Ghana, Kenya, Rwanda + more · NGN',
    PaymentGateway.stripe      => 'International · USD',
  };

  String get regionNote => switch (this) {
    PaymentGateway.paystack    => 'Best for Nigerian organisations',
    PaymentGateway.flutterwave => 'Best for broader West Africa coverage',
    PaymentGateway.stripe      => 'Best for international organisations',
  };

  IconData get icon => switch (this) {
    PaymentGateway.paystack    => Icons.account_balance_wallet_outlined,
    PaymentGateway.flutterwave => Icons.flight_takeoff_outlined,
    PaymentGateway.stripe      => Icons.credit_card_outlined,
  };

  Color get color => switch (this) {
    PaymentGateway.paystack    => const Color(0xFF00C3F7),
    PaymentGateway.flutterwave => const Color(0xFFF5A623),
    PaymentGateway.stripe      => const Color(0xFF635BFF),
  };
}

/// Bottom sheet that lets the user pick a payment gateway before checkout.
///
/// Returns the chosen [PaymentGateway] or null if dismissed.
Future<PaymentGateway?> showGatewayPicker(BuildContext context) {
  return showModalBottomSheet<PaymentGateway>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _GatewayPickerSheet(),
  );
}

class _GatewayPickerSheet extends StatelessWidget {
  const _GatewayPickerSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Choose payment method',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Your payment is processed securely by the gateway.',
              style: TextStyle(fontSize: 13, color: AppTheme.gray600),
            ),
            const SizedBox(height: 20),
            ...PaymentGateway.values
                .map((g) => _GatewayTile(gateway: g)),
          ],
        ),
      ),
    );
  }
}

class _GatewayTile extends StatelessWidget {
  final PaymentGateway gateway;
  const _GatewayTile({required this.gateway});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).pop(gateway),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
                color: AppTheme.gray600.withValues(alpha: 0.2)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: gateway.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(gateway.icon, color: gateway.color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(gateway.label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                    Text(gateway.subtitle,
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.gray600)),
                    const SizedBox(height: 2),
                    Text(gateway.regionNote,
                        style: TextStyle(
                            fontSize: 11,
                            color: gateway.color,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: AppTheme.gray600.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}
