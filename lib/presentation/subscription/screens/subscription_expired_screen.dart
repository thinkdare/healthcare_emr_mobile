import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/providers/subscription_provider.dart';
import '../../../config/theme.dart';

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
                  color: AppTheme.errorColor.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Subscription Expired',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.gray900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Your organization\'s subscription has expired. Please contact your administrator to renew.',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.gray600,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                Consumer<SubscriptionProvider>(
                  builder: (context, subscriptionProvider, child) {
                    final trialStatus = subscriptionProvider.trialStatus;

                    if (trialStatus != null &&
                        trialStatus.subscriptionStatus == 'trial') {
                      return _buildTrialExpiredContent(context);
                    }

                    return _buildSubscriptionExpiredContent(context);
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

  Widget _buildTrialExpiredContent(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.warningColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.warningColor.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AppTheme.warningColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your 30-day free trial has ended',
                  style: TextStyle(
                    color: AppTheme.warningColor,
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
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pushNamed('/subscription/upgrade');
            },
            icon: const Icon(Icons.upgrade),
            label: const Text('Upgrade Now'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AppTheme.primaryColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionExpiredContent(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.errorColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.errorColor.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.error_outline, color: AppTheme.errorColor),
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
                'Please contact your organization administrator to renew the subscription.',
                style: TextStyle(color: AppTheme.gray600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pushNamed('/auth/logout');
            },
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
        color: AppTheme.gray50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.support_agent, color: AppTheme.gray600),
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
                    color: AppTheme.gray600,
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