import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_colors.dart';
import '../../core/api/api_client.dart';
import '../../core/platform.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/repositories/organization_repository.dart';
import '../auth/screens/login_screen.dart';
import '../organization/screens/organization_profile_screen.dart';
import '../providers/screens/provider_invitation_screen.dart';
import '../profile/screens/staff_profile_screen.dart';
import '../reporting/screens/reporting_screen.dart';
import '../subscription/screens/subscription_details_screen.dart';

class OrgAdminMoreScreen extends StatelessWidget {
  const OrgAdminMoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return kIsIOS ? const _IOSMoreScreen() : const _AndroidMoreScreen();
  }
}

// ── iOS ──────────────────────────────────────────────────────────────────────

class _IOSMoreScreen extends StatelessWidget {
  const _IOSMoreScreen();

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('More')),
      child: SafeArea(
        child: ListView(
          children: [
            CupertinoListSection.insetGrouped(
              header: Text(
                'Admin',
                style: TextStyle(
                    color: CupertinoColors.systemOrange.resolveFrom(context)),
              ),
              children: [
                CupertinoListTile(
                  leading: const Icon(CupertinoIcons.building_2_fill,
                      color: CupertinoColors.systemOrange),
                  title: const Text('Organisation Profile'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => _push(
                    context,
                    OrganizationProfileScreen(
                      repository: OrganizationRepository(
                          apiClient: context.read<ApiClient>()),
                    ),
                  ),
                ),
                CupertinoListTile(
                  leading: const Icon(CupertinoIcons.mail,
                      color: CupertinoColors.systemOrange),
                  title: const Text('Invite Staff'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => _push(context, const ProviderInvitationScreen()),
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              header: const Text('Account'),
              children: [
                CupertinoListTile(
                  leading: const Icon(CupertinoIcons.creditcard,
                      color: AppColors.primary),
                  title: const Text('Subscription & Billing'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () =>
                      _push(context, const SubscriptionDetailsScreen()),
                ),
                CupertinoListTile(
                  leading: const Icon(CupertinoIcons.chart_bar_square,
                      color: AppColors.primary),
                  title: const Text('Reporting & Compliance'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => _push(context, const ReportingScreen()),
                ),
                CupertinoListTile(
                  leading: const Icon(CupertinoIcons.person_crop_square,
                      color: AppColors.primary),
                  title: const Text('Staff Profile'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => _push(context, const StaffProfileScreen()),
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              children: [
                CupertinoListTile(
                  leading: const Icon(CupertinoIcons.square_arrow_left,
                      color: AppColors.error),
                  title: const Text('Sign Out',
                      style: TextStyle(color: AppColors.error)),
                  onTap: () => _confirmSignOut(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context)
        .push(CupertinoPageRoute(builder: (_) => screen));
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<AuthProvider>().logout();
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          CupertinoPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    }
  }
}

// ── Android ──────────────────────────────────────────────────────────────────

class _AndroidMoreScreen extends StatelessWidget {
  const _AndroidMoreScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        children: [
          _SectionHeader(label: 'Admin', color: Colors.orange.shade700),
          ListTile(
            leading:
                Icon(Icons.business, color: Colors.orange.shade700),
            title: const Text('Organisation Profile'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _push(
              context,
              OrganizationProfileScreen(
                repository: OrganizationRepository(
                    apiClient: context.read<ApiClient>()),
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.mail_outline, color: Colors.orange.shade700),
            title: const Text('Invite Staff'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _push(context, const ProviderInvitationScreen()),
          ),
          const Divider(),
          const _SectionHeader(label: 'Account'),
          ListTile(
            leading: const Icon(Icons.credit_card_outlined),
            title: const Text('Subscription & Billing'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _push(context, const SubscriptionDetailsScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart_outlined),
            title: const Text('Reporting & Compliance'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _push(context, const ReportingScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Staff Profile'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _push(context, const StaffProfileScreen()),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title: const Text('Sign Out',
                style: TextStyle(color: AppColors.error)),
            onTap: () => _confirmSignOut(context),
          ),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
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
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
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

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color? color;

  const _SectionHeader({required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: color ?? Colors.grey.shade600,
        ),
      ),
    );
  }
}
