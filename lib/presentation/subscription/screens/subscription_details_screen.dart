import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/platform.dart';
import 'package:provider/provider.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/subscription_provider.dart';
import '../../../config/theme.dart';

class SubscriptionDetailsScreen extends StatefulWidget {
  const SubscriptionDetailsScreen({super.key});

  @override
  State<SubscriptionDetailsScreen> createState() =>
      _SubscriptionDetailsScreenState();
}

class _SubscriptionDetailsScreenState extends State<SubscriptionDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final orgId = context.read<AuthProvider>().organizationId;
    if (orgId == null) return;
    await Future.wait([
      context.read<SubscriptionProvider>().loadSubscription(orgId),
      context.read<SubscriptionProvider>().loadInvoices(orgId),
    ]);
  }

  Future<void> _handleCancel() async {
    bool confirmed = false;
    await showAdaptiveActionSheet(
      context: context,
      title: 'Cancel Subscription',
      message: 'Are you sure? You will retain access until the end of your '
          'current billing period.',
      destructiveLabel: 'Cancel Subscription',
      onConfirm: () => confirmed = true,
    );

    if (!confirmed || !mounted) return;

    final auth = context.read<AuthProvider>();
    final sub = context.read<SubscriptionProvider>().subscription;
    if (auth.organizationId == null || sub == null) return;

    final success = await context
        .read<SubscriptionProvider>()
        .cancelSubscription(auth.organizationId!, sub.id);

    if (mounted) {
      if (success) {
        showAdaptiveToast(context, 'Subscription cancelled', type: ToastType.success);
      } else {
        showAdaptiveToast(
          context,
          context.read<SubscriptionProvider>().error ?? 'Failed to cancel',
          type: ToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: kIsIOS
          ? CupertinoNavigationBar(
              middle: const Text('Subscription'),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _loadData,
                child: const Icon(CupertinoIcons.refresh),
              ),
            )
          : AppBar(
              title: const Text('Subscription'),
              actions: [
                IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadData,
                    tooltip: 'Refresh'),
              ],
            ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: Consumer<SubscriptionProvider>(
          builder: (context, sp, _) {
            if (sp.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final sub = sp.subscription;
            if (sub == null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.credit_card_off,
                        size: 64, color: AppTheme.gray600),
                    const SizedBox(height: 16),
                    Text('No active subscription',
                        style: TextStyle(
                            fontSize: 18, color: AppTheme.gray600)),
                    const SizedBox(height: 8),
                    if (sp.error != null)
                      Text(sp.error!,
                          style: TextStyle(
                              fontSize: 13, color: AppTheme.errorColor)),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Status card ─────────────────────────────────────
                  _StatusCard(sub: sub),
                  const SizedBox(height: 16),

                  // ── Details card ─────────────────────────────────────
                  _DetailsCard(sub: sub),
                  const SizedBox(height: 16),

                  // ── Invoices ──────────────────────────────────────────
                  if (sp.invoices.isNotEmpty) ...[
                    _InvoiceList(invoices: sp.invoices),
                    const SizedBox(height: 16),
                  ],

                  // ── Actions ───────────────────────────────────────────
                  if (sub.isActive && !sub.cancelAtPeriodEnd)
                    OutlinedButton.icon(
                      onPressed: _handleCancel,
                      icon: const Icon(Icons.cancel),
                      label: const Text('Cancel Subscription'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorColor,
                        side: const BorderSide(color: AppTheme.errorColor),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),

                  if (sub.cancelAtPeriodEnd)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.warningColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color:
                                AppTheme.warningColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'This subscription will cancel at the end of the '
                        'current billing period.',
                        style: TextStyle(color: AppTheme.warningColor),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Status card ───────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final dynamic sub; // SubscriptionModel

  const _StatusCard({required this.sub});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String label;

    switch (sub.status as String) {
      case 'trial':
        color = AppTheme.warningColor;
        icon = Icons.schedule;
        label = 'Free Trial';
        break;
      case 'active':
        color = AppTheme.successColor;
        icon = Icons.check_circle;
        label = 'Active';
        break;
      case 'past_due':
        color = AppTheme.errorColor;
        icon = Icons.error;
        label = 'Payment Past Due';
        break;
      default:
        color = AppTheme.gray600;
        icon = Icons.cancel;
        label = (sub.status as String).replaceAll('_', ' ').toUpperCase();
    }

    return Card(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.1),
              color.withValues(alpha: 0.05)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 56, color: color),
            const SizedBox(height: 12),
            Text(label,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color)),
            if (sub.isTrial == true && sub.trialDaysRemaining != null) ...[
              const SizedBox(height: 8),
              Text('${sub.trialDaysRemaining} days remaining',
                  style: TextStyle(fontSize: 16, color: AppTheme.gray600)),
            ],
            if (sub.currentPeriodEnd != null) ...[
              const SizedBox(height: 4),
              Text(
                sub.isTrial == true
                    ? 'Trial ends ${_fmt(sub.trialEndsAt ?? sub.currentPeriodEnd)}'
                    : 'Renews ${_fmt(sub.currentPeriodEnd)}',
                style: TextStyle(fontSize: 13, color: AppTheme.gray600),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ── Details card ──────────────────────────────────────────────────────────────

class _DetailsCard extends StatelessWidget {
  final dynamic sub;

  const _DetailsCard({required this.sub});

  @override
  Widget build(BuildContext context) {
    final plan = sub.plan;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.receipt_long, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              const Text('Plan Details',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
            const Divider(height: 24),
            if (plan != null) ...[
              _row('Plan', '${plan.name} (${plan.slug})'),
            ],
            _row('Billing', sub.billingCycle == 'annual' ? 'Annual' : 'Monthly'),
            _row('Amount', sub.formattedAmount),
            _row('Currency', sub.currency as String),
            if (sub.currentPeriodStart != null)
              _row(
                'Period',
                '${_fmt(sub.currentPeriodStart)} – ${_fmt(sub.currentPeriodEnd)}',
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 100,
                child: Text(label,
                    style: TextStyle(color: AppTheme.gray600))),
            Expanded(
                child: Text(value,
                    style:
                        const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );

  String _fmt(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ── Invoice list ──────────────────────────────────────────────────────────────

class _InvoiceList extends StatelessWidget {
  final List<dynamic> invoices;

  const _InvoiceList({required this.invoices});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.description, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              const Text('Recent Invoices',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
            const Divider(height: 16),
            ...invoices.take(5).map((inv) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    inv.isPaid ? Icons.check_circle : Icons.pending,
                    color: inv.isPaid
                        ? AppTheme.successColor
                        : AppTheme.warningColor,
                  ),
                  title: Text(inv.invoiceNumber as String),
                  subtitle: Text(
                      '${_fmt(inv.invoiceDate)} · ${inv.status}'),
                  trailing: Text(inv.formattedTotal as String,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold)),
                )),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
