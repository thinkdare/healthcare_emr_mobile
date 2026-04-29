import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/platform.dart';
import 'package:provider/provider.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/subscription_provider.dart';
import '../../../data/models/subscription_models.dart';
import '../../../config/theme.dart';

class SubscriptionUpgradeScreen extends StatefulWidget {
  const SubscriptionUpgradeScreen({super.key});

  @override
  State<SubscriptionUpgradeScreen> createState() =>
      _SubscriptionUpgradeScreenState();
}

class _SubscriptionUpgradeScreenState
    extends State<SubscriptionUpgradeScreen> {
  String? _selectedPlanId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionProvider>().loadPlans();
    });
  }

  Future<void> _handleSelectPlan(SubscriptionPlanModel plan) async {
    final auth = context.read<AuthProvider>();
    final sp = context.read<SubscriptionProvider>();

    final orgId = auth.organizationId;
    final sub = sp.subscription;

    if (orgId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No organization found. Contact your administrator.'),
        backgroundColor: AppTheme.errorColor,
      ));
      return;
    }

    setState(() => _selectedPlanId = plan.id);

    bool success;
    if (sub != null) {
      // Change existing plan
      success = await sp.changePlan(orgId, sub.id, planId: plan.id);
    } else {
      // Start a trial on the selected plan
      success = await sp.startTrial(orgId, planId: plan.id);
    }

    setState(() => _selectedPlanId = null);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Plan updated successfully'),
          backgroundColor: AppTheme.successColor,
        ));
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(sp.error ?? 'Failed to update plan'),
          backgroundColor: AppTheme.errorColor,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: kIsIOS
          ? const CupertinoNavigationBar(middle: Text('Choose a Plan'))
          : AppBar(title: const Text('Choose a Plan')),
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
                  const Text('No plans available at this time.'),
                  if (sp.error != null) ...[
                    const SizedBox(height: 8),
                    Text(sp.error!,
                        style: TextStyle(color: AppTheme.errorColor,
                            fontSize: 13)),
                  ],
                ],
              ),
            );
          }

          final currentPlanId = sp.subscription?.planId;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (sp.subscription?.isTrial == true) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppTheme.warningColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      Icon(Icons.schedule, color: AppTheme.warningColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${sp.subscription!.trialDaysRemaining ?? 0} days '
                          'remaining in your trial',
                          style: TextStyle(
                              color: AppTheme.warningColor,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ]),
                  ),
                ],

                ...sp.plans.map((plan) => _PlanCard(
                      plan: plan,
                      isCurrent: plan.id == currentPlanId,
                      isProcessing: _selectedPlanId == plan.id,
                      onSelect: _selectedPlanId == null
                          ? () => _handleSelectPlan(plan)
                          : null,
                    )),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Plan card ─────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final SubscriptionPlanModel plan;
  final bool isCurrent;
  final bool isProcessing;
  final VoidCallback? onSelect;

  const _PlanCard({
    required this.plan,
    required this.isCurrent,
    required this.isProcessing,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final ngnPrice = plan.prices['ngn'] ?? 0;
    final displayPrice = ngnPrice > 0
        ? '₦${ngnPrice.toStringAsFixed(0)}/${plan.billingCycle == 'annual' ? 'yr' : 'mo'}'
        : 'Contact sales';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isCurrent
              ? AppTheme.primaryColor
              : AppTheme.gray600.withValues(alpha: 0.2),
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(plan.name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('Current',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            if (plan.description != null) ...[
              const SizedBox(height: 6),
              Text(plan.description!,
                  style: TextStyle(color: AppTheme.gray600, fontSize: 13)),
            ],
            const SizedBox(height: 12),
            Text(displayPrice,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor)),
            if (plan.limits.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (plan.limits['max_facilities'] != null)
                    _Chip('${plan.limits['max_facilities']} facilities'),
                  if (plan.limits['max_staff'] != null)
                    _Chip('${plan.limits['max_staff']} staff'),
                  if (plan.limits['max_patients'] != null)
                    _Chip('${plan.limits['max_patients']} patients'),
                ],
              ),
            ],
            if (plan.features.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...plan.features.take(4).map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(children: [
                      Icon(Icons.check,
                          size: 16, color: AppTheme.successColor),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(f,
                              style: const TextStyle(fontSize: 13))),
                    ]),
                  )),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: isCurrent
                  ? OutlinedButton(
                      onPressed: null,
                      child: const Text('Current Plan'),
                    )
                  : ElevatedButton(
                      onPressed: onSelect,
                      child: isProcessing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                      Colors.white)),
                            )
                          : const Text('Select Plan'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, color: AppTheme.primaryColor)),
    );
  }
}
