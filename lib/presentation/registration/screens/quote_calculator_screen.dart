import 'package:flutter/material.dart';

/// Stub — pricing/quote calculation happens via the web portal.
class QuoteCalculatorScreen extends StatelessWidget {
  final String? initialTier;

  const QuoteCalculatorScreen({super.key, this.initialTier});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pricing Calculator')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Pricing configuration is managed via the web portal.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
