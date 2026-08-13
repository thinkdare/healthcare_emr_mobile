import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/platform.dart';
import '../../../data/providers/subscription_provider.dart';
import '../../../config/app_colors.dart';

class TrialStatusBanner extends StatelessWidget {
  const TrialStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionProvider>(
      builder: (context, subscriptionProvider, child) {
        final subscription = subscriptionProvider.subscription;

        if (subscription == null || !subscription.isTrial) {
          return const SizedBox.shrink();
        }

        final daysRemaining = subscription.trialDaysRemaining ?? 0;
        final isUrgent = daysRemaining <= 7;
        // The banner is filled with warning->critical (urgent) or accent.
        // Both on-colors resolve to the same value per theme, so one variable
        // covers the whole banner.
        final onFill = isUrgent
            ? AppColors.of(context).onWarning
            : AppColors.of(context).onAccent;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isUrgent
                  ? [
                      AppColors.of(context).warning,
                      AppColors.of(context).critical,
                    ]
                  : [
                      AppColors.of(context).accent,
                      AppColors.of(context).accent,
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Icon(
                  isUrgent ? Icons.warning_amber : Icons.access_time,
                  color: onFill,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        daysRemaining == 0
                            ? 'Trial expires today!'
                            : daysRemaining == 1
                            ? 'Trial expires tomorrow'
                            : 'Trial expires in $daysRemaining days',
                        style: TextStyle(
                          color: onFill,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Upgrade to continue using all features',
                        style: TextStyle(
                          color: onFill,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                kIsIOS
                    ? CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(
                          context,
                        ).pushNamed('/subscription/upgrade'),
                        child: Text(
                          'Upgrade',
                          style: TextStyle(
                            color: onFill,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : TextButton(
                        onPressed: () => Navigator.of(
                          context,
                        ).pushNamed('/subscription/upgrade'),
                        style: TextButton.styleFrom(
                          backgroundColor: onFill,
                          foregroundColor: isUrgent
                              ? AppColors.of(context).warning
                              : AppColors.of(context).accent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Text(
                          'Upgrade',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }
}
