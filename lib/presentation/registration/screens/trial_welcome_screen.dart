import 'package:flutter/material.dart';
import '../../../core/platform.dart';
import '../../../config/app_colors.dart';

/// Placeholder — organization registration happens via the web portal.
class TrialWelcomeScreen extends StatelessWidget {
  const TrialWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.celebration,
                size: 80,
                color: AppColors.of(context).accent,
              ),
              const SizedBox(height: 24),
              const Text(
                'Your organization has been registered!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Please check your email for setup instructions.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.of(context).textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              AdaptiveFilledButton(
                onPressed: () => Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/', (_) => false),
                child: const Text('Go to Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
