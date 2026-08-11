// lib/presentation/shell/app_lock_gate.dart
//
// Biometric app-lock: gates the app behind Face ID/fingerprint (falling
// back to device passcode) whenever there's an authenticated session to
// protect — on cold start and every resume-from-background. Devices with
// no biometrics enrolled and no passcode set are NOT locked out — there's
// nothing to authenticate against, so gating would just be a permanent
// lockout with no way to unlock.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../../config/app_colors.dart';
import '../../config/theme.dart';
import '../../core/platform.dart';
import '../../data/providers/auth_provider.dart';

class AppLockGate extends StatefulWidget {
  final Widget child;
  const AppLockGate({super.key, required this.child});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  final _localAuth = LocalAuthentication();
  bool _locked = false;
  bool _checking = false;
  bool _armed = false; // becomes true once we've seen an authenticated session

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLockOnLaunch());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool get _hasProtectableSession {
    if (!mounted) return false;
    final auth = context.read<AuthProvider>();
    return auth.isAuthenticated || auth.needsFacilitySelection;
  }

  Future<void> _maybeLockOnLaunch() async {
    // Cold start with an already-restored session (token survived app
    // relaunch) — gate immediately, same as any other resume.
    if (_hasProtectableSession) {
      setState(() {
        _locked = true;
        _armed = true;
      });
      await _attemptUnlock();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_hasProtectableSession) return;
    _armed = true;

    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      setState(() => _locked = true);
    } else if (state == AppLifecycleState.resumed && _locked) {
      _attemptUnlock();
    }
  }

  Future<void> _attemptUnlock() async {
    if (_checking) return;
    _checking = true;
    try {
      final canAuthenticate = await _localAuth.isDeviceSupported();
      if (!canAuthenticate) {
        // No biometrics and no device passcode configured — nothing to
        // gate against. Don't lock the user out with no way back in.
        if (mounted) setState(() => _locked = false);
        return;
      }

      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Unlock Voya to continue',
        biometricOnly: false, // allow device passcode/PIN fallback
      );
      if (didAuthenticate && mounted) {
        setState(() => _locked = false);
      }
    } catch (_) {
      // Platform exception (e.g. too many attempts, hardware unavailable) —
      // stay locked; the retry button lets the user try again.
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_armed) {
      // Haven't yet established whether there's a session to protect —
      // render the app underneath as normal (covers first-ever launch
      // before AuthProvider.initialize() resolves).
      return widget.child;
    }

    return Stack(
      children: [
        widget.child,
        if (_locked) _LockScreen(checking: _checking, onUnlock: _attemptUnlock),
      ],
    );
  }
}

class _LockScreen extends StatelessWidget {
  final bool checking;
  final VoidCallback onUnlock;
  const _LockScreen({required this.checking, required this.onUnlock});

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          kIsIOS ? CupertinoIcons.lock_shield : Icons.lock_outline,
          size: 64,
          color: kIsIOS ? AppColors.primary : AppTheme.primaryColor,
        ),
        const SizedBox(height: 24),
        const Text('Voya is locked',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Unlock to view patient data',
            style: TextStyle(fontSize: 14, color: CupertinoColors.systemGrey)),
        const SizedBox(height: 32),
        if (checking)
          const CircularProgressIndicator()
        else
          AdaptiveFilledButton(onPressed: onUnlock, child: const Text('Unlock')),
      ],
    );

    // Opaque full-screen cover — this sits above the entire app (patient
    // lists, clinical detail, everything) until unlocked, so it must fully
    // obscure content, not just dim it.
    return Positioned.fill(
      child: Container(
        color: kIsIOS
            ? CupertinoColors.systemBackground
            : Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(child: Center(child: content)),
      ),
    );
  }
}
