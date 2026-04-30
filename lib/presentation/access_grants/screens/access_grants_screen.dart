import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/theme.dart';
import '../../../core/platform.dart';
import '../../../data/models/access_grant_models.dart';
import '../../../data/providers/access_grant_provider.dart';
import 'request_access_screen.dart';

class AccessGrantsScreen extends StatefulWidget {
  const AccessGrantsScreen({super.key});

  @override
  State<AccessGrantsScreen> createState() => _AccessGrantsScreenState();
}

class _AccessGrantsScreenState extends State<AccessGrantsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AccessGrantProvider>().loadGrants();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: kIsIOS
          ? CupertinoNavigationBar(
              middle: const Text('Access Grants'),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () =>
                    context.read<AccessGrantProvider>().loadGrants(),
                child: const Icon(CupertinoIcons.refresh),
              ),
            )
          : AppBar(
              title: const Text('Access Grants'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                  onPressed: () =>
                      context.read<AccessGrantProvider>().loadGrants(),
                ),
              ],
              bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(
              child: Consumer<AccessGrantProvider>(
                builder: (context, p, child) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Pending Approval'),
                    if (p.pendingCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${p.pendingCount}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Tab(text: 'My Requests'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final provider = context.read<AccessGrantProvider>();
          final created = await Navigator.of(context).push<bool>(
            kIsIOS
                ? CupertinoPageRoute(
                    builder: (_) => const RequestAccessScreen())
                : MaterialPageRoute(
                    builder: (_) => const RequestAccessScreen()),
          );
          if (created == true && mounted) {
            provider.loadGrants();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Request Access'),
      ),
      body: Consumer<AccessGrantProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              if (provider.error != null)
                _ErrorBanner(
                  message: provider.error!,
                  onDismiss: provider.clearError,
                ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _PendingApprovalTab(grants: provider.pendingApproval),
                    _MyRequestsTab(grants: provider.myRequests),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Pending Approval Tab ──────────────────────────────────────────────────────

class _PendingApprovalTab extends StatelessWidget {
  final List<AccessGrantModel> grants;
  const _PendingApprovalTab({required this.grants});

  @override
  Widget build(BuildContext context) {
    if (grants.isEmpty) {
      return _EmptyState(
        icon: Icons.check_circle_outline,
        message: 'No pending approvals',
        subtitle: 'Access requests from other providers will appear here',
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<AccessGrantProvider>().loadGrants(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: grants.length,
        itemBuilder: (_, i) => _PendingGrantCard(grant: grants[i]),
      ),
    );
  }
}

class _PendingGrantCard extends StatelessWidget {
  final AccessGrantModel grant;
  const _PendingGrantCard({required this.grant});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield_outlined, color: AppTheme.warningColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Request from ${grant.requestingTenantName}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                _StatusChip(status: grant.status),
              ],
            ),
            const Divider(height: 20),
            _InfoRow('Access level', grant.accessLevelDisplay),
            if (grant.accessibleDataTypes.isNotEmpty) ...[
              const SizedBox(height: 8),
              _InfoRow(
                'Data types',
                grant.accessibleDataTypes
                    .map((t) => t.replaceAll('_', ' '))
                    .join(', '),
              ),
            ],
            if (grant.requestReason != null) ...[
              const SizedBox(height: 8),
              _InfoRow('Reason', grant.requestReason!),
            ],
            if (grant.expiresAt != null) ...[
              const SizedBox(height: 8),
              _InfoRow('Expires', _formatDate(grant.expiresAt!)),
            ],
            const SizedBox(height: 8),
            _InfoRow('Requested', _formatDate(grant.createdAt)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Deny'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorColor,
                      side: const BorderSide(color: AppTheme.errorColor),
                    ),
                    onPressed: () => _showDenyDialog(context, grant.id),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AdaptiveFilledButton(
                    icon: const Icon(Icons.check, size: 18),
                    onPressed: () => _showApproveDialog(context, grant.id),
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showApproveDialog(BuildContext context, String id) async {
    final notesCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Access'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Approve this access request?'),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Any notes for the requester…',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successColor),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final ok = await context
          .read<AccessGrantProvider>()
          .approve(id, notes: notesCtrl.text.trim());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok
              ? 'Access granted.'
              : context.read<AccessGrantProvider>().error ?? 'Failed'),
          backgroundColor: ok ? AppTheme.successColor : AppTheme.errorColor,
        ));
      }
    }
    notesCtrl.dispose();
  }

  Future<void> _showDenyDialog(BuildContext context, String id) async {
    final reasonCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deny Access'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: reasonCtrl,
            decoration: const InputDecoration(
              labelText: 'Reason *',
              hintText: 'Explain why this request is being denied…',
            ),
            maxLines: 3,
            validator: (v) => (v == null || v.trim().length < 10)
                ? 'Reason must be at least 10 characters'
                : null,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(true);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor),
            child: const Text('Deny'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final ok = await context
          .read<AccessGrantProvider>()
          .deny(id, reasonCtrl.text.trim());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok
              ? 'Access denied.'
              : context.read<AccessGrantProvider>().error ?? 'Failed'),
          backgroundColor: ok ? AppTheme.gray600 : AppTheme.errorColor,
        ));
      }
    }
    reasonCtrl.dispose();
  }
}

