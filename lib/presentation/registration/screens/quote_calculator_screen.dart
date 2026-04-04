import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../data/providers/subscription_provider.dart';
import '../../../config/theme.dart';

class QuoteCalculatorScreen extends StatefulWidget {
  final String? initialTier;

  const QuoteCalculatorScreen({super.key, this.initialTier});

  @override
  State<QuoteCalculatorScreen> createState() => _QuoteCalculatorScreenState();
}

class _QuoteCalculatorScreenState extends State<QuoteCalculatorScreen> {
  final _formKey = GlobalKey<FormState>();
  int _numFacilities = 1;
  int _numProviders = 5;
  String _billingCycle = 'annual';
  bool _calculating = false;

  @override
  void initState() {
    super.initState();
    // Set initial values based on tier
    if (widget.initialTier == 'small') {
      _numProviders = 5;
    } else if (widget.initialTier == 'medium') {
      _numProviders = 25;
    } else if (widget.initialTier == 'large') {
      _numProviders = 100;
    }
    _calculateQuote();
  }

  Future<void> _calculateQuote() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _calculating = true);

    await context.read<SubscriptionProvider>().calculateQuote(
          numFacilities: _numFacilities,
          numProviders: _numProviders,
          billingCycle: _billingCycle,
        );

    setState(() => _calculating = false);
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculate Your Cost'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isWeb ? 32 : 16),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isWeb ? 800 : double.infinity),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Text(
                    'Customize Your Plan',
                    style: TextStyle(
                      fontSize: isWeb ? 32 : 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.gray900,
                    ),
                    textAlign: isWeb ? TextAlign.center : TextAlign.left,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tell us about your organization to get a personalized quote',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.gray600,
                    ),
                    textAlign: isWeb ? TextAlign.center : TextAlign.left,
                  ),
                  const SizedBox(height: 48),

                  // Inputs Card
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Number of Facilities
                          const Text(
                            'Number of Facilities',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'How many branches/locations do you have?',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.gray600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Slider(
                                  value: _numFacilities.toDouble(),
                                  min: 1,
                                  max: 20,
                                  divisions: 19,
                                  label: _numFacilities.toString(),
                                  onChanged: (value) {
                                    setState(() {
                                      _numFacilities = value.toInt();
                                    });
                                    _calculateQuote();
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              SizedBox(
                                width: 80,
                                child: TextFormField(
                                  initialValue: _numFacilities.toString(),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: const InputDecoration(
                                    suffixText: 'facilities',
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  onChanged: (value) {
                                    final num = int.tryParse(value);
                                    if (num != null && num >= 1 && num <= 100) {
                                      setState(() => _numFacilities = num);
                                      _calculateQuote();
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),

                          // Number of Providers
                          const Text(
                            'Number of Providers',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'How many doctors, nurses, and staff will use the system?',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.gray600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Slider(
                                  value: _numProviders.toDouble(),
                                  min: 1,
                                  max: 200,
                                  divisions: 199,
                                  label: _numProviders.toString(),
                                  onChanged: (value) {
                                    setState(() {
                                      _numProviders = value.toInt();
                                    });
                                    _calculateQuote();
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              SizedBox(
                                width: 80,
                                child: TextFormField(
                                  initialValue: _numProviders.toString(),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: const InputDecoration(
                                    suffixText: 'providers',
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  onChanged: (value) {
                                    final num = int.tryParse(value);
                                    if (num != null && num >= 1 && num <= 1000) {
                                      setState(() => _numProviders = num);
                                      _calculateQuote();
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),

                          // Billing Cycle
                          const Text(
                            'Billing Cycle',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'monthly',
                                label: Text('Monthly'),
                                icon: Icon(Icons.calendar_today),
                              ),
                              ButtonSegment(
                                value: 'annual',
                                label: Text('Annual'),
                                icon: Icon(Icons.calendar_month),
                              ),
                            ],
                            selected: {_billingCycle},
                            onSelectionChanged: (Set<String> selected) {
                              setState(() {
                                _billingCycle = selected.first;
                              });
                              _calculateQuote();
                            },
                          ),
                          if (_billingCycle == 'annual') ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.successColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.savings,
                                    color: AppTheme.successColor,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Save with annual billing',
                                      style: TextStyle(
                                        color: AppTheme.successColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Quote Result
                  Consumer<SubscriptionProvider>(
                    builder: (context, subscriptionProvider, child) {
                      final quote = subscriptionProvider.quote;

                      if (_calculating) {
                        return const Card(
                          child: Padding(
                            padding: EdgeInsets.all(48),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        );
                      }

                      if (quote == null) {
                        return const SizedBox.shrink();
                      }

                      return Card(
                        elevation: 4,
                        color: AppTheme.primaryColor,
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppTheme.primaryColor,
                                AppTheme.secondaryColor,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Your Total Cost',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.white70,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        quote.formattedTotal,
                                        style: const TextStyle(
                                          fontSize: 36,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Text(
                                        'per ${_billingCycle == 'annual' ? 'year' : 'month'}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      quote.tier.toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              const Divider(color: Colors.white24),
                              const SizedBox(height: 16),
                              const Text(
                                'Cost Breakdown',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildBreakdownItem(
                                'Organization Fee',
                                '₦${(quote.breakdown['organization_fee']! / 100).toStringAsFixed(2)}',
                              ),
                              _buildBreakdownItem(
                                'Facilities (${quote.numFacilities})',
                                '₦${(quote.breakdown['facilities_fee']! / 100).toStringAsFixed(2)}',
                              ),
                              _buildBreakdownItem(
                                'Providers (${quote.numProviders})',
                                '₦${(quote.breakdown['providers_fee']! / 100).toStringAsFixed(2)}',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  // CTA Button
                  SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushNamed(
                          '/registration/form',
                          arguments: {
                            'num_facilities': _numFacilities,
                            'num_providers': _numProviders,
                            'billing_cycle': _billingCycle,
                          },
                        );
                      },
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Continue to Registration'),
                      style: ElevatedButton.styleFrom(
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      '30-day free trial • No credit card required',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.gray600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBreakdownItem(String label, String amount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}