import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/models.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/organization_provider.dart';
import '../../../config/theme.dart';
import '../../dashboard/screens/provider_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // State
  bool _emailChecked = false;
  bool _loading = false;
  bool _obscurePassword = true;
  OrganizationLiteModel? _selectedOrg;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Step 1: Check email and get organizations
  Future<void> _checkEmail() async {
    if (_emailController.text.trim().isEmpty) {
      _showError('Please enter your email');
      return;
    }

    if (!_emailController.text.contains('@')) {
      _showError('Please enter a valid email');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final orgProvider = context.read<OrganizationProvider>();
    final result = await orgProvider.checkEmail(_emailController.text.trim());

    if (mounted) {
      if (result != null && result.isNotEmpty) {
        setState(() {
          _emailChecked = true;
          _loading = false;
          // Auto-select if only one organization
          _selectedOrg = result.length == 1 
              ? result.first 
              : null;
        });
      } else {
        setState(() {
          _loading = false;
          _errorMessage = orgProvider.error ?? 'No provider account found with this email';
        });
      }
    }
  }

  /// Step 2: Login with password and organization
  Future<void> _login() async {
    if (_selectedOrg == null) {
      _showError('Please select an organization');
      return;
    }

    if (_passwordController.text.isEmpty) {
      _showError('Please enter your password');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      organizationId: _selectedOrg!.id,
    );

    if (mounted) {
      if (success) {
        // Navigate to dashboard
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const ProviderDashboardScreen(),
          ),
        );
      } else {
        // Show error and reset to step 1
        setState(() {
          _loading = false;
          _errorMessage = authProvider.error?.userMessage ?? 'Login failed. Please try again.';
          _emailChecked = false;
          _selectedOrg = null;
          _passwordController.clear();
        });
        context.read<OrganizationProvider>().clearOrganizations();
      }
    }
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
    });
  }

  void _resetToEmailStep() {
    setState(() {
      _emailChecked = false;
      _selectedOrg = null;
      _passwordController.clear();
      _errorMessage = null;
    });
    context.read<OrganizationProvider>().clearOrganizations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo/Header
                    Icon(
                      Icons.local_hospital,
                      size: 80,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Healthcare EMR',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.gray900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Provider Login',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.gray600,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Error message
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.errorColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: AppTheme.errorColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: AppTheme.errorColor,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Email field (always shown)
                    TextFormField(
                      controller: _emailController,
                      enabled: !_emailChecked && !_loading,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        hintText: 'Enter your email',
                        prefixIcon: const Icon(Icons.email_outlined),
                        suffixIcon: _emailChecked
                            ? IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: _resetToEmailStep,
                                tooltip: 'Change email',
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Step 1: Check Email Button
                    if (!_emailChecked) ...[
                      ElevatedButton(
                        onPressed: _loading ? null : _checkEmail,
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : const Text('Next'),
                      ),
                    ],

                    // Step 2: Organization & Password
                    if (_emailChecked) ...[
                      // Organization selector
                      _buildOrganizationSelector(),
                      const SizedBox(height: 16),

                      // Password field
                      TextFormField(
                        controller: _passwordController,
                        enabled: !_loading,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'Enter your password',
                          prefixIcon: const Icon(Icons.lock_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Login button
                      ElevatedButton(
                        onPressed: _loading ? null : _login,
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : const Text('Login'),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Forgot password link
                    if (_emailChecked)
                      TextButton(
                        onPressed: () {
                          // TODO: Implement forgot password
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Forgot password feature coming soon'),
                            ),
                          );
                        },
                        child: const Text('Forgot Password?'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrganizationSelector() {
    final orgProvider = context.watch<OrganizationProvider>();
    final orgs = orgProvider.organizations;

    if (orgs.isEmpty) {
      return const SizedBox.shrink();
    }

    // If only one organization, show as read-only text field
    if (orgs.length == 1) {
      return TextFormField(
        initialValue: orgs.first.name,
        enabled: false,
        decoration: InputDecoration(
          labelText: 'Organization',
          prefixIcon: const Icon(Icons.business),
          suffixIcon: Icon(
            Icons.check_circle,
            color: AppTheme.successColor,
          ),
        ),
      );
    }

    // Multiple organizations - show dropdown
    return DropdownButtonFormField<OrganizationLiteModel>(
      initialValue: _selectedOrg,
      decoration: const InputDecoration(
        labelText: 'Organization',
        hintText: 'Select your organization',
        prefixIcon: Icon(Icons.business),
      ),
      items: orgs.map((org) {
        return DropdownMenuItem(
          value: org,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                org.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (org.address != null)
                Text(
                  org.address!,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.gray600,
                  ),
                ),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedOrg = value;
          _errorMessage = null;
        });
      },
      validator: (value) {
        if (value == null) {
          return 'Please select an organization';
        }
        return null;
      },
    );
  }
}