import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/platform.dart';
import '../../../config/theme.dart';
import '../../../data/models/auth_models.dart';
import '../../../data/providers/auth_provider.dart';
import '../../dashboard/screens/provider_dashboard_screen.dart';
import 'facility_picker_screen.dart';

/// Accepts a staff invitation and creates the account.
///
/// There is no deep-link handling in this app (no app_links/uni_links
/// package wired up), so the invitation email's link can't open this screen
/// directly — the staff member copies the token (or the whole link, from
/// which the token is extracted) from the email and pastes it here. Once
/// resolved, GET /staff/invitation pre-fills the facility/role, matching
/// what the token proves, then POST /staff/register creates the account.
class AcceptInvitationScreen extends StatefulWidget {
  const AcceptInvitationScreen({super.key});

  @override
  State<AcceptInvitationScreen> createState() =>
      _AcceptInvitationScreenState();
}

class _AcceptInvitationScreenState extends State<AcceptInvitationScreen> {
  final _tokenController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _licenseController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  InvitationPreviewModel? _invitation;
  bool _loading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _tokenController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _licenseController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  /// Accepts either a bare 64-char token or the full email link
  /// (".../register?token=XXXX") and extracts the token either way.
  String _extractToken(String input) {
    final trimmed = input.trim();
    final uri = Uri.tryParse(trimmed);
    final fromQuery = uri?.queryParameters['token'];
    return (fromQuery != null && fromQuery.isNotEmpty) ? fromQuery : trimmed;
  }

  Future<void> _lookUpInvitation() async {
    final token = _extractToken(_tokenController.text);
    if (token.isEmpty) {
      setState(() => _errorMessage = 'Paste your invitation link or token.');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final auth = context.read<AuthProvider>();
    final invitation = await auth.loadInvitation(token);

    if (!mounted) return;
    setState(() => _loading = false);

    if (invitation == null) {
      setState(() => _errorMessage =
          auth.error ?? 'Invitation not found or has expired.');
      return;
    }

    if (invitation.isExpired) {
      setState(() => _errorMessage =
          'This invitation expired. Ask your administrator to send a new one.');
      return;
    }

    setState(() {
      _invitation = invitation;
      _firstNameController.text = invitation.firstName ?? '';
      _lastNameController.text = invitation.lastName ?? '';
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_invitation == null) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final auth = context.read<AuthProvider>();
    final success = await auth.acceptInvitation(
      token: _extractToken(_tokenController.text),
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      password: _passwordController.text,
      passwordConfirmation: _confirmController.text,
      phone: _phoneController.text.trim(),
      licenseNumber: _licenseController.text.trim(),
    );

    if (!mounted) return;

    if (!success) {
      setState(() {
        _loading = false;
        _errorMessage = auth.error ?? 'Registration failed.';
      });
      return;
    }

    setState(() => _loading = false);

    final target = auth.state == AuthState.awaitingFacility
        ? const FacilityPickerScreen()
        : const ProviderDashboardScreen();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => target),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: kIsIOS
          ? const CupertinoNavigationBar(middle: Text('Accept Invitation'))
          : AppBar(title: const Text('Accept Invitation')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(children: [
                          Icon(Icons.error_outline, color: AppTheme.errorColor, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_errorMessage!,
                                style: TextStyle(color: AppTheme.errorColor)),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_invitation == null) ..._buildTokenStep() else ..._buildRegistrationStep(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTokenStep() {
    return [
      Icon(Icons.mail_outline, size: 48, color: AppTheme.primaryColor),
      const SizedBox(height: 12),
      const Text(
        'Paste the invitation link (or just the token) from your email.',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      TextFormField(
        controller: _tokenController,
        enabled: !_loading,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Invitation link or token',
          hintText: 'https://.../register?token=… or the token itself',
          prefixIcon: Icon(Icons.link),
        ),
      ),
      const SizedBox(height: 24),
      AdaptiveFilledButton(
        onPressed: _loading ? null : _lookUpInvitation,
        child: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Continue'),
      ),
    ];
  }

  List<Widget> _buildRegistrationStep() {
    final invitation = _invitation!;
    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(invitation.facilityName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(invitation.email, style: TextStyle(color: AppTheme.gray600)),
            if (invitation.staffType != null) ...[
              const SizedBox(height: 4),
              Text(
                [
                  invitation.staffType!.replaceAll('_', ' '),
                  if (invitation.clinicalRankName != null) invitation.clinicalRankName,
                  if (invitation.department != null && invitation.department!.isNotEmpty)
                    invitation.department,
                ].whereType<String>().join(' · '),
                style: TextStyle(color: AppTheme.gray600, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(
          child: TextFormField(
            controller: _firstNameController,
            enabled: !_loading,
            decoration: const InputDecoration(labelText: 'First name *'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: _lastNameController,
            enabled: !_loading,
            decoration: const InputDecoration(labelText: 'Last name *'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
        ),
      ]),
      const SizedBox(height: 16),
      TextFormField(
        controller: _phoneController,
        enabled: !_loading,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(labelText: 'Phone (optional)'),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _licenseController,
        enabled: !_loading,
        decoration: const InputDecoration(labelText: 'License number (optional)'),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _passwordController,
        enabled: !_loading,
        obscureText: _obscurePassword,
        decoration: InputDecoration(
          labelText: 'Password',
          helperText: 'At least 12 characters, with upper/lowercase, a number, and a symbol.',
          helperMaxLines: 2,
          suffixIcon: IconButton(
            icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        validator: (v) {
          if (v == null || v.length < 12) return 'Must be at least 12 characters';
          final strong = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])');
          if (!strong.hasMatch(v)) {
            return 'Needs uppercase, lowercase, a number, and a symbol (@\$!%*?&)';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _confirmController,
        enabled: !_loading,
        obscureText: _obscurePassword,
        decoration: const InputDecoration(labelText: 'Confirm password'),
        validator: (v) =>
            v != _passwordController.text ? 'Passwords do not match' : null,
      ),
      const SizedBox(height: 24),
      AdaptiveFilledButton(
        onPressed: _loading ? null : _submit,
        child: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Create Account'),
      ),
      const SizedBox(height: 12),
      AdaptiveTextButton(
        onPressed: _loading
            ? null
            : () => setState(() {
                  _invitation = null;
                  _errorMessage = null;
                }),
        child: const Text('Use a different invitation'),
      ),
    ];
  }
}
