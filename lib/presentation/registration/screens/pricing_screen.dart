import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/theme.dart';
import '../../../core/platform.dart';
import '../../../data/models/subscription_models.dart';
import '../../../data/providers/subscription_provider.dart';

class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionProvider>().loadPlans();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pricing Plans'), centerTitle: true),
      body: Consumer<SubscriptionProvider>(
        builder: (context, sp, _) {
          if (sp.isLoading && sp.plans.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (sp.plans.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, size: 48, color: AppTheme.gray600),
                  const SizedBox(height: 12),
                  const Text('No plans available.'),
                  if (sp.error != null) ...[
                    const SizedBox(height: 8),
                    Text(sp.error!,
                        style:
                            TextStyle(color: AppTheme.errorColor, fontSize: 13)),
                    const SizedBox(height: 16),
                    AdaptiveFilledButton(
                      onPressed: () => sp.loadPlans(),
                      child: const Text('Retry'),
                    ),
                  ],
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                const Text(
                  'Choose Your Plan',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Start with a free trial. No credit card required.',
                  style: TextStyle(fontSize: 16, color: AppTheme.gray600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ...sp.plans.map((plan) => _PlanCard(plan: plan)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final SubscriptionPlanModel plan;

  const _PlanCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    final ngnPrice = plan.prices['ngn'] ?? 0;
    final displayPrice = ngnPrice > 0
        ? '₦${ngnPrice.toStringAsFixed(0)}/${plan.billingCycle == 'annual' ? 'yr' : 'mo'}'
        : 'Contact sales';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(plan.name,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            if (plan.description != null) ...[
              const SizedBox(height: 4),
              Text(plan.description!,
                  style: TextStyle(color: AppTheme.gray600, fontSize: 13)),
            ],
            const SizedBox(height: 12),
            Text(displayPrice,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor)),
            if (plan.limits.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  if (plan.limits['max_facilities'] != null)
                    Chip(
                        label:
                            Text('${plan.limits['max_facilities']} facilities')),
                  if (plan.limits['max_staff'] != null)
                    Chip(label: Text('${plan.limits['max_staff']} staff')),
                  if (plan.limits['max_patients'] != null)
                    Chip(label: Text('${plan.limits['max_patients']} patients')),
                ],
              ),
            ],
            if (plan.features.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...plan.features.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(children: [
                      Icon(Icons.check, size: 16, color: AppTheme.successColor),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(f, style: const TextStyle(fontSize: 13))),
                    ]),
                  )),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: AdaptiveFilledButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed('/registration/calculator'),
                child: const Text('Get Started'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
