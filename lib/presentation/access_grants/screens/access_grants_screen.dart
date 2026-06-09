import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/theme.dart';
import '../../../core/platform.dart';
import '../../../data/models/access_grant_models.dart';
import '../../../data/models/intra_grant_models.dart';
import '../../../data/providers/access_grant_provider.dart';
import '../../../data/providers/intra_grant_provider.dart';
import '../../../data/providers/intra_transfer_provider.dart';
import '../widgets/create_intra_grant_sheet.dart';
import '../widgets/transfer_request_card.dart';
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
    _tabs = TabController(length: 3, vsync: this);
    // Rebuild on swipe so the iOS CupertinoSlidingSegmentedControl stays in sync.
    _tabs.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AccessGrantProvider>().loadGrants();
      context.read<IntraGrantProvider>().loadGrants();
      context.read<IntraTransferProvider>().load();
    });
  }

  void _onTabChanged() {
    if (!_tabs.indexIsChanging) setState(() {});
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
            Consumer<IntraGrantProvider>(
              builder: (context, intra, child) => Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Same Facility'),
                    if (intra.pendingIncomingCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${intra.pendingIncomingCount}',
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
          ],
        ),
      ),
      floatingActionButton: ListenableBuilder(
        listenable: _tabs,
        builder: (context, _) {
          if (_tabs.index == 2) {
            // Same Facility tab — "Ask a Colleague" FAB
            return FloatingActionButton.extended(
              heroTag: 'intra_fab',
              onPressed: () async {
                final intra = context.read<IntraGrantProvider>();
                final created = await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  builder: (_) => const CreateIntraGrantSheet(),
                );
                if (created == true && mounted) intra.loadGrants();
              },
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Ask a Colleague'),
            );
          }
          // Cross-facility tabs — "Request Access" FAB
          return FloatingActionButton.extended(
            heroTag: 'cross_fab',
            onPressed: () async {
              final provider = context.read<AccessGrantProvider>();
              final created = await Navigator.of(context).push<bool>(
                kIsIOS
                    ? CupertinoPageRoute(
                        builder: (_) => const RequestAccessScreen())
                    : MaterialPageRoute(
                        builder: (_) => const RequestAccessScreen()),
              );
              if (created == true && mounted) provider.loadGrants();
            },
            icon: const Icon(Icons.add),
            label: const Text('Request Access'),
          );
        },
      ),
      body: Column(
        children: [
          if (kIsIOS)
            Consumer2<AccessGrantProvider, IntraGrantProvider>(
              builder: (_, cross, intra, child) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: CupertinoSlidingSegmentedControl<int>(
                  groupValue: _tabs.index,
                  onValueChanged: (i) {
                    if (i != null) _tabs.animateTo(i);
                  },
                  children: {
                    0: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      child: Text(
                        cross.pendingCount > 0
                            ? 'Pending (${cross.pendingCount})'
                            : 'Pending',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    1: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text('My Requests',
                          style: TextStyle(fontSize: 13)),
                    ),
                    2: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      child: Text(
                        intra.pendingIncomingCount > 0
                            ? 'Same Facility (${intra.pendingIncomingCount})'
                            : 'Same Facility',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  },
                ),
              ),
            ),
          Consumer<AccessGrantProvider>(
            builder: (context, provider, child) => provider.error != null
                ? _ErrorBanner(
                    message: provider.error!,
                    onDismiss: provider.clearError)
                : const SizedBox.shrink(),
          ),
          Consumer<IntraGrantProvider>(
            builder: (context, intra, child) => intra.error != null
                ? _ErrorBanner(
                    message: intra.error!,
                    onDismiss: intra.clearError)
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: Consumer2<AccessGrantProvider, IntraGrantProvider>(
              builder: (context, cross, intra, _) {
                if (cross.isLoading || intra.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                return TabBarView(
                  controller: _tabs,
                  children: [
                    _PendingApprovalTab(grants: cross.pendingApproval),
                    _MyRequestsTab(grants: cross.myRequests),
                    _SameFacilityTab(
                      incoming: intra.incoming,
                      outgoing: intra.outgoing,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
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
          AdaptiveTextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          AdaptiveFilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
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
        if (ok) {
          showAdaptiveToast(context, 'Access granted.', type: ToastType.success);
        } else {
          showAdaptiveToast(context, context.read<AccessGrantProvider>().error ?? 'Failed', type: ToastType.error);
        }
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
          AdaptiveTextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          AdaptiveFilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(true);
              }
            },
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
        showAdaptiveToast(
          context,
          ok ? 'Access denied.' : context.read<AccessGrantProvider>().error ?? 'Failed',
          type: ok ? ToastType.info : ToastType.error,
        );
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
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
          AdaptiveTextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          AdaptiveFilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(true);
              }
            },
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
        showAdaptiveToast(
          context,
          ok
              ? (isPending ? 'Request cancelled.' : 'Access revoked.')
              : context.read<AccessGrantProvider>().error ?? 'Failed',
          type: ok ? ToastType.info : ToastType.error,
        );
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

// ══════════════════════════════════════════════════════════════════════════════
// Same Facility tab
// ══════════════════════════════════════════════════════════════════════════════

class _SameFacilityTab extends StatelessWidget {
  final List<IntraAccessGrantModel> incoming;
  final List<IntraAccessGrantModel> outgoing;

  const _SameFacilityTab({required this.incoming, required this.outgoing});

  @override
  Widget build(BuildContext context) {
    final pendingIncoming = incoming.where((g) => g.isPending).toList();
    final otherIncoming   = incoming.where((g) => !g.isPending).toList();

    return Consumer<IntraTransferProvider>(
      builder: (context, transferProvider, child) {
        final pendingTransfers = transferProvider.pendingIncoming;
        final hasContent = incoming.isNotEmpty || outgoing.isNotEmpty || pendingTransfers.isNotEmpty;

        if (!hasContent) {
          return _EmptyState(
            icon: Icons.people_outline,
            message: 'No consultation requests',
            subtitle: "Tap 'Ask a Colleague' to request a clinical opinion.",
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await context.read<IntraGrantProvider>().loadGrants();
            if (context.mounted) await context.read<IntraTransferProvider>().load();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              if (pendingTransfers.isNotEmpty) ...[
                _SectionHeader('Transfer requests', Colors.orange.shade700),
                ...pendingTransfers.map((t) => TransferRequestCard(transfer: t)),
                const SizedBox(height: 8),
              ],
              if (pendingIncoming.isNotEmpty) ...[
                _SectionHeader('Needs your response', AppTheme.warningColor),
                ...pendingIncoming.map((g) => _IncomingGrantCard(grant: g)),
                const SizedBox(height: 8),
              ],
              if (outgoing.isNotEmpty) ...[
                _SectionHeader('My requests', AppTheme.primaryColor),
                ...outgoing.map((g) => _OutgoingGrantCard(grant: g)),
                const SizedBox(height: 8),
              ],
              if (otherIncoming.isNotEmpty) ...[
                _SectionHeader('Handled', AppTheme.gray600),
                ...otherIncoming.map((g) => _IncomingGrantCard(grant: g)),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  const _SectionHeader(this.title, this.color);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title.toUpperCase(),
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.6)),
      );
}

// ── Incoming card (Doctor B's perspective) ────────────────────────────────────

class _IncomingGrantCard extends StatelessWidget {
  final IntraAccessGrantModel grant;
  const _IncomingGrantCard({required this.grant});

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
                const Icon(Icons.help_outline, size: 18, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    grant.patientName ?? 'Patient',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
                _IntraStatusChip(status: grant.status),
              ],
            ),
            if (grant.patientMrn != null) ...[
              const SizedBox(height: 2),
              Text('MRN: ${grant.patientMrn}',
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
            const Divider(height: 20),
            Text(grant.question,
                style: const TextStyle(fontSize: 13, height: 1.4)),
            const SizedBox(height: 6),
            Text(_formatDate(grant.createdAt),
                style:
                    TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            if (grant.hasResponse) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.reply, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(grant.response!,
                          style: const TextStyle(
                              fontSize: 13, height: 1.4)),
                    ),
                  ],
                ),
              ),
            ],
            if (grant.isPending) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorColor,
                        side: const BorderSide(color: AppTheme.errorColor),
                      ),
                      onPressed: () =>
                          _showDeclineDialog(context, grant.id),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AdaptiveFilledButton(
                      onPressed: () =>
                          _showAcceptOptions(context, grant),
                      child: const Text('Accept'),
                    ),
                  ),
                ],
              ),
            ],
            if (grant.isAccepted) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: AdaptiveFilledButton(
                  onPressed: () => _showCompleteDialog(context, grant.id),
                  child: const Text('Close with response'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showAcceptOptions(
      BuildContext context, IntraAccessGrantModel grant) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Accept consultation?'),
        content: const Text(
            'You will gain view access to the patient record until you close the consultation.'),
        actions: [
          AdaptiveTextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          AdaptiveFilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final ok = await context.read<IntraGrantProvider>().accept(grant.id);
      if (context.mounted) {
        showAdaptiveToast(context,
            ok ? 'Request accepted.' : 'Failed to accept.',
            type: ok ? ToastType.success : ToastType.error);
      }
    }
  }

  Future<void> _showDeclineDialog(BuildContext context, String id) async {
    final ctrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Decline & respond'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Your response *',
              hintText:
                  'e.g. The current dose is at the safe ceiling for their renal function — do not increase.',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            validator: (v) => (v == null || v.trim().length < 5)
                ? 'Please enter a response (min 5 characters)'
                : null,
          ),
        ),
        actions: [
          AdaptiveTextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          AdaptiveFilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: const Text('Send & decline'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final ok = await context
          .read<IntraGrantProvider>()
          .decline(id, ctrl.text.trim());
      if (context.mounted) {
        showAdaptiveToast(
          context,
          ok ? 'Response sent.' : context.read<IntraGrantProvider>().error ?? 'Failed',
          type: ok ? ToastType.info : ToastType.error,
        );
      }
    }
    ctrl.dispose();
  }

  Future<void> _showCompleteDialog(BuildContext context, String id) async {
    final ctrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close consultation'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Your response *',
              hintText:
                  'e.g. Reviewed — digoxin level within range. Safe to increase bisoprolol to 7.5 mg. Monitor for bradycardia.',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            validator: (v) => (v == null || v.trim().length < 5)
                ? 'Please enter a response (min 5 characters)'
                : null,
          ),
        ),
        actions: [
          AdaptiveTextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          AdaptiveFilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: const Text('Close & send'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final ok = await context
          .read<IntraGrantProvider>()
          .complete(id, ctrl.text.trim());
      if (context.mounted) {
        showAdaptiveToast(
          context,
          ok ? 'Consultation closed.' : context.read<IntraGrantProvider>().error ?? 'Failed',
          type: ok ? ToastType.success : ToastType.error,
        );
      }
    }
    ctrl.dispose();
  }
}

