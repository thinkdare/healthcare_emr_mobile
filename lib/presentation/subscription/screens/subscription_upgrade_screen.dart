import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/providers/subscription_provider.dart';
import '../../../config/theme.dart';

class SubscriptionUpgradeScreen extends StatefulWidget {
  const SubscriptionUpgradeScreen({super.key});

  @override
  State<SubscriptionUpgradeScreen> createState() => _SubscriptionUpgradeScreenState();
}

class _SubscriptionUpgradeScreenState extends State<SubscriptionUpgradeScreen> {
  String _selectedCycle = 'annual';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionProvider>().loadTrialStatus();
    });
  }

  Future<void> _handleUpgrade() async {
    setState(() => _isProcessing = true);

    final subscriptionProvider = context.read<SubscriptionProvider>();
    
    // Create checkout session
    final result = await subscriptionProvider.createUpgradeCheckout(
      billingCycle: _selectedCycle,
      successUrl: 'emrsystem://subscription/success',
      cancelUrl: 'emrsystem://subscription/cancel',
    );

    setState(() => _isProcessing = false);

    if (result != null && mounted) {
      final checkoutUrl = result['checkout_url'];
      
      // Open Stripe checkout in browser
      final uri = Uri.parse(checkoutUrl!);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        
        // Show instructions
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Complete Payment'),
              content: const Text(
                'You\'ve been redirected to Stripe to complete your payment. '
                'Once payment is successful, your subscription will be activated automatically.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to open payment page'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            subscriptionProvider.error ?? 'Failed to create checkout session',
          ),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upgrade Subscription'),
      ),
      body: Consumer<SubscriptionProvider>(
        builder: (context, subscriptionProvider, child) {
          if (subscriptionProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final trialStatus = subscriptionProvider.trialStatus;
          final quote = subscriptionProvider.quote;

          return SingleChildScrollView(
            padding: EdgeInsets.all(isWeb ? 32 : 16),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isWeb ? 700 : double.infinity),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Text(
                      'Upgrade to Paid Plan',
                      style: TextStyle(
                        fontSize: isWeb ? 32 : 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.gray900,
                      ),
                      textAlign: isWeb ? TextAlign.center : TextAlign.left,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Continue using all features after your trial ends',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.gray600,
                      ),
                      textAlign: isWeb ? TextAlign.center : TextAlign.left,
                    ),
                    const SizedBox(height: 32),

                    // Trial Status
                    if (trialStatus != null && trialStatus.onTrial)
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
                            Icon(Icons.schedule, color: AppTheme.warningColor),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Your trial ends in ${trialStatus.trialDaysRemaining} days',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.warningColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Upgrade now to ensure uninterrupted access',
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
                      ),
                    const SizedBox(height: 24),

                    // Billing Cycle Selection
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Select Billing Cycle',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Annual Option
                            _buildBillingOption(
                              'Annual',
                              'Pay yearly and save',
                              'annual',
                              badge: 'SAVE 15%',
                            ),
                            const SizedBox(height: 12),
                            
                            // Monthly Option
                            _buildBillingOption(
                              'Monthly',
                              'Pay month-to-month',
                              'monthly',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Current Plan Details
                    if (trialStatus != null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Your Plan',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Divider(height: 24),
                              _buildPlanDetail(
                                'Facilities',
                                '${trialStatus.maxFacilities} included',
                              ),
                              _buildPlanDetail(
                                'Providers',
                                '${trialStatus.maxProviders} included',
                              ),
                              _buildPlanDetail(
                                'Billing Cycle',
                                _selectedCycle == 'annual' ? 'Annual' : 'Monthly',
                              ),
                              if (quote != null) ...[
                                const Divider(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Total',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      quote.formattedTotal,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  'per ${_selectedCycle == 'annual' ? 'year' : 'month'}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.gray600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Features
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.gray50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'What You Get',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildFeature('Unlimited patient records'),
                          _buildFeature('Multi-facility support'),
                          _buildFeature('Provider management'),
                          _buildFeature('Secure data encryption'),
                          _buildFeature('24/7 customer support'),
                          _buildFeature('Free updates & new features'),
                          _buildFeature('HIPAA compliance'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Payment Button
                    SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _handleUpgrade,
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : const Icon(Icons.payment),
                        label: Text(_isProcessing ? 'Processing...' : 'Proceed to Payment'),
                        style: ElevatedButton.styleFrom(
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Security Notice
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock, size: 16, color: AppTheme.gray600),
                        const SizedBox(width: 8),
                        Text(
                          'Secure payment powered by Stripe',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.gray600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cancel anytime • No long-term commitment',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.gray600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBillingOption(
    String title,
    String description,
    String value, {
    String? badge,
  }) {
    final isSelected = _selectedCycle == value;

    return InkWell(
      onTap: () {
        setState(() => _selectedCycle = value);
        // Recalculate quote
        final trialStatus = context.read<SubscriptionProvider>().trialStatus;
        if (trialStatus != null) {
          context.read<SubscriptionProvider>().calculateQuote(
                numFacilities: trialStatus.maxFacilities,
                numProviders: trialStatus.maxProviders,
                billingCycle: value,
              );
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.gray600.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.05)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: _selectedCycle,
              onChanged: (val) {
                setState(() => _selectedCycle = val!);
                final trialStatus = context.read<SubscriptionProvider>().trialStatus;
                if (trialStatus != null) {
                  context.read<SubscriptionProvider>().calculateQuote(
                        numFacilities: trialStatus.maxFacilities,
                        numProviders: trialStatus.maxProviders,
                        billingCycle: val ?? '',
                      );
                }
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? AppTheme.primaryColor : AppTheme.gray900,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.successColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.gray600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.gray600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeature(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: AppTheme.successColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.gray600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}