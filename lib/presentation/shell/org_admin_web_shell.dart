import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../core/api/api_client.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/repositories/organization_repository.dart';
import '../../data/repositories/staff_repository.dart';
import '../auth/screens/login_screen.dart';
import '../facilities/screens/facilities_list_screen.dart';
import '../organization/screens/org_dashboard_screen.dart';
import '../organization/screens/organization_profile_screen.dart';
import '../providers/screens/provider_invitation_screen.dart';
import '../reporting/screens/reporting_screen.dart';
import '../staff/screens/staff_management_screen.dart';
import '../subscription/screens/subscription_details_screen.dart';

/// Web shell for org admin users: collapsible NavigationRail sidebar + IndexedStack.
class OrgAdminWebShell extends StatefulWidget {
  const OrgAdminWebShell({super.key});

  @override
  State<OrgAdminWebShell> createState() => _OrgAdminWebShellState();
}

class _OrgAdminWebShellState extends State<OrgAdminWebShell> {
  int _selectedIndex = 0;
  bool _sidebarExpanded = true;

  final _screens = const [
    OrgDashboardScreen(),
    FacilitiesListScreen(),
    _StaffTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _OrgAdminSidebar(
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
    );
  }
}

// ── Sidebar ──────────────────────────────────────────────────────────────────

class _OrgAdminSidebar extends StatelessWidget {
  final int selectedIndex;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<int> onDestinationSelected;

  const _OrgAdminSidebar({
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
          // Toggle button at top
          SizedBox(
            height: 56,
            child: Row(
              children: [
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                      expanded ? Icons.menu_open : Icons.menu),
                  onPressed: onToggle,
                  tooltip: expanded ? 'Collapse' : 'Expand',
                ),
              ],
            ),
          ),
          // Primary nav destinations
          Expanded(
            child: NavigationRail(
              extended: expanded,
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              backgroundColor: Colors.white,
              selectedIconTheme:
                  IconThemeData(color: AppTheme.primaryColor),
              selectedLabelTextStyle:
                  TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w600),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.business_center_outlined),
                  selectedIcon: Icon(Icons.business_center),
                  label: Text('Overview'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.apartment_outlined),
                  selectedIcon: Icon(Icons.apartment),
                  label: Text('Facilities'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.group_outlined),
                  selectedIcon: Icon(Icons.group),
                  label: Text('Staff'),
                ),
              ],
            ),
          ),
          // Footer actions
          ClipRect(
            child: _SidebarFooter(expanded: expanded),
          ),
        ],
      ),
    );
  }
}

class _SidebarFooter extends StatelessWidget {
  final bool expanded;

  const _SidebarFooter({required this.expanded});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          _FooterItem(
            icon: Icons.business,
            label: 'Organisation',
            expanded: expanded,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => OrganizationProfileScreen(
                  repository: OrganizationRepository(
                      apiClient: context.read<ApiClient>()),
                ),
              ),
            ),
          ),
          _FooterItem(
            icon: Icons.credit_card_outlined,
            label: 'Billing',
            expanded: expanded,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const SubscriptionDetailsScreen()),
            ),
          ),
          _FooterItem(
            icon: Icons.bar_chart_outlined,
            label: 'Reporting',
            expanded: expanded,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ReportingScreen()),
            ),
          ),
          _FooterItem(
            icon: Icons.mail_outline,
            label: 'Invite Staff',
            expanded: expanded,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ProviderInvitationScreen()),
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

// StaffManagementScreen needs a repository injected; wrap it here.
class _StaffTab extends StatelessWidget {
  const _StaffTab();

  @override
  Widget build(BuildContext context) {
    return StaffManagementScreen(
      repository: StaffRepository(apiClient: context.read<ApiClient>()),
    );
  }
}
