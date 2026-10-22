import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/subscription_provider.dart';

/// Loads the plan the signed-in role may read, once, so plan-gated navigation
/// (emergency access, referrals) resolves in shells that do not open the
/// dashboard first. Org admins load the full subscription; staff load the plan
/// summary, since the subscription endpoint is admin-only.
class PlanLoader extends StatefulWidget {
  final Widget child;
  const PlanLoader({super.key, required this.child});

  @override
  State<PlanLoader> createState() => _PlanLoaderState();
}

class _PlanLoaderState extends State<PlanLoader> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final sub = context.read<SubscriptionProvider>();
      final orgId = auth.organizationId;
      if (orgId == null || sub.subLoadState != SubscriptionLoadState.initial) {
        return;
      }
      sub.loadForRole(orgId, isOrgAdmin: auth.isOrgAdmin);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