// ── Outgoing card (Doctor A's perspective) ────────────────────────────────────

class _OutgoingGrantCard extends StatelessWidget {
  final IntraAccessGrantModel grant;
  const _OutgoingGrantCard({required this.grant});

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
                const Icon(Icons.send_outlined,
                    size: 18, color: Colors.indigo),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    grant.patientName ?? 'Patient',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
                _IntraStatusChip(status: grant.status),
              ],
            ),
            const Divider(height: 20),
            Text(grant.question,
                style: const TextStyle(fontSize: 13, height: 1.4)),
            const SizedBox(height: 6),
            Text('Sent ${_formatDate(grant.createdAt)}',
                style:
                    TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            // Response note
            if (grant.hasResponse) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: grant.isDeclined
                      ? Colors.orange.shade50
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: grant.isDeclined
                        ? Colors.orange.shade200
                        : Colors.green.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          grant.isDeclined
                              ? Icons.reply
                              : Icons.check_circle_outline,
                          size: 14,
                          color: grant.isDeclined
                              ? Colors.orange.shade700
                              : Colors.green.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          grant.isDeclined ? 'Response' : 'Consultation response',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: grant.isDeclined
                                  ? Colors.orange.shade700
                                  : Colors.green.shade700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(grant.response!,
                        style:
                            const TextStyle(fontSize: 13, height: 1.4)),
                    if (grant.respondedAt != null) ...[
                      const SizedBox(height: 4),
                      Text(_formatDate(grant.respondedAt!),
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600)),
                    ],
                  ],
                ),
              ),
            ] else if (grant.isPending || grant.isAccepted) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.grey.shade400),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    grant.isPending
                        ? 'Waiting for response…'
                        : 'Colleague is reviewing…',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
            // Cancel button
            if (grant.isPending) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorColor,
                    side: const BorderSide(color: AppTheme.errorColor),
                  ),
                  onPressed: () => _confirmCancel(context, grant.id),
                  child: const Text('Cancel request'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel request?'),
        content: const Text('Your consultation request will be withdrawn.'),
        actions: [
          AdaptiveTextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Keep')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Cancel request'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final ok =
          await context.read<IntraGrantProvider>().cancel(id);
      if (context.mounted) {
        showAdaptiveToast(
          context,
          ok ? 'Request cancelled.' : context.read<IntraGrantProvider>().error ?? 'Failed',
          type: ok ? ToastType.info : ToastType.error,
        );
      }
    }
  }
}

class _IntraStatusChip extends StatelessWidget {
  final String status;
  const _IntraStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'pending'   => (AppTheme.warningColor,  'Pending'),
      'accepted'  => (Colors.blue,            'In review'),
      'declined'  => (AppTheme.errorColor,    'Declined'),
      'completed' => (AppTheme.successColor,  'Completed'),
      'cancelled' => (AppTheme.gray600,       'Cancelled'),
      _           => (AppTheme.gray600,       status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
