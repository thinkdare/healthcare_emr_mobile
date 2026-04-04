import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/providers/subscription_provider.dart';
import '../../../config/theme.dart';

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
      context.read<SubscriptionProvider>().loadPricing();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pricing Plans'),
        centerTitle: true,
      ),
      body: Consumer<SubscriptionProvider>(
        builder: (context, subscriptionProvider, child) {
          if (subscriptionProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (subscriptionProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load pricing',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.gray900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subscriptionProvider.error!,
                    style: TextStyle(color: AppTheme.gray600),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      subscriptionProvider.loadPricing();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final pricing = subscriptionProvider.pricing;
          if (pricing == null) {
            return const Center(child: Text('No pricing data available'));
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(isWeb ? 32 : 16),
            child: Column(
              children: [
                // Header
                const SizedBox(height: 16),
                Text(
                  'Choose Your Plan',
                  style: TextStyle(
                    fontSize: isWeb ? 36 : 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.gray900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Start with a 30-day free trial. No credit card required.',
                  style: TextStyle(
                    fontSize: isWeb ? 18 : 16,
                    color: AppTheme.gray600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // Pricing Cards
                if (isWeb)
                  _buildWebPricingGrid(pricing)
                else
                  _buildMobilePricingList(pricing),

                const SizedBox(height: 48),

                // Features Comparison (optional)
                _buildFeaturesSection(isWeb),

                const SizedBox(height: 48),

                // CTA
                _buildCTASection(isWeb),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWebPricingGrid(pricing) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1200),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildPricingCard(
              tier: 'small',
              name: pricing.small.name,
              organizationFee: pricing.small.organizationFee,
              facilityFee: pricing.small.facilityFee,
              providerFee: pricing.small.providerFee,
              maxProviders: pricing.small.maxProviders.toString(),
              isPrimary: false,
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: _buildPricingCard(
              tier: 'medium',
              name: pricing.medium.name,
              organizationFee: pricing.medium.organizationFee,
              facilityFee: pricing.medium.facilityFee,
              providerFee: pricing.medium.providerFee,
              maxProviders: pricing.medium.maxProviders.toString(),
              isPrimary: true,
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: _buildPricingCard(
              tier: 'large',
              name: pricing.large.name,
              organizationFee: pricing.large.organizationFee,
              facilityFee: pricing.large.facilityFee,
              providerFee: pricing.large.providerFee,
              maxProviders: pricing.large.maxProviders.toString(),
              isPrimary: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobilePricingList(pricing) {
    return Column(
      children: [
        _buildPricingCard(
          tier: 'small',
          name: pricing.small.name,
          organizationFee: pricing.small.organizationFee,
          facilityFee: pricing.small.facilityFee,
          providerFee: pricing.small.providerFee,
          maxProviders: pricing.small.maxProviders.toString(),
          isPrimary: false,
        ),
        const SizedBox(height: 16),
        _buildPricingCard(
          tier: 'medium',
          name: pricing.medium.name,
          organizationFee: pricing.medium.organizationFee,
          facilityFee: pricing.medium.facilityFee,
          providerFee: pricing.medium.providerFee,
          maxProviders: pricing.medium.maxProviders.toString(),
          isPrimary: true,
        ),
        const SizedBox(height: 16),
        _buildPricingCard(
          tier: 'large',
          name: pricing.large.name,
          organizationFee: pricing.large.organizationFee,
          facilityFee: pricing.large.facilityFee,
          providerFee: pricing.large.providerFee,
          maxProviders: pricing.large.maxProviders.toString(),
          isPrimary: false,
        ),
      ],
    );
  }

  Widget _buildPricingCard({
    required String tier,
    required String name,
    required String organizationFee,
    required String facilityFee,
    required String providerFee,
    required String maxProviders,
    required bool isPrimary,
  }) {
    return Card(
      elevation: isPrimary ? 8 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isPrimary
            ? const BorderSide(color: AppTheme.primaryColor, width: 2)
            : BorderSide.none,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isPrimary
              ? LinearGradient(
                  colors: [
                    AppTheme.primaryColor.withValues(alpha: 0.05),
                    AppTheme.secondaryColor.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isPrimary)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'RECOMMENDED',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (isPrimary) const SizedBox(height: 16),
            Text(
              name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.gray900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Up to $maxProviders providers',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.gray600,
              ),
            ),
            const SizedBox(height: 24),
            _buildPriceItem('Organization', organizationFee, 'per year'),
            const SizedBox(height: 12),
            _buildPriceItem('Per Facility', facilityFee, 'per year'),
            const SizedBox(height: 12),
            _buildPriceItem('Per Provider', providerFee, 'per month'),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            _buildFeature('30-day free trial'),
            _buildFeature('Unlimited patient records'),
            _buildFeature('Multi-facility support'),
            _buildFeature('Provider management'),
            _buildFeature('24/7 support'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushNamed(
                    '/registration/calculator',
                    arguments: tier,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isPrimary ? AppTheme.primaryColor : AppTheme.gray600,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Get Started'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceItem(String label, String amount, String period) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.gray600,
            fontWeight: FontWeight.w500,
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              amount,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.gray900,
              ),
            ),
            Text(
              period,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.gray600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeature(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: AppTheme.successColor, size: 20),
          const SizedBox(width: 8),
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

  Widget _buildFeaturesSection(bool isWeb) {
    return Container(
      padding: EdgeInsets.all(isWeb ? 32 : 16),
      decoration: BoxDecoration(
        color: AppTheme.gray50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            'All Plans Include',
            style: TextStyle(
              fontSize: isWeb ? 24 : 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.gray900,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              _buildFeatureItem(Icons.security, 'HIPAA Compliant'),
              _buildFeatureItem(Icons.cloud_done, 'Cloud Backup'),
              _buildFeatureItem(Icons.phone_in_talk, '24/7 Support'),
              _buildFeatureItem(Icons.update, 'Free Updates'),
              _buildFeatureItem(Icons.lock, 'Data Encryption'),
              _buildFeatureItem(Icons.devices, 'Multi-platform'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return SizedBox(
      width: 150,
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.gray600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCTASection(bool isWeb) {
    return Container(
      padding: EdgeInsets.all(isWeb ? 48 : 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            'Ready to Get Started?',
            style: TextStyle(
              fontSize: isWeb ? 32 : 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Start your 30-day free trial today. No credit card required.',
            style: TextStyle(
              fontSize: isWeb ? 18 : 16,
              color: Colors.white.withValues(alpha: 0.9),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pushNamed('/registration/calculator');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primaryColor,
              padding: EdgeInsets.symmetric(
                horizontal: isWeb ? 48 : 32,
                vertical: 16,
              ),
            ),
            child: const Text(
              'Calculate Your Cost',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}