import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/platform.dart';
import '../../../data/providers/subscription_provider.dart';
import '../../../config/app_colors.dart';

class SubscriptionExpiredScreen extends StatelessWidget {
  const SubscriptionExpiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_clock,
                  size: 100,
                  color: AppColors.of(context).critical.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 32),
                Text(
                  'Subscription Expired',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.of(context).textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Your organization\'s subscription has expired. '
                  'Please contact your administrator to renew.',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.of(context).textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                Consumer<SubscriptionProvider>(
                  builder: (context, sp, _) {
                    final isTrial = sp.subscription?.isTrial ?? false;
                    return isTrial
                        ? _buildTrialBanner(context)
                        : _buildExpiredBanner(context);
                  },
                ),

                const SizedBox(height: 32),
                _buildContactSupport(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrialBanner(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.of(context).warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.of(context).warning.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.of(context).warning),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your free trial has ended',
                  style: TextStyle(
                    color: AppColors.of(context).warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: AdaptiveFilledButton(
            onPressed: () =>
                Navigator.of(context).pushNamed('/subscription/upgrade'),
            icon: const Icon(Icons.upgrade),
            child: const Text('Upgrade Now'),
          ),
        ),
      ],
    );
  }

  Widget _buildExpiredBanner(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.of(context).critical.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.of(context).critical.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: AppColors.of(context).critical,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Payment Required',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Please contact your organization administrator to '
                'renew the subscription.',
                style: TextStyle(color: AppColors.of(context).textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pushNamed('/auth/logout'),
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactSupport(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.of(context).surfaceTint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.support_agent, color: AppColors.of(context).textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Need Help?',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  'Contact support@emrsystem.com',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.of(context).textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
