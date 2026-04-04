import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/patient_provider.dart';
import '../../../data/providers/subscription_provider.dart';
import '../../../config/app_config.dart';
import '../../../config/theme.dart';
import '../../auth/screens/login_screen.dart';
import '../../patients/screens/patient_list_screen.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAll();
    });
  }

  Future<void> _loadAll() async {
    final auth = context.read<AuthProvider>();
    final providerId = auth.currentProvider?.id;

    await Future.wait([
      context.read<SubscriptionProvider>().loadTrialStatus(),
      if (providerId != null)
        context.read<PatientProvider>().loadPatients(providerId: providerId),
    ]);

    if (providerId != null && mounted) {
      await context
          .read<PatientProvider>()
          .loadDashboardStats(providerId);
    }
  }

  Future<void> _handleRefresh() async {
    final auth = context.read<AuthProvider>();
    final providerId = auth.currentProvider?.id;

    await Future.wait([
      auth.refreshCurrentUser(),
      context.read<SubscriptionProvider>().loadTrialStatus(),
      if (providerId != null)
        context.read<PatientProvider>().loadPatients(
              providerId: providerId,
              forceRefresh: true,
            ),
    ]);

    if (providerId != null && mounted) {
      await context.read<PatientProvider>().loadDashboardStats(providerId);
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final auth = context.read<AuthProvider>();
      final providerId = auth.currentProvider?.id;

      // Clear patient cache before logging out
      if (providerId != null) {
        await context
            .read<PatientProvider>()
            .clearCacheOnLogout(providerId);
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
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: Column(
        children: [
          const TrialStatusBanner(),
          Expanded(
            child: Consumer<AuthProvider>(
              builder: (context, auth, _) {
                final provider = auth.currentProvider;
                final org = provider?.organization;

                if (provider == null) {
                  return const Center(
                    child: Text('No provider data available'),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _handleRefresh,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _WelcomeCard(provider: provider),
                        const SizedBox(height: 16),
                        _SubscriptionCard(),
                        const SizedBox(height: 16),
                        // ── PHASE 2: Real stats card ────────────────────────
                        _PatientStatsCard(providerId: provider.id),
                        const SizedBox(height: 16),
                        // ── PHASE 2: Recent patients quick-access ───────────
                        _RecentPatientsCard(providerId: provider.id),
                        const SizedBox(height: 16),
                        _ProviderInfoCard(provider: provider),
                        const SizedBox(height: 16),
                        if (org != null) _OrganizationCard(org: org),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),

      // ── FAB: Add Patient ──────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const PatientListScreen(),
            ),
          );
        },
        icon: const Icon(Icons.people),
        label: const Text('Patients'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  // ── Drawer ─────────────────────────────────────────────────────────────────

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              final provider = auth.currentProvider;
              final user = auth.currentUser;
              return UserAccountsDrawerHeader(
                decoration: const BoxDecoration(color: AppTheme.primaryColor),
                accountName: Text(
                  provider?.fullName ?? 'Provider',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                accountEmail: Text(user?.email ?? ''),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Text(
                    provider != null
                        ? '${provider.firstName[0]}${provider.lastName[0]}'
                        : 'P',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () => Navigator.of(context).pop(),
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
          ListTile(
            leading: const Icon(Icons.subscriptions),
            title: const Text('Subscription'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed('/subscription');
            },
          ),
          const Divider(),
          ListTile(
            leading:
                const Icon(Icons.logout, color: AppTheme.errorColor),
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
            child: Text(
              '${AppConfig.appName} v1.0.0',
              style: TextStyle(fontSize: 12, color: AppTheme.gray600),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// ── Extracted widget cards ────────────────────────────────────────────────────
// =============================================================================

class _WelcomeCard extends StatelessWidget {
  final dynamic provider;
  const _WelcomeCard({required this.provider});

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
            Text(
              provider.fullName,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              AppConfig.providerTypeNames[provider.providerType] ??
                  provider.providerType,
              style: const TextStyle(fontSize: 16, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Patient Stats Card (Phase 2) ──────────────────────────────────────────────

class _PatientStatsCard extends StatelessWidget {
  final String providerId;
  const _PatientStatsCard({required this.providerId});

  @override
  Widget build(BuildContext context) {
    return Consumer<PatientProvider>(
      builder: (context, patientProvider, _) {
        final stats = patientProvider.stats;
        final isLoading = patientProvider.isLoadingStats;
        final fromCache = patientProvider.statsFromCache;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────────────
                Row(
                  children: [
                    const Icon(Icons.analytics, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Patient Overview',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    if (fromCache)
                      Tooltip(
                        message: 'Showing cached data',
                        child: Icon(Icons.offline_bolt,
                            size: 16, color: AppTheme.warningColor),
                      ),
                    if (isLoading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const Divider(height: 24),

                // ── Stats grid ───────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        icon: Icons.people,
                        label: 'Total Patients',
                        value: isLoading ? '…' : '${stats.totalPatients}',
                        color: AppTheme.primaryColor,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const PatientListScreen()),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatTile(
                        icon: Icons.person_add,
                        label: 'New (7 days)',
                        value: isLoading ? '…' : '${stats.recentPatients}',
                        color: AppTheme.successColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        icon: Icons.event,
                        label: 'Appointments',
                        value: '—',
                        color: AppTheme.secondaryColor,
                        subtitle: 'Phase 5',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatTile(
                        icon: Icons.medication,
                        label: 'Prescriptions',
                        value: '—',
                        color: AppTheme.warningColor,
                        subtitle: 'Phase 5',
                      ),
                    ),
                  ],
                ),

                // ── Last refreshed ───────────────────────────────────────────
                if (stats.lastRefreshed != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Last refreshed: ${_formatTime(stats.lastRefreshed!)}',
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

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ── Recent Patients Card (Phase 2) ────────────────────────────────────────────

class _RecentPatientsCard extends StatelessWidget {
  final String providerId;
  const _RecentPatientsCard({required this.providerId});

  @override
  Widget build(BuildContext context) {
    return Consumer<PatientProvider>(
      builder: (context, patientProvider, _) {
        final patients = patientProvider.patients;
        final isLoading = patientProvider.isLoading;
        final fromCache = patientProvider.patientsFromCache;

        // Show up to 5 most recent
        final recent = patients.take(5).toList();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Recent Patients',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    if (fromCache)
                      Tooltip(
                        message: 'Showing cached data',
                        child: Icon(Icons.offline_bolt,
                            size: 16, color: AppTheme.warningColor),
                      ),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const PatientListScreen()),
                      ),
                      child: const Text('View All'),
                    ),
                  ],
                ),
                const Divider(height: 16),

                if (isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (recent.isEmpty)
                  _EmptyPatientsPlaceholder()
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: recent.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1),
                    itemBuilder: (_, i) =>
                        _PatientListTile(patient: recent[i]),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PatientListTile extends StatelessWidget {
  final dynamic patient;
  const _PatientListTile({required this.patient});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
        child: Text(
          '${patient.firstName[0]}${patient.lastName[0]}',
          style: const TextStyle(
              color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(
        patient.fullName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${patient.gender} · ${patient.ageDisplay}${patient.bloodType != null ? ' · ${patient.bloodType}' : ''}',
        style: TextStyle(fontSize: 12, color: AppTheme.gray600),
      ),
      trailing: patient.hasCriticalAllergies
          ? Tooltip(
              message: 'Critical allergies',
              child: Icon(Icons.warning,
                  size: 18, color: AppTheme.errorColor),
            )
          : null,
      onTap: () {
        context.read<PatientProvider>().setSelectedPatient(patient);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PatientListScreen()),
        );
      },
    );
  }
}

class _EmptyPatientsPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(Icons.people_outline, size: 48, color: AppTheme.gray600),
          const SizedBox(height: 12),
          Text('No patients yet',
              style: TextStyle(color: AppTheme.gray600, fontSize: 14)),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PatientListScreen()),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Add First Patient'),
          ),
        ],
      ),
    );
  }
}

// ── Subscription Card (unchanged from Phase 1) ────────────────────────────────

class _SubscriptionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionProvider>(
      builder: (context, sub, _) {
        final trialStatus = sub.trialStatus;
        if (trialStatus == null) return const SizedBox.shrink();

        final onTrial = trialStatus.onTrial;
        final daysRemaining = trialStatus.trialDaysRemaining;

        return Card(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: onTrial
                    ? [
                        AppTheme.warningColor.withValues(alpha: 0.1),
                        AppTheme.warningColor.withValues(alpha: 0.05),
                      ]
                    : [
                        AppTheme.successColor.withValues(alpha: 0.1),
                        AppTheme.successColor.withValues(alpha: 0.05),
                      ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(onTrial ? Icons.schedule : Icons.check_circle,
                      color: onTrial
                          ? AppTheme.warningColor
                          : AppTheme.successColor),
                  const SizedBox(width: 8),
                  const Text('Subscription',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ]),
                const Divider(height: 16),
                _InfoRow('Status', onTrial ? 'Free Trial' : 'Active',
                    valueColor: onTrial
                        ? AppTheme.warningColor
                        : AppTheme.successColor),
                if (onTrial) ...[
                  const SizedBox(height: 8),
                  _InfoRow('Days Remaining', '$daysRemaining',
                      valueColor: daysRemaining <= 7
                          ? AppTheme.errorColor
                          : AppTheme.warningColor),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context)
                          .pushNamed('/subscription/upgrade'),
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

class _ProviderInfoCard extends StatelessWidget {
  final dynamic provider;
  const _ProviderInfoCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.person, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              const Text('Provider Information',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
            const Divider(height: 24),
            _InfoRow('Name', provider.fullName),
            const SizedBox(height: 12),
            _InfoRow(
              'Type',
              AppConfig.providerTypeNames[provider.providerType] ??
                  provider.providerType,
            ),
            if (provider.specialization?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              _InfoRow('Specialization', provider.specialization!),
            ],
            const SizedBox(height: 12),
            _InfoRow('License', provider.licenseNumber),
            const SizedBox(height: 12),
            _InfoRow('Phone', provider.phone),
          ],
        ),
      ),
    );
  }
}

class _OrganizationCard extends StatelessWidget {
  final dynamic org;
  const _OrganizationCard({required this.org});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.business, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              const Text('Organization',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
            const Divider(height: 24),
            _InfoRow('Name', org.name),
            const SizedBox(height: 12),
            _InfoRow('Type',
                AppConfig.organizationTypeNames[org.type] ?? org.type),
            const SizedBox(height: 12),
            _InfoRow('Address', org.address),
            const SizedBox(height: 12),
            _InfoRow('Phone', org.phone ?? '—'),
            const SizedBox(height: 12),
            _InfoRow('Email', org.email ?? '—'),
          ],
        ),
      ),
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────

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
            Text(
              value,
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: color),
            ),
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
          child: Text(
            value,
            style: TextStyle(
                fontWeight: FontWeight.w600, color: valueColor),
          ),
        ),
      ],
    );
  }
}