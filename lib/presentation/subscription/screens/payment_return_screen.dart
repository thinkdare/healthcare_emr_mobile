// lib/presentation/subscription/screens/payment_return_screen.dart
//
// Shown immediately after the user returns from the hosted payment page via
// the voya://payment/return deep link. Verifies the payment server-side and
// displays success, pending, or failure accordingly.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/theme.dart';
import '../../../core/platform.dart';
import '../../../data/providers/subscription_provider.dart';

class PaymentReturnScreen extends StatefulWidget {
  final String status;        // success | cancelled | pending | unknown
  final String? reference;
  final String? gateway;
  final String? transactionId; // Flutterwave
  final String? sessionId;     // Stripe

  const PaymentReturnScreen({
    super.key,
    required this.status,
    this.reference,
    this.gateway,
    this.transactionId,
    this.sessionId,
  });

  @override
  State<PaymentReturnScreen> createState() => _PaymentReturnScreenState();
}

class _PaymentReturnScreenState extends State<PaymentReturnScreen> {
  _VerifyState _verifyState = _VerifyState.idle;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.status == 'success' && widget.reference != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _verify());
    }
  }

  Future<void> _verify() async {
    setState(() {
      _verifyState  = _VerifyState.verifying;
      _errorMessage = null;
    });

    final sp = context.read<SubscriptionProvider>();
    final ok = await sp.verifyPayment(
      reference:     widget.reference!,
      gateway:       widget.gateway ?? 'paystack',
      transactionId: widget.transactionId,
      sessionId:     widget.sessionId,
    );

    if (!mounted) return;

    setState(() {
      _verifyState  = ok ? _VerifyState.success : _VerifyState.failed;
      _errorMessage = ok ? null : sp.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = kIsIOS
        ? CupertinoPageScaffold(
            navigationBar: const CupertinoNavigationBar(
              middle: Text('Payment'),
            ),
            child: SafeArea(child: _body()),
          )
        : Scaffold(
            appBar: AppBar(title: const Text('Payment')),
            body: _body(),
          );

    return scaffold;
  }

  Widget _body() {
    // Cancelled by user
    if (widget.status == 'cancelled') {
      return _StatusView(
        icon: Icons.cancel_outlined,
        color: AppTheme.warningColor,
        title: 'Payment cancelled',
        subtitle: 'You cancelled the payment. Your current subscription has not changed.',
        actions: [
          _ActionButton(
            label: 'Go back',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
    }

    // Verifying in progress
    if (_verifyState == _VerifyState.verifying ||
        (_verifyState == _VerifyState.idle && widget.status == 'success')) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Verifying payment…',
                style: TextStyle(fontSize: 15, color: AppTheme.gray600)),
          ],
        ),
      );
    }

    // Server-confirmed success
    if (_verifyState == _VerifyState.success) {
      return _StatusView(
        icon: Icons.check_circle_outline,
        color: AppTheme.successColor,
        title: 'Payment successful!',
        subtitle: 'Your subscription has been activated. You now have full access to Voya.',
        actions: [
          _ActionButton(
            label: 'Continue',
            onPressed: () => Navigator.of(context).pop(),
            primary: true,
          ),
        ],
      );
    }

    // Verification failed
    if (_verifyState == _VerifyState.failed) {
      return _StatusView(
        icon: Icons.error_outline,
        color: AppTheme.errorColor,
        title: 'Verification failed',
        subtitle: _errorMessage ??
            'We could not confirm your payment. If money was deducted, please contact support with your reference: ${widget.reference ?? "N/A"}',
        actions: [
          _ActionButton(
            label: 'Retry verification',
            onPressed: _verify,
            primary: true,
          ),
          _ActionButton(
            label: 'Go back',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
    }

    // Unknown / pending status
    return _StatusView(
      icon: Icons.hourglass_empty,
      color: AppTheme.warningColor,
      title: 'Payment pending',
      subtitle:
          'Your payment is being processed. Your subscription will be activated once confirmed. Reference: ${widget.reference ?? "N/A"}',
      actions: [
        if (widget.reference != null)
          _ActionButton(
            label: 'Check now',
            onPressed: _verify,
            primary: true,
          ),
        _ActionButton(
          label: 'Go back',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

enum _VerifyState { idle, verifying, success, failed }

class _StatusView extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final List<Widget> actions;

  const _StatusView({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: color),
            const SizedBox(height: 20),
            Text(title,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(subtitle,
                style: TextStyle(fontSize: 14, color: AppTheme.gray600),
                textAlign: TextAlign.center),
            const SizedBox(height: 32),
            ...actions,
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool primary;

  const _ActionButton({
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        child: primary
            ? ElevatedButton(onPressed: onPressed, child: Text(label))
            : OutlinedButton(onPressed: onPressed, child: Text(label)),
      ),
    );
  }
}
