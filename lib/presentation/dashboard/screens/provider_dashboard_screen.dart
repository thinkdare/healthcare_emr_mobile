import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/api/api_client.dart';
import '../../../core/platform.dart';
import '../../../data/providers/access_grant_provider.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/emergency_access_provider.dart';
import '../../../data/providers/patient_provider.dart';
import '../../../data/providers/subscription_provider.dart';
import '../../../config/app_config.dart';
import '../../access_grants/screens/access_grants_screen.dart';
import '../../auth/screens/login_screen.dart';
import '../../emergency_access/screens/emergency_access_screen.dart';
import '../../patients/screens/patient_list_screen.dart';
import '../../roster/screens/roster_screen.dart';
import '../../profile/screens/staff_profile_screen.dart';
import '../../facilities/screens/facilities_list_screen.dart';
import '../../organization/screens/organization_profile_screen.dart';
import '../../sync/widgets/root_warning_banner.dart';
import '../../providers/screens/provider_invitation_screen.dart';
import '../../staff/screens/staff_management_screen.dart';
import '../../../data/repositories/organization_repository.dart';
import '../../../data/repositories/staff_repository.dart';
import '../../reporting/screens/reporting_screen.dart';
import '../../subscription/screens/subscription_details_screen.dart';
import '../../subscription/screens/subscription_upgrade_screen.dart';
import '../../subscription/widgets/trial_status_banner.dart';
import '../../sync/widgets/sync_banner.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_spacing.dart';
import '../../shared/widgets/adaptive_card.dart';
import '../../shared/widgets/adaptive_badge.dart';
import '../../shared/widgets/adaptive_list_row.dart';
import '../../shared/widgets/stat_tile.dart';

class ProviderDashboardScreen extends StatefulWidget {
  const ProviderDashboardScreen({super.key});

  @override
  State<ProviderDashboardScreen> createState() =>
      _ProviderDashboardScreenState();
}

