import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/providers/subscription_provider.dart';
import '../../../config/theme.dart';

class SubscriptionDetailsScreen extends StatefulWidget {
  const SubscriptionDetailsScreen({super.key});

  @override
  State<SubscriptionDetailsScreen> createState() => _SubscriptionDetailsScreenState();
}

class _SubscriptionDetailsScreenState extends State<SubscriptionDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final provider = context.read<SubscriptionProvider>();
    await Future.wait([
      provider.loadTrialStatus(),
      provider.loadSubscription(),
    ]);
  }

  Future<void> _handleCancelSubscription() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Subscription'),
        content: const Text(
          'Are you sure you want to cancel your subscription? '
          'You will still have access until the end of your billing period.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Subscription'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Cancel Subscription'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await context.read<SubscriptionProvider>().cancelSubscription();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Subscription cancelled successfully'
                  : 'Failed to cancel subscription',
            ),
            backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
          ),
        );
        
        if (success) {
          _loadData();
        }
      }
    }
  }

  Future<void> _handleResumeSubscription() async {
    final success = await context.read<SubscriptionProvider>().resumeSubscription();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Subscription resumed successfully'
                : 'Failed to resume subscription',
          ),
          backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
        ),
      );
      
      if (success) {
        _loadData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: Consumer<SubscriptionProvider>(
          builder: (context, subscriptionProvider, child) {
            if (subscriptionProvider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final trialStatus = subscriptionProvider.trialStatus;
            final subscription = subscriptionProvider.subscription;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(isWeb ? 32 : 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isWeb ? 800 : double.infinity),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Status Card
                      if (trialStatus != null)
                        _buildStatusCard(trialStatus, subscription, isWeb),
                      const SizedBox(height: 24),

                      // Subscription Details
                      if (subscription != null)
                        _buildSubscriptionCard(subscription, isWeb),
                      const SizedBox(height: 24),

                      // Usage Card
                      if (trialStatus != null)
                        _buildUsageCard(trialStatus, isWeb),
                      const SizedBox(height: 24),

                      // Actions
                      if (trialStatus != null)
                        _buildActionsCard(trialStatus, subscription, isWeb),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusCard(trialStatus, subscription, bool isWeb) {
    final onTrial = trialStatus.onTrial;
    final isActive = trialStatus.isActive;
    
    Color statusColor = AppTheme.gray600;
    IconData statusIcon = Icons.help_outline;
    String statusText = trialStatus.subscriptionStatus;
    
    if (onTrial) {
      statusColor = AppTheme.warningColor;
      statusIcon = Icons.schedule;
      statusText = 'Free Trial';
    } else if (isActive) {
      statusColor = AppTheme.successColor;
      statusIcon = Icons.check_circle;
      statusText = 'Active';
    } else if (trialStatus.subscriptionStatus == 'past_due') {
      statusColor = AppTheme.errorColor;
      statusIcon = Icons.error;
      statusText = 'Payment Past Due';
    } else if (trialStatus.subscriptionStatus == 'cancelled') {
      statusColor = AppTheme.errorColor;
      statusIcon = Icons.cancel;
      statusText = 'Cancelled';
    }

    return Card(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              statusColor.withValues(alpha: 0.1),
              statusColor.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Icon(statusIcon, size: 64, color: statusColor),
            const SizedBox(height: 16),
            Text(
              statusText,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
            if (onTrial) ...[
              const SizedBox(height: 8),
              Text(
                '${trialStatus.trialDaysRemaining} days remaining',
                style: TextStyle(
                  fontSize: 18,
                  color: AppTheme.gray600,
                ),
              ),
              if (trialStatus.trialEndsAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Trial ends on ${_formatDate(trialStatus.trialEndsAt!)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.gray600,
                  ),
                ),
              ],
            ],
            if (!onTrial && subscription != null) ...[
              const SizedBox(height: 8),
              Text(
                'Next billing: ${_formatDate(subscription.currentPeriodEnd)}',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.gray600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard(subscription, bool isWeb) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.credit_card, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Subscription Details',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildDetailRow('Plan', subscription.planType.toUpperCase()),
            _buildDetailRow(
              'Billing Cycle',
              subscription.billingCycle == 'annual' ? 'Annual' : 'Monthly',
            ),
            _buildDetailRow('Amount', subscription.formattedAmount),
            _buildDetailRow('Currency', subscription.currency),
            _buildDetailRow(
              'Current Period',
              '${_formatDate(subscription.currentPeriodStart)} - ${_formatDate(subscription.currentPeriodEnd)}',
            ),
            _buildDetailRow(
              'Auto Renew',
              subscription.autoRenew ? 'Enabled' : 'Disabled',
            ),
            if (subscription.isCancelled && subscription.endsAt != null)
              _buildDetailRow(
                'Ends On',
                _formatDate(subscription.endsAt!),
                valueColor: AppTheme.errorColor,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageCard(trialStatus, bool isWeb) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Usage & Limits',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildUsageItem(
              'Facilities',
              trialStatus.currentFacilities,
              trialStatus.maxFacilities,
            ),
            const SizedBox(height: 16),
            _buildUsageItem(
              'Providers',
              trialStatus.currentProviders,
              trialStatus.maxProviders,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageItem(String label, int current, int max) {
    final percentage = current / max;
    final isNearLimit = percentage > 0.8;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '$current / $max',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isNearLimit ? AppTheme.warningColor : AppTheme.gray900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: percentage,
          backgroundColor: AppTheme.gray100,
          valueColor: AlwaysStoppedAnimation(
            isNearLimit ? AppTheme.warningColor : AppTheme.primaryColor,
          ),
        ),
        if (isNearLimit) ...[
          const SizedBox(height: 4),
          Text(
            'You\'re approaching your $label limit',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.warningColor,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionsCard(trialStatus, subscription, bool isWeb) {
    final onTrial = trialStatus.onTrial;
    final isCancelled = subscription?.isCancelled ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Actions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24),
            
            if (onTrial) ...[
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/subscription/upgrade');
                  },
                  icon: const Icon(Icons.upgrade),
                  label: const Text('Upgrade to Paid Plan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  ),
                ),
              ),
            ] else if (isCancelled) ...[
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _handleResumeSubscription,
                  icon: const Icon(Icons.replay),
                  label: const Text('Resume Subscription'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successColor,
                  ),
                ),
              ),
            ] else ...[
              SizedBox(
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: _handleCancelSubscription,
                  icon: const Icon(Icons.cancel),
                  label: const Text('Cancel Subscription'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorColor,
                    side: const BorderSide(color: AppTheme.errorColor),
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            SizedBox(
              height: 56,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamed('/subscription/invoices');
                },
                icon: const Icon(Icons.receipt_long),
                label: const Text('View Invoices'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: TextStyle(
                color: AppTheme.gray600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}