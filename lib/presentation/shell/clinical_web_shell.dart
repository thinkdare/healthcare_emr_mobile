import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/providers/intra_grant_provider.dart';
import '../../data/providers/referral_provider.dart';
import '../../data/providers/subscription_provider.dart';
import '../../data/providers/sync_provider.dart';
import '../access_grants/screens/access_grants_screen.dart';
import '../auth/screens/login_screen.dart';
import '../dashboard/screens/provider_dashboard_screen.dart';
import '../emergency_access/screens/emergency_access_screen.dart';
import '../patients/screens/patient_list_screen.dart';
import '../profile/screens/staff_profile_screen.dart';
import '../referrals/screens/referrals_screen.dart';
import '../roster/screens/roster_screen.dart';
import '../subscription/screens/subscription_details_screen.dart';
import '../sync/screens/sync_screen.dart';
import '../sync/widgets/sync_banner.dart';

/// Web shell for clinical staff: collapsible NavigationRail sidebar + IndexedStack.
/// Four primary destinations: Dashboard · Patients · Roster · Access Grants.
class ClinicalWebShell extends StatefulWidget {
  const ClinicalWebShell({super.key});

  @override
  State<ClinicalWebShell> createState() => _ClinicalWebShellState();
}

class _ClinicalWebShellState extends State<ClinicalWebShell> {
  int _selectedIndex = 0;
  bool _sidebarExpanded = true;

  // Index 0 = Dashboard matches Android's home-screen behaviour.
  static const _screens = [
    ProviderDashboardScreen(),
    PatientListScreen(),
    RosterScreen(),
    AccessGrantsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const SyncBanner(),
          Expanded(
            child: Row(
              children: [
                _ClinicalSidebar(
                  selectedIndex: _selectedIndex,
                  expanded: _sidebarExpanded,
                  onToggle: () =>
                      setState(() => _sidebarExpanded = !_sidebarExpanded),
                  onDestinationSelected: (i) =>
                      setState(() => _selectedIndex = i),
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: _screens,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sidebar ──────────────────────────────────────────────────────────────────

class _ClinicalSidebar extends StatelessWidget {
  final int selectedIndex;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<int> onDestinationSelected;

  const _ClinicalSidebar({
    required this.selectedIndex,
    required this.expanded,
    required this.onToggle,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          SizedBox(
            height: 56,
            child: Row(
              children: [
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(expanded ? Icons.menu_open : Icons.menu),
                  onPressed: onToggle,
                  tooltip: expanded ? 'Collapse' : 'Expand',
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer<IntraGrantProvider>(
              builder: (context, intra, _) => NavigationRail(
                extended: expanded,
                selectedIndex: selectedIndex,
                onDestinationSelected: onDestinationSelected,
                backgroundColor: Colors.white,
                selectedIconTheme:
                    IconThemeData(color: AppTheme.primaryColor),
                selectedLabelTextStyle: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600),
                destinations: [
                  const NavigationRailDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard),
                    label: Text('Dashboard'),
                  ),
                  const NavigationRailDestination(
                    icon: Icon(Icons.people_outline),
                    selectedIcon: Icon(Icons.people),
                    label: Text('Patients'),
                  ),
                  const NavigationRailDestination(
                    icon: Icon(Icons.list_alt_outlined),
                    selectedIcon: Icon(Icons.list_alt),
                    label: Text('Roster'),
                  ),
                  NavigationRailDestination(
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.shield_outlined),
                        if (intra.pendingIncomingCount > 0)
                          Positioned(
                            top: -4,
                            right: -6,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    selectedIcon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.shield),
                        if (intra.pendingIncomingCount > 0)
                          Positioned(
                            top: -4,
                            right: -6,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    label: const Text('Access'),
                  ),
                ],
              ),
            ),
          ),
          ClipRect(
            child: _SidebarFooter(expanded: expanded),
          ),
        ],
      ),
    );
  }
}

// ── Footer ───────────────────────────────────────────────────────────────────

class _SidebarFooter extends StatelessWidget {
  final bool expanded;

  const _SidebarFooter({required this.expanded});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final sub = context.watch<SubscriptionProvider>();

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          if (auth.canEmergencyAccess && sub.isProfessionalOrHigher == true)
            _FooterItem(
              icon: Icons.emergency_outlined,
              label: 'Emergency Access',
              expanded: expanded,
              color: Colors.red,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => const EmergencyAccessScreen()),
              ),
            ),
          if (sub.isProfessionalOrHigher == true)
            Consumer<ReferralProvider>(
              builder: (context, referrals, _) => _FooterItem(
                icon: Icons.swap_horiz_outlined,
                label: referrals.pendingActionCount > 0
                    ? 'Referrals (${referrals.pendingActionCount})'
                    : 'Referrals',
                expanded: expanded,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const ReferralsScreen()),
                ),
              ),
            ),
          Consumer<SyncProvider>(
            builder: (context, sync, _) => _FooterItem(
              icon: sync.hasPendingConflicts
                  ? Icons.sync_problem_outlined
                  : Icons.sync_outlined,
              label: sync.hasPendingConflicts
                  ? 'Sync (${sync.pendingConflicts})'
                  : 'Sync',
              expanded: expanded,
              color: sync.hasPendingConflicts ? Colors.orange.shade700 : null,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => const SyncScreen()),
              ),
            ),
          ),
          _FooterItem(
            icon: Icons.credit_card_outlined,
            label: 'Subscription',
            expanded: expanded,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => const SubscriptionDetailsScreen()),
            ),
          ),
          _FooterItem(
            icon: Icons.person_outline,
            label: 'Profile',
            expanded: expanded,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => const StaffProfileScreen()),
            ),
          ),
          _FooterItem(
            icon: Icons.logout,
            label: 'Sign Out',
            expanded: expanded,
            color: Colors.red,
            onTap: () => _confirmSignOut(context),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<AuthProvider>().logout();
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    }
  }
}

// ── Footer item ───────────────────────────────────────────────────────────────

class _FooterItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool expanded;
  final VoidCallback onTap;
  final Color? color;

  const _FooterItem({
    required this.icon,
    required this.label,
    required this.expanded,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Colors.grey.shade700;

    if (expanded) {
      return TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: effectiveColor),
        label: Text(label, style: TextStyle(color: effectiveColor)),
        style: TextButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          minimumSize: const Size(double.infinity, 0),
        ),
      );
    }

    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: effectiveColor),
      tooltip: label,
    );
  }
}