class _ProviderDashboardScreenState extends State<ProviderDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  Future<void> _loadAll() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.currentUserId;
    final orgId = auth.organizationId;

    await Future.wait([
      if (orgId != null)
        context.read<SubscriptionProvider>().loadSubscription(orgId),
      // Clinical endpoints require tenant context — skip for org admins.
      if (!auth.isOrgAdmin) ...[
        if (userId != null)
          context.read<PatientProvider>().loadPatients(providerId: userId),
        context.read<AccessGrantProvider>().loadGrants(),
        context.read<EmergencyAccessProvider>().loadLogs(refresh: true),
      ],
    ]);

    if (!auth.isOrgAdmin && userId != null && mounted) {
      await context.read<PatientProvider>().loadDashboardStats(userId);
    }
  }

  Future<void> _handleRefresh() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.currentUserId;
    final orgId = auth.organizationId;

    await Future.wait([
      if (orgId != null)
        context.read<SubscriptionProvider>().loadSubscription(orgId),
      if (!auth.isOrgAdmin && userId != null)
        context.read<PatientProvider>().loadPatients(
          providerId: userId,
          forceRefresh: true,
        ),
    ]);

    if (!auth.isOrgAdmin && userId != null && mounted) {
      await context.read<PatientProvider>().loadDashboardStats(userId);
    }
  }

  Future<void> _showAccountMenu(BuildContext context) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                CupertinoPageRoute(builder: (_) => const StaffProfileScreen()),
              );
            },
            child: const Text('Profile'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => const StaffProfileScreen(initialTab: 1),
                ),
              );
            },
            child: const Text('Settings'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(context).pop();
              _handleLogout(context);
            },
            child: const Text('Logout'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    bool confirmed = false;
    await showAdaptiveActionSheet(
      context: context,
      title: 'Logout',
      message: 'Are you sure you want to logout?',
      destructiveLabel: 'Logout',
      onConfirm: () => confirmed = true,
    );

    if (confirmed && context.mounted) {
      final auth = context.read<AuthProvider>();
      // AuthProvider.logout() clears the disk cache itself now (guaranteed
      // for every logout call site, not just this screen). This only resets
      // PatientProvider's in-memory state so it doesn't flash stale data.
      context.read<PatientProvider>().clearCacheOnLogout();
      await auth.logout();

      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: kIsIOS
          ? CupertinoNavigationBar(
              middle: const Text('Dashboard'),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _showAccountMenu(context),
                child: const Icon(CupertinoIcons.person_circle),
              ),
            )
          : AppBar(
              title: const Text('Dashboard'),
              actions: [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.account_circle_outlined),
                  tooltip: 'Account',
                  onSelected: (value) {
                    switch (value) {
                      case 'profile':
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const StaffProfileScreen(),
                          ),
                        );
                      case 'settings':
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const StaffProfileScreen(initialTab: 1),
                          ),
                        );
                      case 'logout':
                        _handleLogout(context);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'profile',
                      child: ListTile(
                        leading: Icon(Icons.person_outline),
                        title: Text('Profile'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'settings',
                      child: ListTile(
                        leading: Icon(Icons.settings_outlined),
                        title: Text('Settings'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'logout',
                      child: ListTile(
                        leading: Icon(
                          Icons.logout,
                          color: AppColors.of(context).critical,
                        ),
                        title: Text(
                          'Logout',
                          style: TextStyle(
                            color: AppColors.of(context).critical,
                          ),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
      drawer: kIsIOS ? null : _buildDrawer(context),
      body: Column(
        children: [
          const RootWarningBanner(),
          const TrialStatusBanner(),
          const SyncBanner(),
          Expanded(
            child: Consumer<AuthProvider>(
              builder: (context, auth, _) {
                if (auth.currentUser == null) {
                  return const Center(child: Text('Loading…'));
                }

                final isOrgAdmin = auth.isOrgAdmin;
                final isDoctor = auth.staffType == 'doctor';
                final showGrants =
                    isOrgAdmin ||
                    isDoctor ||
                    (auth
                            .activeMembership
                            ?.clinicalRank
                            ?.canApproveAccessGrants ??
                        false);
                final showEmergency = auth.canEmergencyAccess;

                return RefreshIndicator(
                  onRefresh: _handleRefresh,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    // Horizontal inset comes entirely from AdaptiveCard's own
                    // AppSpacing.lg margin; vertical gaps between stacked
                    // cards likewise come from each card's AppSpacing.sm
                    // margin (sm + sm = 16 between adjacent cards) — no
                    // manual SizedBox needed between them.
                    padding: const EdgeInsets.only(
                      top: AppSpacing.sm,
                      bottom: AppSpacing.xl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _WelcomeCard(auth: auth),
                        if (isOrgAdmin) ...[
                          _SubscriptionCard(),
                          _OrgAdminQuickActionsCard(),
                        ] else ...[
                          _PatientStatsCard(userId: auth.currentUserId ?? ''),
                          _RecentPatientsCard(userId: auth.currentUserId ?? ''),
                          if (showGrants) _AccessGrantsCard(),
                          if (showEmergency) _EmergencyAccessCard(),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (auth.isOrgAdmin) return const SizedBox.shrink();
          final useRoster =
              auth.staffType == 'doctor' || auth.staffType == 'nurse';
          return FloatingActionButton.extended(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => useRoster
                    ? const RosterScreen()
                    : const PatientListScreen(),
              ),
            ),
            icon: Icon(useRoster ? Icons.event_note : Icons.people),
            label: Text(
              auth.staffType == 'doctor'
                  ? 'Today\'s Patients'
                  : auth.staffType == 'nurse'
                  ? 'Daily Roster'
                  : 'Patients',
            ),
            backgroundColor: AppColors.of(context).accent,
          );
        },
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          final isOrgAdmin = auth.isOrgAdmin;
          final isDoctor = auth.staffType == 'doctor';
          final showGrants =
              isOrgAdmin ||
              isDoctor ||
              (auth.activeMembership?.clinicalRank?.canApproveAccessGrants ??
                  false);
          final showEmergency = auth.canEmergencyAccess;

          return Column(
            children: [
              UserAccountsDrawerHeader(
                decoration: BoxDecoration(color: AppColors.of(context).accent),
                accountName: Text(
                  auth.displayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                accountEmail: Text(auth.currentUser?.email ?? ''),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Text(
                    auth.initials,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.of(context).accent,
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.home),
                title: const Text('Home'),
                onTap: () => Navigator.of(context).pop(),
              ),
              if (auth.staffType == 'doctor' || auth.staffType == 'nurse')
                ListTile(
                  leading: const Icon(Icons.event_note),
                  title: Text(
                    auth.staffType == 'doctor'
                        ? 'Today\'s Patients'
                        : 'Daily Roster',
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RosterScreen()),
                    );
                  },
                ),
              if (!isOrgAdmin)
                ListTile(
                  leading: const Icon(Icons.people),
                  title: const Text('Patients'),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PatientListScreen(),
                      ),
                    );
                  },
                ),
              if (showGrants)
                Consumer<AccessGrantProvider>(
                  builder: (context, grants, _) => ListTile(
                    leading: Badge(
                      isLabelVisible: grants.pendingCount > 0,
                      label: Text('${grants.pendingCount}'),
                      child: const Icon(Icons.shield_outlined),
                    ),
                    title: const Text('Access Grants'),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AccessGrantsScreen(),
                        ),
                      );
                    },
                  ),
                ),
              if (showEmergency)
                ListTile(
                  leading: Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.of(context).critical,
                  ),
                  title: const Text('Emergency Access'),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const EmergencyAccessScreen(),
                      ),
                    );
                  },
                ),
              // ── Admin section (org admins only) ──────────────────────
              if (isOrgAdmin) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    'ADMIN',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.business, color: Colors.orange.shade700),
                  title: const Text('Organization'),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OrganizationProfileScreen(
                          repository: OrganizationRepository(
                            apiClient: context.read<ApiClient>(),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.local_hospital_outlined,
                    color: Colors.orange.shade700,
                  ),
                  title: const Text('Facilities'),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const FacilitiesListScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.group_outlined,
                    color: Colors.orange.shade700,
                  ),
                  title: const Text('Staff'),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => StaffManagementScreen(
                          repository: StaffRepository(
                            apiClient: context.read<ApiClient>(),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.mail_outline,
                    color: Colors.orange.shade700,
                  ),
                  title: const Text('Invite Staff'),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ProviderInvitationScreen(),
                      ),
                    );
                  },
                ),
              ],
              // ── Account section (all staff) ───────────────────────────
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  'ACCOUNT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.subscriptions),
                title: const Text('Subscription'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SubscriptionDetailsScreen(),
                    ),
                  );
                },
              ),
              if (isOrgAdmin)
                ListTile(
                  leading: const Icon(Icons.analytics_outlined),
                  title: const Text('Reports & Compliance'),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ReportingScreen(),
                      ),
                    );
                  },
                ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('My Profile'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const StaffProfileScreen(),
                    ),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: Icon(
                  Icons.logout,
                  color: AppColors.of(context).critical,
                ),
                title: Text(
                  'Logout',
                  style: TextStyle(color: AppColors.of(context).critical),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _handleLogout(context);
                },
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '${AppConfig.appName} v1.0.0',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.of(context).textSecondary,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// =============================================================================
// ── Cards ─────────────────────────────────────────────────────────────────────
// =============================================================================

