import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/providers/subscription_provider.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../config/theme.dart';
import '../../../config/app_config.dart';

class OrganizationRegistrationScreen extends StatefulWidget {
  final int numFacilities;
  final int numProviders;
  final String billingCycle;

  const OrganizationRegistrationScreen({
    super.key,
    required this.numFacilities,
    required this.numProviders,
    required this.billingCycle,
  });

  @override
  State<OrganizationRegistrationScreen> createState() =>
      _OrganizationRegistrationScreenState();
}

class _OrganizationRegistrationScreenState
    extends State<OrganizationRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  int _currentStep = 0;

  // Organization fields
  final _orgNameController = TextEditingController();
  String _orgType = 'hospital';
  final _orgAddressController = TextEditingController();
  final _orgPhoneController = TextEditingController();
  final _orgEmailController = TextEditingController();
  final _taxIdController = TextEditingController();

  // Admin fields
  final _adminFirstNameController = TextEditingController();
  final _adminLastNameController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _adminPhoneController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  final _adminPasswordConfirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isRegistering = false;

  @override
  void dispose() {
    _orgNameController.dispose();
    _orgAddressController.dispose();
    _orgPhoneController.dispose();
    _orgEmailController.dispose();
    _taxIdController.dispose();
    _adminFirstNameController.dispose();
    _adminLastNameController.dispose();
    _adminEmailController.dispose();
    _adminPhoneController.dispose();
    _adminPasswordController.dispose();
    _adminPasswordConfirmController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 0) {
      // Validate organization form
      if (!_formKey.currentState!.validate()) return;
      setState(() => _currentStep = 1);
      _pageController.animateToPage(
        1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else if (_currentStep == 1) {
      // Validate admin form
      if (!_formKey.currentState!.validate()) return;
      setState(() => _currentStep = 2);
      _pageController.animateToPage(
        2,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isRegistering = true);

    final subscriptionProvider = context.read<SubscriptionProvider>();
    final authProvider = context.read<AuthProvider>();

    final response = await subscriptionProvider.registerOrganization(
      organizationName: _orgNameController.text.trim(),
      organizationType: _orgType,
      address: _orgAddressController.text.trim(),
      phone: _orgPhoneController.text.trim(),
      email: _orgEmailController.text.trim(),
      taxId: _taxIdController.text.trim(),
      adminFirstName: _adminFirstNameController.text.trim(),
      adminLastName: _adminLastNameController.text.trim(),
      adminEmail: _adminEmailController.text.trim(),
      adminPhone: _adminPhoneController.text.trim(),
      adminPassword: _adminPasswordController.text,
      numFacilities: widget.numFacilities,
      numProviders: widget.numProviders,
      billingCycle: widget.billingCycle,
    );

    setState(() => _isRegistering = false);

    if (mounted && response != null) {
      // Navigate to welcome screen
      Navigator.of(context).pushReplacementNamed(
        '/registration/welcome',
        arguments: response,
      );
    } else if (mounted) {
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            subscriptionProvider.error ??
                'Registration failed. Please try again.',
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
        title: const Text('Register Your Organization'),
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _previousStep,
              )
            : null,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Progress Indicator
            LinearProgressIndicator(
              value: (_currentStep + 1) / 3,
              backgroundColor: AppTheme.gray100,
              valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
            ),
            
            // Step Indicator
            Padding(
              padding: EdgeInsets.all(isWeb ? 24 : 16),
              child: Row(
                children: [
                  _buildStepIndicator(0, 'Organization'),
                  Expanded(child: Divider(color: AppTheme.gray600)),
                  _buildStepIndicator(1, 'Administrator'),
                  Expanded(child: Divider(color: AppTheme.gray600)),
                  _buildStepIndicator(2, 'Review'),
                ],
              ),
            ),

            // Form Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildOrganizationForm(isWeb),
                  _buildAdminForm(isWeb),
                  _buildReviewForm(isWeb),
                ],
              ),
            ),

            // Bottom Actions
            Container(
              padding: EdgeInsets.all(isWeb ? 24 : 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: _currentStep == 2
                    ? SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isRegistering ? null : _submitRegistration,
                          child: _isRegistering
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation(Colors.white),
                                  ),
                                )
                              : const Text('Start Free Trial'),
                        ),
                      )
                    : SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _nextStep,
                          child: const Text('Continue'),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label) {
    final isActive = _currentStep >= step;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? AppTheme.primaryColor : AppTheme.gray100,
          ),
          child: Center(
            child: isActive
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      color: AppTheme.gray600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            color: isActive ? AppTheme.primaryColor : AppTheme.gray600,
          ),
        ),
      ],
    );
  }

  Widget _buildOrganizationForm(bool isWeb) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isWeb ? 32 : 16),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isWeb ? 600 : double.infinity),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Organization Details',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tell us about your healthcare organization',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.gray600,
                ),
              ),
              const SizedBox(height: 32),

              TextFormField(
                controller: _orgNameController,
                decoration: const InputDecoration(
                  labelText: 'Organization Name *',
                  hintText: 'e.g., City General Hospital',
                  prefixIcon: Icon(Icons.business),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Organization name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              DropdownButtonFormField<String>(
                value: _orgType,
                decoration: const InputDecoration(
                  labelText: 'Organization Type *',
                  prefixIcon: Icon(Icons.category),
                ),
                items: AppConfig.organizationTypeNames.entries.map((entry) {
                  return DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _orgType = value!);
                },
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _orgAddressController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Address *',
                  hintText: 'Enter full address',
                  prefixIcon: Icon(Icons.location_on),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Address is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _orgPhoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number *',
                  hintText: '+234...',
                  prefixIcon: Icon(Icons.phone),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Phone number is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _orgEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email Address *',
                  hintText: 'info@hospital.com',
                  prefixIcon: Icon(Icons.email),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Email is required';
                  }
                  if (!value.contains('@')) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _taxIdController,
                decoration: const InputDecoration(
                  labelText: 'Tax ID (Optional)',
                  hintText: 'Tax identification number',
                  prefixIcon: Icon(Icons.badge),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminForm(bool isWeb) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isWeb ? 32 : 16),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isWeb ? 600 : double.infinity),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Administrator Account',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This person will manage your organization',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.gray600,
                ),
              ),
              const SizedBox(height: 32),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _adminFirstNameController,
                      decoration: const InputDecoration(
                        labelText: 'First Name *',
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Required';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _adminLastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Last Name *',
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Required';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _adminEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email Address *',
                  hintText: 'admin@hospital.com',
                  prefixIcon: Icon(Icons.email),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Email is required';
                  }
                  if (!value.contains('@')) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _adminPhoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number *',
                  prefixIcon: Icon(Icons.phone),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Phone is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _adminPasswordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password *',
                  hintText: 'Min. 12 characters',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Password is required';
                  }
                  if (value.length < 12) {
                    return 'Password must be at least 12 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _adminPasswordConfirmController,
                obscureText: _obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: 'Confirm Password *',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () {
                      setState(() =>
                          _obscureConfirmPassword = !_obscureConfirmPassword);
                    },
                  ),
                ),
                validator: (value) {
                  if (value != _adminPasswordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewForm(bool isWeb) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isWeb ? 32 : 16),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isWeb ? 600 : double.infinity),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Review & Confirm',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please review your information before starting your trial',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.gray600,
                ),
              ),
              const SizedBox(height: 32),

              // Organization Summary
              _buildSummaryCard(
                'Organization Details',
                [
                  _buildSummaryItem('Name', _orgNameController.text),
                  _buildSummaryItem(
                    'Type',
                    AppConfig.organizationTypeNames[_orgType] ?? _orgType,
                  ),
                  _buildSummaryItem('Address', _orgAddressController.text),
                  _buildSummaryItem('Phone', _orgPhoneController.text),
                  _buildSummaryItem('Email', _orgEmailController.text),
                ],
                onEdit: () => setState(() {
                  _currentStep = 0;
                  _pageController.jumpToPage(0);
                }),
              ),
              const SizedBox(height: 16),

              // Admin Summary
              _buildSummaryCard(
                'Administrator',
                [
                  _buildSummaryItem(
                    'Name',
                    '${_adminFirstNameController.text} ${_adminLastNameController.text}',
                  ),
                  _buildSummaryItem('Email', _adminEmailController.text),
                  _buildSummaryItem('Phone', _adminPhoneController.text),
                ],
                onEdit: () => setState(() {
                  _currentStep = 1;
                  _pageController.jumpToPage(1);
                }),
              ),
              const SizedBox(height: 16),

              // Subscription Summary
              Consumer<SubscriptionProvider>(
                builder: (context, subscriptionProvider, child) {
                  final quote = subscriptionProvider.quote;
                  return _buildSummaryCard(
                    'Subscription Plan',
                    [
                      _buildSummaryItem('Facilities', widget.numFacilities.toString()),
                      _buildSummaryItem('Providers', widget.numProviders.toString()),
                      _buildSummaryItem(
                        'Billing Cycle',
                        widget.billingCycle == 'annual' ? 'Annual' : 'Monthly',
                      ),
                      if (quote != null)
                        _buildSummaryItem(
                          'Total Cost',
                          quote.formattedTotal,
                          valueStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                    ],
                    onEdit: null, // Can't edit subscription from here
                  );
                },
              ),
              const SizedBox(height: 24),

              // Trial Notice
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.successColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.celebration, color: AppTheme.successColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '30-Day Free Trial',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.successColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'No credit card required. Full access to all features.',
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    List<Widget> items, {
    VoidCallback? onEdit,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (onEdit != null)
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                  ),
              ],
            ),
            const Divider(),
            ...items,
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value, {
    TextStyle? valueStyle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
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
              style: valueStyle ??
                  const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}