// ── My Requests Tab ───────────────────────────────────────────────────────────

class _MyRequestsTab extends StatelessWidget {
  final List<AccessGrantModel> grants;
  const _MyRequestsTab({required this.grants});

  @override
  Widget build(BuildContext context) {
    if (grants.isEmpty) {
      return _EmptyState(
        icon: Icons.send_outlined,
        message: 'No access requests',
        subtitle: "Tap '+' to request access to a patient at another facility",
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<AccessGrantProvider>().loadGrants(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: grants.length,
        itemBuilder: (_, i) => _MyGrantCard(grant: grants[i]),
      ),
    );
  }
}

class _MyGrantCard extends StatelessWidget {
  final AccessGrantModel grant;
  const _MyGrantCard({required this.grant});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock_open_outlined, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    grant.grantingTenantName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                _StatusChip(status: grant.status),
              ],
            ),
            const Divider(height: 20),
            _InfoRow('Access level', grant.accessLevelDisplay),
            const SizedBox(height: 8),
            _InfoRow('Requested', _formatDate(grant.createdAt)),
            if (grant.isApproved && grant.grantedAt != null) ...[
              const SizedBox(height: 8),
              _InfoRow('Approved', _formatDate(grant.grantedAt!)),
            ],
            if (grant.expiresAt != null) ...[
              const SizedBox(height: 8),
              _InfoRow(
                'Expires',
                _formatDate(grant.expiresAt!),
                valueColor: grant.isExpired ? AppTheme.errorColor : null,
              ),
            ],
            if (grant.autoApproved) ...[
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.auto_awesome, size: 14, color: AppTheme.successColor),
                const SizedBox(width: 4),
                Text('Auto-approved (same organisation)',
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.successColor)),
              ]),
            ],
            // Revoke button — only for pending or active grants
            if (grant.isPending || grant.isActive) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: Text(
                      grant.isPending ? 'Cancel Request' : 'Revoke Access'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorColor,
                    side: const BorderSide(color: AppTheme.errorColor),
                  ),
                  onPressed: () => _showRevokeDialog(context, grant.id,
                      isPending: grant.isPending),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showRevokeDialog(BuildContext context, String id,
      {required bool isPending}) async {
    final reasonCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isPending ? 'Cancel Request' : 'Revoke Access'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: reasonCtrl,
            decoration: InputDecoration(
              labelText: 'Reason *',
              hintText: isPending
                  ? 'Why are you cancelling this request?'
                  : 'Why are you revoking access?',
            ),
            maxLines: 2,
            validator: (v) => (v == null || v.trim().length < 10)
                ? 'Reason must be at least 10 characters'
                : null,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(true);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final ok = await context
          .read<AccessGrantProvider>()
          .revoke(id, reasonCtrl.text.trim());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok
              ? (isPending ? 'Request cancelled.' : 'Access revoked.')
              : context.read<AccessGrantProvider>().error ?? 'Failed'),
          backgroundColor: ok ? AppTheme.gray600 : AppTheme.errorColor,
        ));
      }
    }
    reasonCtrl.dispose();
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'approved' => (AppTheme.successColor, 'Approved'),
      'pending'  => (AppTheme.warningColor, 'Pending'),
      'denied'   => (AppTheme.errorColor,   'Denied'),
      'revoked'  => (AppTheme.gray600,      'Revoked'),
      _          => (AppTheme.gray600,      status),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: color),
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
          width: 90,
          child: Text('$label:',
              style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.gray600,
                  fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: valueColor)),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String subtitle;
  const _EmptyState(
      {required this.icon, required this.message, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 64,
                color: AppTheme.gray600.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(message,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(subtitle,
                style: TextStyle(fontSize: 13, color: AppTheme.gray600),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;
  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.errorColor.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: AppTheme.errorColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.errorColor)),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: AppTheme.errorColor),
            onPressed: onDismiss,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime dt) =>
    '${dt.day.toString().padLeft(2, '0')}/'
    '${dt.month.toString().padLeft(2, '0')}/'
    '${dt.year}';
