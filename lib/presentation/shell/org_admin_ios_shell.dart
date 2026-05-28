import 'package:flutter/cupertino.dart';

import '../organization/screens/org_dashboard_screen.dart';
import '../facilities/screens/facilities_list_screen.dart';
import '../staff/screens/staff_management_screen.dart';
import '../more/org_admin_more_screen.dart';
import '../../core/api/api_client.dart';
import '../../data/repositories/staff_repository.dart';
import 'package:provider/provider.dart';

/// CupertinoTabScaffold for org admin users.
/// Four tabs: Overview · Facilities · Staff · More
/// Uses systemOrange tint to distinguish from the clinical shell.
class OrgAdminIOSShell extends StatelessWidget {
  const OrgAdminIOSShell({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        activeColor: CupertinoColors.systemOrange,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.building_2_fill),
            label: 'Overview',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.house_fill),
            label: 'Facilities',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person_2_fill),
            label: 'Staff',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.ellipsis_circle),
            label: 'More',
          ),
        ],
      ),
      tabBuilder: (context, index) => CupertinoTabView(
        builder: (_) => switch (index) {
          0 => const OrgDashboardScreen(),
          1 => const FacilitiesListScreen(),
          2 => StaffManagementScreen(
              repository: StaffRepository(
                  apiClient: context.read<ApiClient>())),
          _ => const OrgAdminMoreScreen(),
        },
      ),
    );
  }
}
