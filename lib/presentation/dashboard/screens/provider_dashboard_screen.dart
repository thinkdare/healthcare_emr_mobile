import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/platform.dart';
import '../../../data/providers/access_grant_provider.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/emergency_access_provider.dart';
import '../../../data/providers/patient_provider.dart';
import '../../../data/providers/subscription_provider.dart';
import '../../../config/app_config.dart';
import '../../../config/theme.dart';
import '../../access_grants/screens/access_grants_screen.dart';
import '../../auth/screens/login_screen.dart';
import '../../emergency_access/screens/emergency_access_screen.dart';
import '../../patients/screens/patient_list_screen.dart';
import '../../roster/screens/roster_screen.dart';
import '../../profile/screens/staff_profile_screen.dart';
import '../../reporting/screens/reporting_screen.dart';
import '../../subscription/screens/subscription_details_screen.dart';
import '../../subscription/screens/subscription_upgrade_screen.dart';
import '../../subscription/widgets/trial_status_banner.dart';

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
      if (userId != null)
        context.read<PatientProvider>().loadPatients(providerId: userId),
      context.read<AccessGrantProvider>().loadGrants(),
      context
          .read<EmergencyAccessProvider>()
          .loadLogs(refresh: true),
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
      if (orgId != null)
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
              Navigator.of(context).push(CupertinoPageRoute(
                  builder: (_) => const StaffProfileScreen()));
            },
            child: const Text('Profile'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(CupertinoPageRoute(
                  builder: (_) => const StaffProfileScreen(initialTab: 1)));
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
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const StaffProfileScreen()));
                      case 'settings':
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) =>
                                const StaffProfileScreen(initialTab: 1)));
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
                    const PopupMenuItem(
                      value: 'logout',
                      child: ListTile(
                        leading: Icon(Icons.logout, color: AppTheme.errorColor),
                        title: Text('Logout',
                            style: TextStyle(color: AppTheme.errorColor)),
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
          Expanded(
            child: Consumer<AuthProvider>(
              builder: (context, auth, _) {
                if (auth.currentUser == null) {
                  return const Center(child: Text('Loading…'));
                }

                final isAdmin = auth.staffType == 'admin';
                final isDoctor = auth.staffType == 'doctor';
                final showGrants = isAdmin || isDoctor ||
                    (auth.activeMembership?.clinicalRank
                            ?.canApproveAccessGrants ??
                        false);
                final showEmergency = auth.canEmergencyAccess;

                return RefreshIndicator(
                  onRefresh: _handleRefresh,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _WelcomeCard(auth: auth),
                        const SizedBox(height: 16),
                        if (isAdmin) ...[
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
          final useRoster = auth.staffType == 'doctor' ||
              auth.staffType == 'nurse';
          return FloatingActionButton.extended(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    useRoster ? const RosterScreen() : const PatientListScreen(),
              ),
            ),
            icon: Icon(useRoster ? Icons.event_note : Icons.people),
            label: Text(auth.staffType == 'doctor'
                ? 'Today\'s Patients'
                : auth.staffType == 'nurse'
                    ? 'Daily Roster'
                    : 'Patients'),
            backgroundColor: AppTheme.primaryColor,
          );
        },
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          final isAdmin = auth.staffType == 'admin';
          final isDoctor = auth.staffType == 'doctor';
          final showGrants = isAdmin || isDoctor ||
              (auth.activeMembership?.clinicalRank?.canApproveAccessGrants ??
                  false);
          final showEmergency = auth.canEmergencyAccess;
          final showAdminItems = isAdmin;

          return Column(
            children: [
              UserAccountsDrawerHeader(
                decoration:
                    const BoxDecoration(color: AppTheme.primaryColor),
                accountName: Text(
                  auth.displayName,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                accountEmail: Text(auth.currentUser?.email ?? ''),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Text(
                    auth.initials,
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor),
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
                  title: Text(auth.staffType == 'doctor'
                      ? 'Today\'s Patients'
                      : 'Daily Roster'),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const RosterScreen()));
                  },
                ),
              ListTile(
                leading: const Icon(Icons.people),
                title: const Text('Patients'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const PatientListScreen()),
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
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const AccessGrantsScreen()));
                    },
                  ),
                ),
              if (showEmergency)
                ListTile(
                  leading: const Icon(Icons.warning_amber_rounded,
                      color: AppTheme.errorColor),
                  title: const Text('Emergency Access'),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const EmergencyAccessScreen()));
                  },
                ),
              if (showAdminItems) ...[
                ListTile(
                  leading: const Icon(Icons.subscriptions),
                  title: const Text('Subscription'),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const SubscriptionDetailsScreen()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.analytics_outlined),
                  title: const Text('Reports & Compliance'),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const ReportingScreen()));
                  },
                ),
              ],
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('My Profile'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const StaffProfileScreen()));
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: AppTheme.errorColor),
                title: const Text('Logout',
                    style: TextStyle(color: AppTheme.errorColor)),
                onTap: () {
                  Navigator.of(context).pop();
                  _handleLogout(context);
                },
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('${AppConfig.appName} v1.0.0',
                    style: TextStyle(fontSize: 12, color: AppTheme.gray600)),
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
    return Card(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Welcome back,',
                style: TextStyle(fontSize: 16, color: Colors.white70)),
            const SizedBox(height: 4),
            Text(auth.displayName,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
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
              Row(children: [
                const Icon(Icons.location_on,
                    size: 14, color: Colors.white54),
                const SizedBox(width: 4),
                Text(auth.facilityName,
                    style:
                        const TextStyle(fontSize: 13, color: Colors.white70)),
              ]),
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
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.analytics, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Patient Overview',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  if (p.patientsFromCache)
                    Tooltip(
                      message: 'Showing cached data',
                      child: Icon(Icons.offline_bolt,
                          size: 16, color: AppTheme.warningColor),
                    ),
                  if (p.isLoadingStats)
                    const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                ]),
                const Divider(height: 24),
                Row(children: [
                  Expanded(
                    child: _StatTile(
                      icon: Icons.people,
                      label: 'Total Patients',
                      value:
                          p.isLoadingStats ? '…' : '${stats.totalPatients}',
                      color: AppTheme.primaryColor,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const PatientListScreen())),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatTile(
                      icon: Icons.person_add,
                      label: 'New (7 days)',
                      value:
                          p.isLoadingStats ? '…' : '${stats.recentPatients}',
                      color: AppTheme.successColor,
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: _StatTile(
                      icon: Icons.event,
                      label: 'Appointments',
                      value: '—',
                      color: AppTheme.secondaryColor,
                      subtitle: 'Coming soon',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatTile(
                      icon: Icons.medication,
                      label: 'Prescriptions',
                      value: '—',
                      color: AppTheme.warningColor,
                      subtitle: 'Coming soon',
                    ),
                  ),
                ]),
                if (stats.lastRefreshed != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Last refreshed: ${_timeAgo(stats.lastRefreshed!)}',
                    style: TextStyle(fontSize: 11, color: AppTheme.gray600),
                  ),
                ],
              ],
            ),
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

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.history, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Recent Patients',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  AdaptiveTextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const PatientListScreen()),
                    ),
                    child: const Text('View All'),
                  ),
                ]),
                const Divider(height: 16),
                if (p.isLoading)
                  const Center(
                      child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator()))
                else if (recent.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.people_outline,
                              size: 48, color: AppTheme.gray600),
                          const SizedBox(height: 12),
                          Text('No patients yet',
                              style: TextStyle(color: AppTheme.gray600)),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: recent.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final patient = recent[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor:
                              AppTheme.primaryColor.withValues(alpha: 0.1),
                          child: Text(
                            '${patient.firstName[0]}${patient.lastName[0]}',
                            style: const TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(patient.fullName,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${patient.gender} · ${patient.ageDisplay}'
                          '${patient.bloodType != null ? ' · ${patient.bloodType}' : ''}',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.gray600),
                        ),
                        trailing: patient.hasCriticalAllergies
                            ? Tooltip(
                                message: 'Critical allergies',
                                child: Icon(Icons.warning,
                                    size: 18,
                                    color: AppTheme.errorColor),
                              )
                            : null,
                        onTap: () {
                          context
                              .read<PatientProvider>()
                              .setSelectedPatient(patient);
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => const PatientListScreen()));
                        },
                      );
                    },
                  ),
              ],
            ),
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
        final statusColor =
            onTrial ? AppTheme.warningColor : AppTheme.successColor;

        return Card(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [
                  statusColor.withValues(alpha: 0.1),
                  statusColor.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(
                    onTrial ? Icons.schedule : Icons.check_circle,
                    color: statusColor,
                  ),
                  const SizedBox(width: 8),
                  const Text('Subscription',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ]),
                const Divider(height: 16),
                _InfoRow('Status', onTrial ? 'Free Trial' : 'Active',
                    valueColor: statusColor),
                if (onTrial) ...[
                  const SizedBox(height: 8),
                  _InfoRow('Days Remaining', '$daysRemaining',
                      valueColor: daysRemaining <= 7
                          ? AppTheme.errorColor
                          : AppTheme.warningColor),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: AdaptiveFilledButton(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  const SubscriptionUpgradeScreen())),
                      child: const Text('Upgrade Plan'),
                    ),
                  ),
                ],
              ],
            ),
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
        final hasActivity =
            pending > 0 || grants.myRequests.isNotEmpty;

        if (!hasActivity && !grants.isLoading) return const SizedBox.shrink();

        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const AccessGrantsScreen())),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(
                      pending > 0
                          ? Icons.shield_outlined
                          : Icons.lock_open_outlined,
                      color: pending > 0
                          ? AppTheme.warningColor
                          : AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Access Grants',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    const Icon(Icons.chevron_right, color: AppTheme.gray600),
                  ]),
                  if (pending > 0) ...[
                    const Divider(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.warningColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        Icon(Icons.pending_actions,
                            color: AppTheme.warningColor, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '$pending request${pending == 1 ? '' : 's'} awaiting your approval',
                          style: TextStyle(
                              color: AppTheme.warningColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 13),
                        ),
                      ]),
                    ),
                  ] else if (grants.myRequests.isNotEmpty) ...[
                    const Divider(height: 16),
                    Text(
                      '${grants.myRequests.length} request${grants.myRequests.length == 1 ? '' : 's'} sent',
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.gray600),
                    ),
                  ],
                ],
              ),
            ),
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

        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const EmergencyAccessScreen())),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: unreviewed > 0
                          ? AppTheme.errorColor
                          : AppTheme.gray600,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Emergency Access',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    const Icon(Icons.chevron_right, color: AppTheme.gray600),
                  ]),
                  if (unreviewed > 0) ...[
                    const Divider(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        const Icon(Icons.rate_review_outlined,
                            color: AppTheme.errorColor, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '$unreviewed event${unreviewed == 1 ? '' : 's'} awaiting your review',
                          style: const TextStyle(
                              color: AppTheme.errorColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 13),
                        ),
                      ]),
                    ),
                  ] else if (em.logs.isNotEmpty) ...[
                    const Divider(height: 16),
                    Text(
                      '${em.logs.length} event${em.logs.length == 1 ? '' : 's'} logged',
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.gray600),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? subtitle;
  final VoidCallback? onTap;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(fontSize: 11, color: AppTheme.gray600),
                textAlign: TextAlign.center),
            if (subtitle != null)
              Text(subtitle!,
                  style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.gray600,
                      fontStyle: FontStyle.italic)),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text('$label:',
              style: TextStyle(
                  color: AppTheme.gray600, fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: valueColor)),
        ),
      ],
    );
  }
}
