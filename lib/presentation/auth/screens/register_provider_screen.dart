import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/platform.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/repositories/staff_repository.dart';
import 'facility_picker_screen.dart';
import '../../dashboard/screens/provider_dashboard_screen.dart';

/// Two-step provider registration via staff invitation token.
///
/// Step 1 — Token entry: user pastes or types the invitation token and we
///           validate it against GET /staff/invitation to surface the
///           facility name, role, and inviter so they know what they're
///           signing up for before committing credentials.
///
/// Step 2 — Account setup: first name, last name, password. On success the
///           API returns a full auth token which is stored via AuthProvider
///           and the user is routed into the app.
class RegisterProviderScreen extends StatefulWidget {
  /// Pre-filled token from a deep link (voya://staff/register?token=…).
  final String? initialToken;

  const RegisterProviderScreen({super.key, this.initialToken});

  @override
  State<RegisterProviderScreen> createState() => _RegisterProviderScreenState();
}

class _RegisterProviderScreenState extends State<RegisterProviderScreen> {
  // ── Form controllers ────────────────────────────────────────────────────────

  final _tokenCtrl      = TextEditingController();
  final _firstNameCtrl  = TextEditingController();
  final _lastNameCtrl   = TextEditingController();
  final _passwordCtrl   = TextEditingController();
  final _confirmCtrl    = TextEditingController();

  final _tokenFormKey   = GlobalKey<FormState>();
  final _accountFormKey = GlobalKey<FormState>();

  // ── State ───────────────────────────────────────────────────────────────────

  _Step _step = _Step.token;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm  = true;
  String? _error;

  InvitationDetails? _invitation;

  late final StaffRepository _staffRepo;

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _staffRepo = StaffRepository(apiClient: context.read<ApiClient>());

