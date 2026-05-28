import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../core/api/api_client.dart';
import '../../data/repositories/staff_repository.dart';
import '../facilities/screens/facilities_list_screen.dart';
import '../more/org_admin_more_screen.dart';
import '../organization/screens/org_dashboard_screen.dart';
import '../staff/screens/staff_management_screen.dart';

/// Android bottom-nav shell for org admin users.
/// Four tabs: Overview · Facilities · Staff · More — no drawer.
class OrgAdminAndroidShell extends StatefulWidget {
  const OrgAdminAndroidShell({super.key});

  @override
  State<OrgAdminAndroidShell> createState() => _OrgAdminAndroidShellState();
}

class _OrgAdminAndroidShellState extends State<OrgAdminAndroidShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      const OrgDashboardScreen(),
      const FacilitiesListScreen(),
      StaffManagementScreen(
          repository: StaffRepository(apiClient: context.read<ApiClient>())),
      const OrgAdminMoreScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.business_center_outlined),
            activeIcon: Icon(Icons.business_center),
            label: 'Overview',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.apartment_outlined),
            activeIcon: Icon(Icons.apartment),
            label: 'Facilities',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group_outlined),
            activeIcon: Icon(Icons.group),
            label: 'Staff',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
      ),
    );
  }
}
