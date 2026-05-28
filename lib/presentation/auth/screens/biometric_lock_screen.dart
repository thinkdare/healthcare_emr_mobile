// lib/presentation/auth/screens/biometric_lock_screen.dart
//
// Full-screen lock overlay shown when BiometricProvider.isLocked is true.
// Triggers the native biometric/passcode prompt automatically on mount.
// Offers "Sign out" if the user cannot authenticate.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/app_colors.dart';
import '../../../core/biometric/biometric_provider.dart';
import '../../../core/platform.dart';
import '../../../data/providers/auth_provider.dart';
import 'login_screen.dart';

class BiometricLockScreen extends StatefulWidget {
  const BiometricLockScreen({super.key});

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> {
  bool _authenticating = false;
  bool _failed = false;
  String _biometricLabel = 'Biometrics';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final svc = context.read<BiometricProvider>().service;
      _biometricLabel = await svc.biometricLabel();
      if (mounted) setState(() {});
      _authenticate();
    });
  }

  Future<void> _authenticate() async {
    if (_authenticating) return;
    setState(() {
      _authenticating = true;
      _failed = false;
    });

    final svc = context.read<BiometricProvider>().service;
    final ok  = await svc.authenticate(
      reason: 'Unlock Voya to access patient records',
    );

    if (!mounted) return;
    setState(() => _authenticating = false);

    if (ok) {
      context.read<BiometricProvider>().unlock();
    } else {
      setState(() => _failed = true);
    }
  }

  Future<void> _signOut() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    context.read<BiometricProvider>().unlock();
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      kIsIOS
          ? CupertinoPageRoute(builder: (_) => const LoginScreen())
          : MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();

    return PopScope(
      canPop: false, // cannot dismiss by back gesture
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // App icon / logo area
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.health_and_safety,
                        size: 48, color: Colors.white),
                  ),
                  const SizedBox(height: 24),

                  const Text('Voya',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
                  const SizedBox(height: 8),

                  Text(
                    'Welcome back, ${auth.displayName}',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 15),
                  ),
                  const SizedBox(height: 48),

                  // Biometric icon button
                  GestureDetector(
                    onTap: _authenticating ? null : _authenticate,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _authenticating
                          ? Padding(
                              padding: const EdgeInsets.all(20),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.primary),
                            )
                          : Icon(
                              _biometricIcon(),
                              size: 36,
                              color: _failed
                                  ? Colors.red
                                  : AppColors.primary,
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    _authenticating
                        ? 'Verifying…'
                        : _failed
                            ? 'Authentication failed. Try again.'
                            : 'Tap to unlock with $_biometricLabel',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Sign out fallback
                  TextButton(
                    onPressed: _signOut,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white.withValues(alpha: 0.7),
                    ),
                    child: const Text('Sign out instead'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _biometricIcon() {
    if (_biometricLabel == 'Face ID') return Icons.face_outlined;
    if (_biometricLabel == 'Fingerprint') return Icons.fingerprint;
    return Icons.lock_open_outlined;
  }
}
