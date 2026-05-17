// Stub — full implementation in Task 5
import 'package:flutter/material.dart';
import '../../../data/models/referral_models.dart';

class ReferralDetailScreen extends StatelessWidget {
  final ReferralModel referral;
  const ReferralDetailScreen({super.key, required this.referral});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
