import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/auth_models.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../config/theme.dart';
import '../../dashboard/screens/provider_dashboard_screen.dart';

/// Shown after a successful login when the user belongs to more than one
/// facility, or when the app restores a session that has no stored tenant.
class FacilityPickerScreen extends StatefulWidget {
  const FacilityPickerScreen({super.key});

  @override
  State<FacilityPickerScreen> createState() => _FacilityPickerScreenState();
}

class _FacilityPickerScreenState extends State<FacilityPickerScreen> {
  String? _selectingId; // which tile is currently in-progress

  Future<void> _select(AuthFacilityModel facility) async {
    setState(() => _selectingId = facility.id);

    final authProvider = context.read<AuthProvider>();
    await authProvider.selectFacility(facility);

    if (!mounted) return;
    setState(() => _selectingId = null);

    if (authProvider.state == AuthState.authenticated) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ProviderDashboardScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Facility'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.logout, color: Colors.white),
            label: const Text('Logout', style: TextStyle(color: Colors.white)),
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
              }
            },
          ),
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          final facilities = auth.availableFacilities;
          final user = auth.currentUser;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Greeting ─────────────────────────────────────────────
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: AppTheme.primaryColor,
                          child: Text(
                            auth.initials,
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(auth.displayName,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(user?.email ?? '',
                            style:
                                TextStyle(fontSize: 14, color: AppTheme.gray600)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Text('Where are you working today?',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.gray600)),
                const SizedBox(height: 12),

                if (auth.error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(auth.error!,
                        style: TextStyle(color: AppTheme.errorColor)),
                  ),
                  const SizedBox(height: 12),
                ],

                // ── Facility list ─────────────────────────────────────────
                Expanded(
                  child: ListView.separated(
                    itemCount: facilities.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) =>
                        _FacilityTile(
                      facility: facilities[i],
                      isLoading: _selectingId == facilities[i].id,
                      onTap: _selectingId == null
                          ? () => _select(facilities[i])
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _FacilityTile extends StatelessWidget {
  final AuthFacilityModel facility;
  final bool isLoading;
  final VoidCallback? onTap;

  const _FacilityTile({
    required this.facility,
    required this.isLoading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final membership = facility.membership;

    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.local_hospital, color: AppTheme.primaryColor),
        ),
        title: Text(facility.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (facility.organization != null)
              Text(facility.organization!.name,
                  style: TextStyle(fontSize: 12, color: AppTheme.gray600)),
            if (membership != null)
              Text(membership.displayType,
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w500)),
          ],
        ),
        trailing: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
