import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/platform.dart';
import '../../../data/models/auth_models.dart';
import '../../../data/providers/auth_provider.dart';
import '../../dashboard/screens/provider_dashboard_screen.dart';
import '../../shell/ios_shell.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_spacing.dart';
import '../../shared/widgets/adaptive_card.dart';
import '../../shared/widgets/adaptive_list_row.dart';

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
        kIsIOS
            ? CupertinoPageRoute(builder: (_) => const IOSShell())
            : MaterialPageRoute(
                builder: (_) => const ProviderDashboardScreen(),
              ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: kIsIOS
          ? CupertinoNavigationBar(
              middle: const Text('Select Facility'),
              automaticallyImplyLeading: false,
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () async {
                  await context.read<AuthProvider>().logout();
                  if (!context.mounted) return;
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/', (_) => false);
                },
                child: const Text('Logout'),
              ),
            )
          : AppBar(
              title: const Text('Select Facility'),
              automaticallyImplyLeading: false,
              actions: [
                TextButton.icon(
                  icon: Icon(
                    Icons.logout,
                    color: AppColors.of(context).onAccent,
                  ),
                  label: Text(
                    'Logout',
                    style: TextStyle(color: AppColors.of(context).onAccent),
                  ),
                  onPressed: () async {
                    await context.read<AuthProvider>().logout();
                    if (!context.mounted) return;
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/', (_) => false);
                  },
                ),
              ],
            ),
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          final facilities = auth.availableFacilities;
          final user = auth.currentUser;

          final tokens = AppColors.of(context);

          return Container(
            color: tokens.background,
            child: Padding(
              // Horizontal inset comes from AdaptiveCard's own 16px margin —
              // non-card children below re-add a matching 16 so everything
              // in this column lines up.
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Greeting ─────────────────────────────────────────
                  AdaptiveCard(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: tokens.accent,
                          child: Text(
                            auth.initials,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: tokens.onAccent,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          auth.displayName,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: tokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          user?.email ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            color: tokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: Text(
                      'Where are you working today?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  if (auth.error != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: tokens.criticalTint,
                          borderRadius: BorderRadius.circular(
                            AppRadius.control,
                          ),
                          border: Border.all(color: tokens.criticalBorder),
                        ),
                        child: Text(
                          auth.error!,
                          style: TextStyle(color: tokens.critical),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // ── Facility list ────────────────────────────────────
                  Expanded(
                    child: ListView.separated(
                      itemCount: facilities.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.xs),
                      itemBuilder: (_, i) => _FacilityTile(
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
    final tokens = AppColors.of(context);
    final membership = facility.membership;
    final subtitle = [
      if (facility.organization != null) facility.organization!.name,
      if (membership != null) membership.displayType,
    ].join(' · ');

    return AdaptiveCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: AdaptiveListRow(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: tokens.accentTint,
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          child: Icon(Icons.local_hospital, color: tokens.accent),
        ),
        title: facility.name,
        subtitle: subtitle.isEmpty ? null : subtitle,
        trailing: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(Icons.chevron_right, color: tokens.textSecondary),
      ),
    );
  }
}
