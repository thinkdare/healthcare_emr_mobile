import 'package:flutter/material.dart';

/// Stub — organization registration is handled via the web portal.
class OrganizationRegistrationScreen extends StatelessWidget {
  final int numFacilities;
  final int numProviders;
  final String billingCycle;

  const OrganizationRegistrationScreen({
    super.key,
    this.numFacilities = 1,
    this.numProviders = 1,
    this.billingCycle = 'annual',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Organization Registration')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Organization registration is handled via the web portal. '
            'Contact your administrator for access.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
