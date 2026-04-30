import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/platform.dart';
import '../../../data/models/auth_models.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/organization_provider.dart';
import '../../../config/theme.dart';
import 'facility_picker_screen.dart';
import '../../dashboard/screens/provider_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _twoFactorController = TextEditingController();

  bool _loading = false;
  bool _emailChecked = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  AuthFacilityModel? _selectedFacility;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _twoFactorController.dispose();
    super.dispose();
  }

  // ── Step 1: check email ───────────────────────────────────────────────────

  Future<void> _checkEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showError('Please enter a valid email address.');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final orgProvider = context.read<OrganizationProvider>();
    final result = await orgProvider.checkEmail(email);

    if (!mounted) return;

    if (result == null || !result.exists) {
      setState(() {
        _loading = false;
        _errorMessage = 'No account found for this email address.';
      });
      return;
    }

    if (result.facilities.isEmpty) {
      setState(() {
        _loading = false;
        _errorMessage =
            'Your account has no active facility memberships. Contact your administrator.';
      });
      return;
    }

    final facilities = result.facilities;
    setState(() {
      _loading = false;
      _emailChecked = true;
      // Pre-select the only facility; multi-facility users must choose explicitly.
      _selectedFacility = facilities.length == 1 ? facilities.first : null;
    });
  }

  // ── Step 2: login with password ───────────────────────────────────────────

  Future<void> _login() async {
    final facilities = context.read<OrganizationProvider>().facilities;
    if (facilities.length > 1 && _selectedFacility == null) {
      _showError('Please select a facility to continue.');
      return;
    }
    if (_passwordController.text.isEmpty) {
      _showError('Please enter your password.');
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
    );

    if (!mounted) return;

    if (!success) {
      setState(() {
        _loading = false;
        _errorMessage =
            authProvider.error ?? 'Login failed. Please check your password.';
      });
      return;
    }

    setState(() => _loading = false);
    _navigateAfterAuth(authProvider);
  }

  // ── Step 3 (if 2FA): verify code ─────────────────────────────────────────

  Future<void> _verify2FA() async {
    final code = _twoFactorController.text.trim();
    if (code.isEmpty) {
      _showError('Please enter your authentication code.');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.verifyTwoFactor(code);

    if (!mounted) return;

    if (!success) {
      setState(() {
        _loading = false;
        _errorMessage = authProvider.error ?? 'Invalid code. Please try again.';
      });
      return;
    }

    setState(() => _loading = false);
    _navigateAfterAuth(authProvider);
  }

  void _navigateAfterAuth(AuthProvider authProvider) {
    if (authProvider.state == AuthState.awaitingFacility) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const FacilityPickerScreen()),
      );
    } else if (authProvider.state == AuthState.authenticated) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ProviderDashboardScreen()),
      );
    }
  }

  void _showError(String msg) => setState(() => _errorMessage = msg);

  void _resetToEmailStep() {
    setState(() {
      _emailChecked = false;
      _errorMessage = null;
      _selectedFacility = null;
      _passwordController.clear();
      _twoFactorController.clear();
    });
    context.read<OrganizationProvider>().clear();
    context.read<AuthProvider>().clearError();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final show2FA = authProvider.requiresTwoFactor;

        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Header ───────────────────────────────────────────
                      Icon(Icons.local_hospital,
                          size: 80, color: AppTheme.primaryColor),
                      const SizedBox(height: 16),
                      const Text('Healthcare EMR',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 28, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        show2FA
                            ? 'Two-Factor Authentication'
                            : 'Provider Login',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: AppTheme.gray600),
                      ),
                      const SizedBox(height: 48),

                      // ── Error banner ─────────────────────────────────────
                      if (_errorMessage != null) ...[
                        _ErrorBox(message: _errorMessage!),
                        const SizedBox(height: 16),
                      ],

                      if (show2FA)
                        _buildTwoFactorStep()
                      else
                        _buildPasswordStep(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Email + password form ─────────────────────────────────────────────────

  Widget _buildPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Email field
        TextFormField(
          controller: _emailController,
          enabled: !_emailChecked && !_loading,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Email',
            hintText: 'Enter your email',
            prefixIcon: const Icon(Icons.email_outlined),
            suffixIcon: _emailChecked
                ? IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: 'Change email',
                    onPressed: _resetToEmailStep,
                  )
                : null,
          ),
        ),

        // Facility selector shown after email check
        if (_emailChecked) ...[
          const SizedBox(height: 12),
          _FacilitySelector(
            facilities: context.watch<OrganizationProvider>().facilities,
            selected: _selectedFacility,
            onChanged: (f) => setState(() => _selectedFacility = f),
          ),
        ],

        const SizedBox(height: 16),

        if (!_emailChecked) ...[
          // ── Step 1 ────────────────────────────────────────────────────
          AdaptiveFilledButton(
            onPressed: _loading ? null : _checkEmail,
            child: _loading
                ? _LoadingSpinner()
                : const Text('Next'),
          ),
        ] else ...[
          // ── Step 2 ────────────────────────────────────────────────────
          TextFormField(
            controller: _passwordController,
            enabled: !_loading,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _login(),
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter your password',
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 24),
          AdaptiveFilledButton(
            onPressed: _loading ? null : _login,
            child: _loading ? _LoadingSpinner() : const Text('Login'),
          ),
          const SizedBox(height: 16),
          AdaptiveTextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Contact your administrator to reset your password.'),
              ));
            },
            child: const Text('Forgot Password?'),
          ),
        ],
      ],
    );
  }

  // ── 2FA form ──────────────────────────────────────────────────────────────

  Widget _buildTwoFactorStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: [
            Icon(Icons.security, color: AppTheme.primaryColor, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Enter the 6-digit code from your authenticator app, '
              'or one of your backup codes.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
          ]),
        ),
        const SizedBox(height: 24),
        TextFormField(
          controller: _twoFactorController,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          autofocus: true,
          onFieldSubmitted: (_) => _verify2FA(),
          decoration: const InputDecoration(
            labelText: 'Authentication Code',
            hintText: '000000 or XXXX-XXXX',
            prefixIcon: Icon(Icons.pin),
          ),
        ),
        const SizedBox(height: 24),
        AdaptiveFilledButton(
          onPressed: _loading ? null : _verify2FA,
          child: _loading ? _LoadingSpinner() : const Text('Verify'),
        ),
        const SizedBox(height: 16),
        AdaptiveTextButton(
          onPressed: _resetToEmailStep,
          child: const Text('Back to login'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _FacilitySelector extends StatelessWidget {
  final List<AuthFacilityModel> facilities;
  final AuthFacilityModel? selected;
  final ValueChanged<AuthFacilityModel?> onChanged;

  const _FacilitySelector({
    required this.facilities,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (facilities.isEmpty) return const SizedBox.shrink();

    if (facilities.length == 1) {
      // Single facility — display name only, no interaction needed
      final f = facilities.first;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.local_hospital_outlined,
                size: 18, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  if (f.organization != null)
                    Text(f.organization!.name,
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.gray600)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Multiple facilities — dropdown selector
    return DropdownButtonFormField<AuthFacilityModel>(
      value: selected,
      decoration: const InputDecoration(
        labelText: 'Select Facility',
        prefixIcon: Icon(Icons.local_hospital_outlined),
      ),
      hint: const Text('Choose your facility'),
      items: facilities.map((f) {
        return DropdownMenuItem(
          value: f,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(f.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 14)),
              if (f.organization != null)
                Text(f.organization!.name,
                    style: TextStyle(fontSize: 12, color: AppTheme.gray600)),
            ],
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppTheme.errorColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: TextStyle(color: AppTheme.errorColor, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

class _LoadingSpinner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 20,
      width: 20,
      child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(Colors.white)),
    );
  }
}