class _WelcomeCard extends StatelessWidget {
  final AuthProvider auth;
  const _WelcomeCard({required this.auth});

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    return AdaptiveCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: tokens.accent,
            child: Text(
              auth.initials,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: tokens.onAccent,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back,',
                  style: TextStyle(fontSize: 13, color: tokens.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  auth.displayName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                if (auth.isOrgAdmin)
                  Text(
                    'Organization Administrator',
                    style: TextStyle(fontSize: 14, color: tokens.textSecondary),
                  )
                else if (auth.staffTypeDisplay.isNotEmpty)
                  Text(
                    auth.department.isNotEmpty
                        ? '${auth.staffTypeDisplay} · ${auth.department}'
                        : auth.staffTypeDisplay,
                    style: TextStyle(fontSize: 14, color: tokens.textSecondary),
                  ),
                if (auth.isOrgAdmin &&
                    auth.currentUser?.primaryOrganizationName != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.business,
                        size: 13,
                        color: tokens.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          auth.currentUser!.primaryOrganizationName!,
                          style: TextStyle(
                            fontSize: 12,
                            color: tokens.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ] else if (!auth.isOrgAdmin &&
                    auth.facilityName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 13,
                        color: tokens.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          auth.facilityName,
                          style: TextStyle(
                            fontSize: 12,
                            color: tokens.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Org Admin Quick Actions Card ──────────────────────────────────────────────

class _OrgAdminQuickActionsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    return AdaptiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.admin_panel_settings, color: tokens.accent),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Administration',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: tokens.textPrimary,
                ),
              ),
            ],
          ),
          const Divider(height: AppSpacing.xl),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            childAspectRatio: 2.4,
            children: [
              _AdminTile(
                icon: Icons.business,
                label: 'Organization',
                color: Colors.orange.shade700,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => OrganizationProfileScreen(
                        repository: OrganizationRepository(
                          apiClient: context.read<ApiClient>(),
                        ),
                      ),
                    ),
                  );
                },
              ),
              _AdminTile(
                icon: Icons.local_hospital_outlined,
                label: 'Facilities',
                color: Colors.blue.shade700,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const FacilitiesListScreen(),
                    ),
                  );
                },
              ),
              _AdminTile(
                icon: Icons.group_outlined,
                label: 'Staff',
                color: Colors.green.shade700,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StaffManagementScreen(
                        repository: StaffRepository(
                          apiClient: context.read<ApiClient>(),
                        ),
                      ),
                    ),
                  );
                },
              ),
              _AdminTile(
                icon: Icons.mail_outline,
                label: 'Invite Staff',
                color: Colors.purple.shade700,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ProviderInvitationScreen(),
                    ),
                  );
                },
              ),
              _AdminTile(
                icon: Icons.analytics_outlined,
                label: 'Reports',
                color: Colors.teal.shade700,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ReportingScreen()),
                  );
                },
              ),
              _AdminTile(
                icon: Icons.shield_outlined,
                label: 'Access Grants',
                color: Colors.indigo.shade700,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AccessGrantsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AdminTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Patient Stats Card ────────────────────────────────────────────────────────

class _PatientStatsCard extends StatelessWidget {
  final String userId;
  const _PatientStatsCard({required this.userId});

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    return Consumer<PatientProvider>(
      builder: (context, p, _) {
        final stats = p.stats;
        return AdaptiveCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.analytics, color: tokens.accent),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Patient Overview',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ),
                  if (p.patientsFromCache)
                    Tooltip(
                      message: 'Showing cached data',
                      child: Icon(
                        Icons.offline_bolt,
                        size: 16,
                        color: tokens.warning,
                      ),
                    ),
                  if (p.isLoadingStats)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const Divider(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      icon: Icons.people,
                      label: 'Total Patients',
                      value: p.isLoadingStats ? '…' : '${stats.totalPatients}',
                      color: tokens.accent,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PatientListScreen(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: StatTile(
                      icon: Icons.person_add,
                      label: 'New (7 days)',
                      value: p.isLoadingStats ? '…' : '${stats.recentPatients}',
                      color: tokens.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      icon: Icons.event,
                      label: 'Appointments',
                      value: p.isLoadingStats
                          ? '…'
                          : '${stats.pendingAppointments}',
                      color: tokens.accent,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: StatTile(
                      icon: Icons.medication,
                      label: 'Prescriptions',
                      value: p.isLoadingStats
                          ? '…'
                          : '${stats.activePrescriptions}',
                      color: tokens.warning,
                    ),
                  ),
                ],
              ),
              if (stats.lastRefreshed != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Last refreshed: ${_timeAgo(stats.lastRefreshed!)}',
                  style: TextStyle(fontSize: 11, color: tokens.textSecondary),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ── Recent Patients Card ──────────────────────────────────────────────────────

class _RecentPatientsCard extends StatelessWidget {
  final String userId;
  const _RecentPatientsCard({required this.userId});

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    return Consumer<PatientProvider>(
      builder: (context, p, _) {
        final recent = p.patients.take(5).toList();

        return AdaptiveCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.history, color: tokens.accent),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Recent Patients',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ),
                  AdaptiveTextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PatientListScreen(),
                      ),
                    ),
                    child: const Text('View All'),
                  ),
                ],
              ),
              const Divider(height: AppSpacing.lg),
              if (p.isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (recent.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 48,
                          color: tokens.textSecondary,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'No patients yet',
                          style: TextStyle(color: tokens.textSecondary),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recent.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final patient = recent[i];
                    return AdaptiveListRow(
                      leading: CircleAvatar(
                        backgroundColor: tokens.accentTint,
                        child: Text(
                          '${patient.firstName[0]}${patient.lastName[0]}',
                          style: TextStyle(
                            color: tokens.accent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: patient.fullName,
                      subtitle:
                          '${patient.gender} · ${patient.ageDisplay}'
                          '${patient.bloodType != null ? ' · ${patient.bloodType}' : ''}',
                      trailing: patient.hasCriticalAllergies
                          ? Tooltip(
                              message: 'Critical allergies',
                              child: Icon(
                                Icons.warning,
                                size: 18,
                                color: tokens.critical,
                              ),
                            )
                          : null,
                      onTap: () {
                        context.read<PatientProvider>().setSelectedPatient(
                          patient,
                        );
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PatientListScreen(),
                          ),
                        );
                      },
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Subscription Card ─────────────────────────────────────────────────────────

class _SubscriptionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    return Consumer<SubscriptionProvider>(
      builder: (context, sp, _) {
        final subscription = sp.subscription;
        if (subscription == null) return const SizedBox.shrink();

        final onTrial = subscription.isTrial;
        final daysRemaining = subscription.trialDaysRemaining ?? 0;
        final statusColor = onTrial ? tokens.warning : tokens.success;
        final statusTint = onTrial ? tokens.warningTint : tokens.successTint;
        final urgent = daysRemaining <= 7;

        return AdaptiveCard(
          backgroundColor: statusTint,
          borderColor: statusColor.withValues(alpha: 0.3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    onTrial ? Icons.schedule : Icons.check_circle,
                    color: statusColor,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Subscription',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: tokens.textPrimary,
                    ),
                  ),
                ],
              ),
              const Divider(height: AppSpacing.lg),
              Row(
                children: [
                  Text(
                    'Status',
                    style: TextStyle(
                      color: tokens.textSecondaryAlt,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  AdaptiveBadge(
                    label: onTrial ? 'Free Trial' : 'Active',
                    variant: onTrial
                        ? BadgeVariant.warning
                        : BadgeVariant.success,
                    icon: onTrial ? Icons.schedule : Icons.check_circle,
                  ),
                ],
              ),
              if (onTrial) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Text(
                      'Days Remaining',
                      style: TextStyle(
                        color: tokens.textSecondaryAlt,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    AdaptiveBadge(
                      label:
                          '$daysRemaining day${daysRemaining == 1 ? '' : 's'}',
                      variant: urgent
                          ? BadgeVariant.critical
                          : BadgeVariant.warning,
                      icon: Icons.hourglass_bottom,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: AdaptiveFilledButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SubscriptionUpgradeScreen(),
                      ),
                    ),
                    child: const Text('Upgrade Plan'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── Access Grants Card ────────────────────────────────────────────────────────

class _AccessGrantsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    return Consumer<AccessGrantProvider>(
      builder: (context, grants, _) {
        final pending = grants.pendingCount;
        final hasActivity = pending > 0 || grants.myRequests.isNotEmpty;

        if (!hasActivity && !grants.isLoading) return const SizedBox.shrink();

        return AdaptiveCard(
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AccessGrantsScreen())),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    pending > 0
                        ? Icons.shield_outlined
                        : Icons.lock_open_outlined,
                    color: pending > 0 ? tokens.warning : tokens.accent,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Access Grants',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: tokens.textSecondary),
                ],
              ),
              if (pending > 0) ...[
                const Divider(height: AppSpacing.lg),
                AdaptiveBadge(
                  label:
                      '$pending request${pending == 1 ? '' : 's'} awaiting your approval',
                  variant: BadgeVariant.warning,
                  icon: Icons.pending_actions,
                ),
              ] else if (grants.myRequests.isNotEmpty) ...[
                const Divider(height: AppSpacing.lg),
                Text(
                  '${grants.myRequests.length} request${grants.myRequests.length == 1 ? '' : 's'} sent',
                  style: TextStyle(fontSize: 13, color: tokens.textSecondary),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── Emergency Access Card ─────────────────────────────────────────────────────

class _EmergencyAccessCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    return Consumer<EmergencyAccessProvider>(
      builder: (context, em, _) {
        final unreviewed = em.unreviewedCount;
        final hasActivity = unreviewed > 0 || em.logs.isNotEmpty;

        if (!hasActivity && !em.isLoading) return const SizedBox.shrink();

        return AdaptiveCard(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const EmergencyAccessScreen()),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: unreviewed > 0
                        ? tokens.critical
                        : tokens.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Emergency Access',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: tokens.textSecondary),
                ],
              ),
              if (unreviewed > 0) ...[
                const Divider(height: AppSpacing.lg),
                AdaptiveBadge(
                  label:
                      '$unreviewed event${unreviewed == 1 ? '' : 's'} awaiting your review',
                  variant: BadgeVariant.critical,
                  icon: Icons.rate_review_outlined,
                ),
              ] else if (em.logs.isNotEmpty) ...[
                const Divider(height: AppSpacing.lg),
                Text(
                  '${em.logs.length} event${em.logs.length == 1 ? '' : 's'} logged',
                  style: TextStyle(fontSize: 13, color: tokens.textSecondary),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
