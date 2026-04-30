import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/platform.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../config/theme.dart';
import '../../../data/providers/auth_provider.dart';

class StaffProfileScreen extends StatefulWidget {
  const StaffProfileScreen({super.key});

  @override
  State<StaffProfileScreen> createState() => _StaffProfileScreenState();
}

class _StaffProfileScreenState extends State<StaffProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: kIsIOS
          ? const CupertinoNavigationBar(
              middle: Text('My Profile'),
            )
          : AppBar(
              title: const Text('My Profile'),
              bottom: TabBar(
                controller: _tabs,
                tabs: const [
                  Tab(text: 'Profile'),
                  Tab(text: 'Security'),
                  Tab(text: '2FA'),
                ],
              ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _ProfileTab(),
          _SecurityTab(),
          _TwoFactorTab(),
        ],
      ),
    );
  }
}

// ── Profile Tab ───────────────────────────────────────────────────────────────

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final user = auth.currentUser;
        final membership = auth.activeMembership;
        final rank = membership?.clinicalRank;
        final facility = auth.activeFacility;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Avatar
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    auth.initials,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                auth.displayName,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold),
              ),
              if (user != null) ...[
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: const TextStyle(
                      color: AppTheme.gray600, fontSize: 14),
                ),
              ],
              const SizedBox(height: 24),

              // Account info
              _SectionCard(
                title: 'Account',
                icon: Icons.person_outline,
                children: [
                  _InfoRow('Name', auth.displayName),
                  if (user != null) ...[
                    _InfoRow('Email', user.email),
                    _InfoRow('Account type',
                        _userTypeLabel(user.userType)),
                    _InfoRow(
                      '2FA',
                      user.twoFactorEnabled ? 'Enabled' : 'Disabled',
                      valueColor: user.twoFactorEnabled
                          ? AppTheme.successColor
                          : AppTheme.gray600,
                    ),
                  ],
                ],
              ),

              // Membership info
              if (membership != null)
                _SectionCard(
                  title: 'Staff Membership',
                  icon: Icons.badge_outlined,
                  children: [
                    _InfoRow('Role', membership.displayType),
                    if (membership.department != null)
                      _InfoRow('Department', membership.department!),
                    _InfoRow(
                        'Primary affiliation',
                        membership.isPrimary ? 'Yes' : 'No'),
                    if (rank != null) ...[
                      _InfoRow('Clinical rank', rank.name),
                      _InfoRow('Hierarchy level',
                          rank.hierarchyLevel.toString()),
                    ],
                  ],
                ),

              // Capabilities
              if (rank != null)
                _SectionCard(
                  title: 'Clinical Capabilities',
                  icon: Icons.medical_services_outlined,
                  children: [
                    _CapRow('Prescribe medications', rank.canPrescribe),
                    _CapRow('Order lab tests', rank.canOrderLabs),
                    _CapRow('Approve access grants',
                        rank.canApproveAccessGrants),
                    _CapRow('Emergency (break-glass) access',
                        rank.canPerformEmergencyAccess),
                  ],
                ),

              // Active facility
              if (facility != null)
                _SectionCard(
                  title: 'Active Facility',
                  icon: Icons.business_outlined,
                  children: [
                    _InfoRow('Name', facility.name),
                    if (facility.organization != null)
                      _InfoRow(
                          'Organisation', facility.organization!.name),
                    _InfoRow('Type', facility.displayType),
                    if (facility.address != null)
                      _InfoRow('Address', facility.address!),
                    if (facility.phone != null)
                      _InfoRow('Phone', facility.phone!),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  String _userTypeLabel(String t) => switch (t) {
        'super_admin' => 'Super Administrator',
        'org_admin' => 'Organisation Administrator',
        _ => 'Clinical Staff',
      };
}

// ── Security Tab ──────────────────────────────────────────────────────────────

class _SecurityTab extends StatefulWidget {
  const _SecurityTab();

  @override
  State<_SecurityTab> createState() => _SecurityTabState();
}

class _SecurityTabState extends State<_SecurityTab> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _saving = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final ok = await context.read<AuthProvider>().changePassword(
          currentPassword: _currentCtrl.text,
          newPassword: _newCtrl.text,
        );

    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      _currentCtrl.clear();
      _newCtrl.clear();
      _confirmCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Password changed successfully.'),
        backgroundColor: AppTheme.successColor,
      ));
    } else {
      final err = context.read<AuthProvider>().error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err ?? 'Failed to change password.'),
        backgroundColor: AppTheme.errorColor,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _SectionCard(
            title: 'Change Password',
            icon: Icons.lock_outline,
            children: [
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _currentCtrl,
                      obscureText: _obscureCurrent,
                      decoration: InputDecoration(
                        labelText: 'Current password',
                        suffixIcon: IconButton(
                          icon: Icon(_obscureCurrent
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () => setState(
                              () => _obscureCurrent = !_obscureCurrent),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Required'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _newCtrl,
                      obscureText: _obscureNew,
                      decoration: InputDecoration(
                        labelText: 'New password',
                        suffixIcon: IconButton(
                          icon: Icon(_obscureNew
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setState(() => _obscureNew = !_obscureNew),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (v.length < 8) {
                          return 'Must be at least 8 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmCtrl,
                      obscureText: _obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirm new password',
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirm
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                      validator: (v) {
                        if (v != _newCtrl.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: AdaptiveFilledButton(
                        onPressed: _saving ? null : _submit,
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                      Colors.white),
                                ),
                              )
                            : const Text('Update Password'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          _SectionCard(
            title: 'Active Sessions',
            icon: Icons.devices_outlined,
            children: [
              const Text(
                'You are currently signed in on this device.',
                style: TextStyle(color: AppTheme.gray600, fontSize: 13),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Sign out of this device'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorColor,
                    side: const BorderSide(color: AppTheme.errorColor),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 2FA Tab ───────────────────────────────────────────────────────────────────

class _TwoFactorTab extends StatefulWidget {
  const _TwoFactorTab();

  @override
  State<_TwoFactorTab> createState() => _TwoFactorTabState();
}

class _TwoFactorTabState extends State<_TwoFactorTab> {
  bool _loading = false;

  // Setup flow state
  Map<String, dynamic>? _setupData; // secret + qr_code_url
  final _codeCtrl = TextEditingController();
  List<String>? _backupCodes; // shown after enabling
  int? _backupCodeCount;

  @override
  void initState() {
    super.initState();
    _loadBackupCodeCount();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBackupCodeCount() async {
    final auth = context.read<AuthProvider>();
    if (auth.currentUser?.twoFactorEnabled == true) {
      final count = await auth.twoFactorBackupCodeCount();
      if (mounted) setState(() => _backupCodeCount = count);
    }
  }

  Future<void> _startSetup() async {
    setState(() => _loading = true);
    final data =
        await context.read<AuthProvider>().twoFactorSetup();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _setupData = data;
    });
    if (data == null) {
      final err = context.read<AuthProvider>().error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err ?? 'Failed to start 2FA setup'),
        backgroundColor: AppTheme.errorColor,
      ));
    }
  }

  Future<void> _enable() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Enter the 6-digit code from your authenticator app'),
        backgroundColor: AppTheme.warningColor,
      ));
      return;
    }

    setState(() => _loading = true);
    final codes =
        await context.read<AuthProvider>().twoFactorEnable(code);
    if (!mounted) return;

    setState(() {
      _loading = false;
      _setupData = null;
      _codeCtrl.clear();
    });

    if (codes != null) {
      setState(() => _backupCodes = codes);
    } else {
      final err = context.read<AuthProvider>().error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err ?? 'Invalid code. Try again.'),
        backgroundColor: AppTheme.errorColor,
      ));
    }
  }

  Future<void> _showDisableDialog() async {
    final pwCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disable 2FA'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Disabling two-factor authentication makes your account less secure.',
              style: TextStyle(color: AppTheme.gray600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pwCtrl,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: 'Confirm your password'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor),
            child: const Text('Disable'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);
    final ok = await context
        .read<AuthProvider>()
        .twoFactorDisable(pwCtrl.text);
    pwCtrl.dispose();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _backupCodeCount = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          ok ? '2FA disabled.' : context.read<AuthProvider>().error ?? 'Failed'),
      backgroundColor: ok ? AppTheme.gray600 : AppTheme.errorColor,
    ));
  }

  Future<void> _regenerateBackupCodes() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Regenerate Backup Codes'),
        content: const Text(
          'Your old backup codes will be invalidated immediately. '
          'Save the new codes somewhere safe.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);
    final codes = await context
        .read<AuthProvider>()
        .twoFactorRegenerateBackupCodes();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (codes != null) _backupCodes = codes;
    });

    if (codes == null) {
      final err = context.read<AuthProvider>().error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err ?? 'Failed to regenerate codes'),
        backgroundColor: AppTheme.errorColor,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final isEnabled = auth.currentUser?.twoFactorEnabled ?? false;

        // Show backup codes after enabling
        if (_backupCodes != null) {
          return _BackupCodesView(
            codes: _backupCodes!,
            onDone: () => setState(() {
              _backupCodes = null;
              _loadBackupCodeCount();
            }),
          );
        }

        // Show setup flow
        if (_setupData != null) {
          return _SetupFlow(
            setupData: _setupData!,
            codeCtrl: _codeCtrl,
            loading: _loading,
            onEnable: _enable,
            onCancel: () => setState(() {
              _setupData = null;
              _codeCtrl.clear();
            }),
          );
        }

        // Main 2FA status view
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Status card
              _SectionCard(
                title: 'Two-Factor Authentication',
                icon: Icons.security_outlined,
                children: [
                  Row(
                    children: [
                      Icon(
                        isEnabled
                            ? Icons.verified_user
                            : Icons.gpp_bad_outlined,
                        color: isEnabled
                            ? AppTheme.successColor
                            : AppTheme.warningColor,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEnabled ? '2FA is enabled' : '2FA is disabled',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isEnabled
                                    ? AppTheme.successColor
                                    : AppTheme.warningColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isEnabled
                                  ? 'Your account is protected with TOTP authentication.'
                                  : 'Add an extra layer of security to your account.',
                              style: const TextStyle(
                                  fontSize: 12, color: AppTheme.gray600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: isEnabled
                        ? OutlinedButton.icon(
                            icon: const Icon(Icons.no_encryption_outlined,
                                size: 18),
                            label: const Text('Disable 2FA'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.errorColor,
                              side: const BorderSide(
                                  color: AppTheme.errorColor),
                            ),
                            onPressed: _loading ? null : _showDisableDialog,
                          )
                        : AdaptiveFilledButton(
                            icon: const Icon(Icons.security, size: 18),
                            onPressed: _loading ? null : _startSetup,
                            child: const Text('Set up 2FA'),
                          ),
                  ),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),

              // Backup codes section (only when 2FA is on)
              if (isEnabled)
                _SectionCard(
                  title: 'Backup Codes',
                  icon: Icons.key_outlined,
                  children: [
                    if (_backupCodeCount != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(children: [
                          Icon(
                            _backupCodeCount! > 2
                                ? Icons.check_circle_outline
                                : Icons.warning_amber_outlined,
                            size: 18,
                            color: _backupCodeCount! > 2
                                ? AppTheme.successColor
                                : AppTheme.warningColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$_backupCodeCount backup code${_backupCodeCount == 1 ? '' : 's'} remaining',
                            style: TextStyle(
                              fontSize: 13,
                              color: _backupCodeCount! > 2
                                  ? AppTheme.successColor
                                  : AppTheme.warningColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ]),
                      ),
                    const Text(
                      'Backup codes let you sign in if you lose access to '
                      'your authenticator app. Each code can only be used once.',
                      style:
                          TextStyle(fontSize: 12, color: AppTheme.gray600),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Regenerate backup codes'),
                        onPressed:
                            _loading ? null : _regenerateBackupCodes,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── 2FA Setup Flow ────────────────────────────────────────────────────────────

class _SetupFlow extends StatelessWidget {
  final Map<String, dynamic> setupData;
  final TextEditingController codeCtrl;
  final bool loading;
  final VoidCallback onEnable;
  final VoidCallback onCancel;

  const _SetupFlow({
    required this.setupData,
    required this.codeCtrl,
    required this.loading,
    required this.onEnable,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final secret = setupData['secret'] as String? ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Step 1',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 4),
          const Text(
            'Open your authenticator app (e.g. Google Authenticator, '
            'Authy) and add a new account.',
            style: TextStyle(color: AppTheme.gray600, fontSize: 13),
          ),
          const SizedBox(height: 20),
          const Text(
            'Step 2 — Enter this secret key manually',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.gray100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.gray600.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    secret,
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  tooltip: 'Copy secret',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: secret));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Secret copied to clipboard')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Step 3 — Verify',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: codeCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: '6-digit code from your app',
              counterText: '',
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: loading ? null : onCancel,
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AdaptiveFilledButton(
                  onPressed: loading ? null : onEnable,
                  child: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation(Colors.white)),
                        )
                      : const Text('Enable 2FA'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Backup Codes View ─────────────────────────────────────────────────────────

class _BackupCodesView extends StatelessWidget {
  final List<String> codes;
  final VoidCallback onDone;

  const _BackupCodesView({required this.codes, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.successColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppTheme.successColor.withValues(alpha: 0.3)),
            ),
            child: const Row(children: [
              Icon(Icons.check_circle, color: AppTheme.successColor),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '2FA is now enabled. Save these backup codes somewhere safe — '
                  'each can only be used once.',
                  style: TextStyle(
                      color: AppTheme.successColor, fontSize: 13),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.builder(
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 3.5,
              ),
              itemCount: codes.length,
              itemBuilder: (_, i) => Container(
                decoration: BoxDecoration(
                  color: AppTheme.gray100,
                  borderRadius: BorderRadius.circular(6),
                  border:
                      Border.all(color: AppTheme.gray600.withValues(alpha: 0.2)),
                ),
                child: Center(
                  child: Text(
                    codes[i],
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy all'),
                  onPressed: () {
                    Clipboard.setData(
                        ClipboardData(text: codes.join('\n')));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Backup codes copied to clipboard')),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AdaptiveFilledButton(
                  onPressed: onDone,
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ]),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                  color: AppTheme.gray600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _CapRow extends StatelessWidget {
  final String label;
  final bool capable;

  const _CapRow(this.label, this.capable);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            capable ? Icons.check_circle : Icons.cancel_outlined,
            size: 18,
            color: capable ? AppTheme.successColor : AppTheme.gray600,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: capable ? null : AppTheme.gray600,
            ),
          ),
        ],
      ),
    );
  }
}