    if (widget.initialToken != null) {
      _tokenCtrl.text = widget.initialToken!;
      // Auto-validate on the next frame so the field is rendered first
      WidgetsBinding.instance.addPostFrameCallback((_) => _validateToken());
    }
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _validateToken() async {
    if (!_tokenFormKey.currentState!.validate()) return;

    setState(() { _loading = true; _error = null; });

    try {
      final details = await _staffRepo.validateInvitation(
        _tokenCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _invitation = details;
        _step       = _Step.account;
        _loading    = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error   = _friendlyError(e.toString());
      });
    }
  }

  Future<void> _register() async {
    if (!_accountFormKey.currentState!.validate()) return;

    setState(() { _loading = true; _error = null; });

    // Capture before async gap
    final apiClient = context.read<ApiClient>();
    final authProv  = context.read<AuthProvider>();

    try {
      final token = await _staffRepo.registerViaInvitation(
        token:     _invitation!.token.isNotEmpty
            ? _invitation!.token
            : _tokenCtrl.text.trim(),
        firstName: _firstNameCtrl.text.trim(),
        lastName:  _lastNameCtrl.text.trim(),
        password:  _passwordCtrl.text,
      );

      await apiClient.saveToken(token);
      if (!mounted) return;
      await authProv.initialize();
      if (!mounted) return;

      setState(() => _loading = false);
      _navigateAfterRegistration();
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error   = _friendlyError(e.toString());
      });
    }
  }

  void _navigateAfterRegistration() {
    final auth = context.read<AuthProvider>();
    if (auth.needsFacilitySelection) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const FacilityPickerScreen()),
      );
    } else if (auth.isAuthenticated) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ProviderDashboardScreen()),
      );
    }
  }

  void _backToTokenStep() {
    setState(() {
      _step       = _Step.token;
      _invitation = null;
      _error      = null;
      _firstNameCtrl.clear();
      _lastNameCtrl.clear();
      _passwordCtrl.clear();
      _confirmCtrl.clear();
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Icon(Icons.local_hospital,
                      size: 72, color: AppTheme.primaryColor),
                  const SizedBox(height: 16),
                  const Text(
                    'Healthcare EMR',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _step == _Step.token
                        ? 'Accept your invitation'
                        : 'Create your account',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: AppTheme.gray600),
                  ),
                  const SizedBox(height: 36),

                  // Error banner
                  if (_error != null) ...[
                    _ErrorBanner(message: _error!),
                    const SizedBox(height: 16),
                  ],

                  if (_step == _Step.token)
                    _buildTokenStep()
                  else
                    _buildAccountStep(),

                  const SizedBox(height: 20),

                  // Back to login link
                  AdaptiveTextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back to login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Step 1: token ─────────────────────────────────────────────────────────

  Widget _buildTokenStep() {
    return Form(
      key: _tokenFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              Icon(Icons.mail_outline,
                  color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Paste the invitation token from your email to get started.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          TextFormField(
            controller: _tokenCtrl,
            enabled: !_loading,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _validateToken(),
            decoration: const InputDecoration(
              labelText: 'Invitation token *',
              hintText: 'Paste your token here',
              prefixIcon: Icon(Icons.vpn_key_outlined),
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Invitation token is required'
                : null,
          ),
          const SizedBox(height: 24),

          AdaptiveFilledButton(
            onPressed: _loading ? null : _validateToken,
            child: _loading
                ? _Spinner()
                : const Text('Verify invitation'),
          ),
        ],
      ),
    );
  }

  // ── Step 2: account setup ──────────────────────────────────────────────────

  Widget _buildAccountStep() {
    final inv = _invitation!;
    return Form(
      key: _accountFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Invitation summary card
          _InvitationCard(
            facilityName: inv.facilityName,
            staffType:    inv.staffTypeLabel,
            email:        inv.email,
            inviterName:  inv.inviterName,
            onChangeToken: _backToTokenStep,
          ),
          const SizedBox(height: 20),

          // Name row
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _firstNameCtrl,
                enabled: !_loading,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'First name *'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Required'
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _lastNameCtrl,
                enabled: !_loading,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Last name *'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Required'
                    : null,
              ),
            ),
          ]),
          const SizedBox(height: 16),

          // Password
          TextFormField(
            controller: _passwordCtrl,
            enabled: !_loading,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Password *',
              hintText: 'At least 8 characters',
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              if (v.length < 8) return 'Must be at least 8 characters';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Confirm password
          TextFormField(
            controller: _confirmCtrl,
            enabled: !_loading,
            obscureText: _obscureConfirm,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _register(),
            decoration: InputDecoration(
              labelText: 'Confirm password *',
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            validator: (v) {
              if (v != _passwordCtrl.text) return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: 28),

          AdaptiveFilledButton(
            onPressed: _loading ? null : _register,
            child: _loading
                ? _Spinner()
                : const Text('Create account'),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _friendlyError(String raw) {
    if (raw.contains('expired')) return 'This invitation has expired. Ask your administrator for a new one.';
    if (raw.contains('used') || raw.contains('already')) return 'This invitation has already been used.';
    if (raw.contains('not found') || raw.contains('invalid') || raw.contains('Invalid')) {
      return 'Invitation not found. Check that you copied the full token.';
    }
    if (raw.contains('SocketException') || raw.contains('Connection')) {
      return 'Cannot reach the server. Check your connection.';
    }
    if (raw.contains('422') || raw.contains('password')) {
      return 'Please check your details and try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}

// ── Step enum ────────────────────────────────────────────────────────────────

enum _Step { token, account }

// ── Invitation summary card ──────────────────────────────────────────────────

class _InvitationCard extends StatelessWidget {
  final String facilityName;
  final String staffType;
  final String email;
  final String? inviterName;
  final VoidCallback onChangeToken;

  const _InvitationCard({
    required this.facilityName,
    required this.staffType,
    required this.email,
    this.inviterName,
    required this.onChangeToken,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.successColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: AppTheme.successColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.check_circle, color: AppTheme.successColor, size: 18),
            const SizedBox(width: 8),
            const Text('Invitation verified',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.successColor,
                    fontSize: 13)),
            const Spacer(),
            GestureDetector(
              onTap: onChangeToken,
              child: Text('Change',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.primaryColor,
                      decoration: TextDecoration.underline)),
            ),
          ]),
          const SizedBox(height: 10),
          _Row(icon: Icons.local_hospital_outlined, text: facilityName),
          _Row(icon: Icons.badge_outlined, text: staffType),
          _Row(icon: Icons.email_outlined, text: email),
          if (inviterName != null && inviterName!.isNotEmpty)
            _Row(icon: Icons.person_outline, text: 'Invited by $inviterName'),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Row({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(children: [
        Icon(icon, size: 15, color: AppTheme.gray600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }
}

// ── Error banner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(Icons.error_outline, color: AppTheme.errorColor, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message,
              style: TextStyle(color: AppTheme.errorColor, fontSize: 13)),
        ),
      ]),
    );
  }
}

// ── Loading spinner ──────────────────────────────────────────────────────────

class _Spinner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 20, width: 20,
      child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(Colors.white)),
    );
  }
}
