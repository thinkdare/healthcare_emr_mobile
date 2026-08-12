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
import '../../providers/screens/provider_invitation_screen.dart';
import '../../staff/screens/staff_management_screen.dart';
import '../../../data/repositories/organization_repository.dart';
import '../../../data/repositories/staff_repository.dart';
import '../../reporting/screens/reporting_screen.dart';
import '../../subscription/screens/subscription_details_screen.dart';
import '../../subscription/screens/subscription_upgrade_screen.dart';
import '../../subscription/widgets/trial_status_banner.dart';
import '../../sync/widgets/sync_banner.dart';
import '../../shell/widgets/device_integrity_banner.dart';
import '../../shared/widgets/adaptive_badge.dart';
import '../../shared/widgets/adaptive_card.dart';
import '../../shared/widgets/adaptive_list_row.dart';
import '../../shared/widgets/stat_tile.dart';
import '../../../config/app_colors.dart';

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
      // Billing/subscription visibility is org-admin-only on the backend;
      // staff logins get a 403 here, so don't bother making the request.
      if (orgId != null && auth.isOrgAdmin)
        context.read<SubscriptionProvider>().loadSubscription(orgId),
      if (userId != null)
        context.read<PatientProvider>().loadPatients(providerId: userId),
      context.read<AccessGrantProvider>().loadGrants(),
      context.read<EmergencyAccessProvider>().loadLogs(refresh: true),
    ]);

    if (userId != null && mounted) {
      await context.read<PatientProvider>().loadDashboardStats(userId);
    }
  }

  Future<void> _handleRefresh() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.currentUserId;

    final orgId = auth.organizationId;
    await Future.wait([
      if (orgId != null && auth.isOrgAdmin)
        context.read<SubscriptionProvider>().loadSubscription(orgId),
      if (userId != null)
        context.read<PatientProvider>().loadPatients(
          providerId: userId,
          forceRefresh: true,
        ),
    ]);

    if (userId != null && mounted) {
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
      final userId = auth.currentUserId;

      if (userId != null) {
        await context.read<PatientProvider>().clearCacheOnLogout(userId);
      }
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
          const TrialStatusBanner(),
          const DeviceIntegrityBanner(),
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
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _WelcomeCard(auth: auth),
                        const SizedBox(height: 16),
                        if (isOrgAdmin) ...[
                          _SubscriptionCard(),
                          const SizedBox(height: 16),
                        ],
                        _PatientStatsCard(userId: auth.currentUserId ?? ''),
                        const SizedBox(height: 16),
                        _RecentPatientsCard(userId: auth.currentUserId ?? ''),
                        if (showGrants) ...[
                          const SizedBox(height: 16),
                          _AccessGrantsCard(),
                        ],
                        if (showEmergency) ...[
                          const SizedBox(height: 16),
                          _EmergencyAccessCard(),
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
                decoration: BoxDecoration(
                  color: AppColors.of(context).accent,
                ),
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
              // Billing/subscription visibility is org-admin-only on the
              // backend (BillingController::resolveOrg) — staff get a 403.
              if (isOrgAdmin)
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
              ListTile(
                leading: const Icon(Icons.analytics_outlined),
                title: const Text('Reports & Compliance'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ReportingScreen()),
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
      backgroundColor: tokens.accent,
      borderColor: tokens.accent,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome back,',
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
            const SizedBox(height: 4),
            Text(
              auth.displayName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            if (auth.staffTypeDisplay.isNotEmpty)
              Text(
                auth.department.isNotEmpty
                    ? '${auth.staffTypeDisplay} · ${auth.department}'
                    : auth.staffTypeDisplay,
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
            if (auth.facilityName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 14,
                    color: Colors.white54,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    auth.facilityName,
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ],
              ),
            ],
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
    return Consumer<PatientProvider>(
      builder: (context, p, _) {
        final stats = p.stats;
        return AdaptiveCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.analytics,
                    color: AppColors.of(context).accent,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Patient Overview',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (p.patientsFromCache)
                    Tooltip(
                      message: 'Showing cached data',
                      child: Icon(
                        Icons.offline_bolt,
                        size: 16,
                        color: AppColors.of(context).warning,
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
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      icon: Icons.people,
                      label: 'Total Patients',
                      value: p.isLoadingStats
                          ? '…'
                          : '${stats.totalPatients}',
                      color: AppColors.of(context).accent,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PatientListScreen(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatTile(
                      icon: Icons.person_add,
                      label: 'New (7 days)',
                      value: p.isLoadingStats
                          ? '…'
                          : '${stats.recentPatients}',
                      color: AppColors.of(context).success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      icon: Icons.event,
                      label: 'Upcoming Appts',
                      value: p.isLoadingStats
                          ? '…'
                          : '${stats.pendingAppointments}',
                      color: AppColors.of(context).accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatTile(
                      icon: Icons.medication,
                      label: 'Active Rx',
                      value: p.isLoadingStats
                          ? '…'
                          : '${stats.activePrescriptions}',
                      color: AppColors.of(context).warning,
                    ),
                  ),
                ],
              ),
              if (stats.lastRefreshed != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Last refreshed: ${_timeAgo(stats.lastRefreshed!)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.of(context).textSecondary,
                  ),
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
    return Consumer<PatientProvider>(
      builder: (context, p, _) {
        final recent = p.patients.take(5).toList();

        return AdaptiveCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.history, color: AppColors.of(context).accent),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Recent Patients',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
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
              const Divider(height: 16),
              if (p.isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (recent.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 48,
                          color: AppColors.of(context).textSecondary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No patients yet',
                          style: TextStyle(
                            color: AppColors.of(context).textSecondary,
                          ),
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
                        backgroundColor: AppColors.of(context).accentTint,
                        child: Text(
                          '${patient.firstName[0]}${patient.lastName[0]}',
                          style: TextStyle(
                            color: AppColors.of(context).accent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: patient.fullName,
                      subtitle:
                          '${patient.gender} · ${patient.ageDisplay}'
                          '${patient.bloodType != null ? ' · ${patient.bloodType}' : ''}',
                      trailing: patient.hasCriticalAllergies
                          ? const AdaptiveBadge(
                              label: 'Allergy',
                              variant: BadgeVariant.critical,
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
    return Consumer<SubscriptionProvider>(
      builder: (context, sp, _) {
        final subscription = sp.subscription;
        if (subscription == null) return const SizedBox.shrink();

        final onTrial = subscription.isTrial;
        final daysRemaining = subscription.trialDaysRemaining ?? 0;
        final statusColor = onTrial
            ? AppColors.of(context).warning
            : AppColors.of(context).success;

        return AdaptiveCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    onTrial ? Icons.schedule : Icons.check_circle,
                    color: statusColor,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Subscription',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Divider(height: 16),
              _InfoRow(
                'Status',
                onTrial ? 'Free Trial' : 'Active',
                valueColor: statusColor,
              ),
              if (onTrial) ...[
                const SizedBox(height: 8),
                _InfoRow(
                  'Days Remaining',
                  '$daysRemaining',
                  valueColor: daysRemaining <= 7
                      ? AppColors.of(context).critical
                      : AppColors.of(context).warning,
                ),
                const SizedBox(height: 12),
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
    return Consumer<AccessGrantProvider>(
      builder: (context, grants, _) {
        final pending = grants.pendingCount;
        final hasActivity = pending > 0 || grants.myRequests.isNotEmpty;

        if (!hasActivity && !grants.isLoading) return const SizedBox.shrink();

        return AdaptiveCard(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AccessGrantsScreen()),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    pending > 0
                        ? Icons.shield_outlined
                        : Icons.lock_open_outlined,
                    color: pending > 0
                        ? AppColors.of(context).warning
                        : AppColors.of(context).accent,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Access Grants',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (pending > 0) ...[
                    AdaptiveBadge(
                      label: '$pending',
                      variant: BadgeVariant.warning,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Icon(
                    Icons.chevron_right,
                    color: AppColors.of(context).textSecondary,
                  ),
                ],
              ),
              if (pending > 0) ...[
                const Divider(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.of(
                      context,
                    ).warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.pending_actions,
                        color: AppColors.of(context).warning,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$pending request${pending == 1 ? '' : 's'} awaiting your approval',
                        style: TextStyle(
                          color: AppColors.of(context).warning,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (grants.myRequests.isNotEmpty) ...[
                const Divider(height: 16),
                Text(
                  '${grants.myRequests.length} request${grants.myRequests.length == 1 ? '' : 's'} sent',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.of(context).textSecondary,
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

// ── Emergency Access Card ─────────────────────────────────────────────────────

class _EmergencyAccessCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<EmergencyAccessProvider>(
      builder: (context, em, _) {
        final unreviewed = em.unreviewedCount;
        final hasActivity = unreviewed > 0 || em.logs.isNotEmpty;

        if (!hasActivity && !em.isLoading) return const SizedBox.shrink();

        return AdaptiveCard(
          backgroundColor: AppColors.of(context).criticalTint,
          borderColor: AppColors.of(context).criticalBorder,
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
                        ? AppColors.of(context).critical
                        : AppColors.of(context).textSecondary,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Emergency Access',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (unreviewed > 0) ...[
                    AdaptiveBadge(
                      label: '$unreviewed',
                      variant: BadgeVariant.critical,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Icon(
                    Icons.chevron_right,
                    color: AppColors.of(context).textSecondary,
                  ),
                ],
              ),
              if (unreviewed > 0) ...[
                const Divider(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.of(
                      context,
                    ).critical.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.rate_review_outlined,
                        color: AppColors.of(context).critical,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$unreviewed event${unreviewed == 1 ? '' : 's'} awaiting your review',
                        style: TextStyle(
                          color: AppColors.of(context).critical,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (em.logs.isNotEmpty) ...[
                const Divider(height: 16),
                Text(
                  '${em.logs.length} event${em.logs.length == 1 ? '' : 's'} logged',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.of(context).textSecondary,
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

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$label:',
            style: TextStyle(
              color: AppColors.of(context).textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w600, color: valueColor),
          ),
        ),
      ],
    );
  }
}
