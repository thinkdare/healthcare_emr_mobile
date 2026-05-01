import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/platform.dart';
import 'package:provider/provider.dart';
import '../../../config/theme.dart';
import '../../../data/models/emergency_access_models.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/emergency_access_provider.dart';
import 'trigger_emergency_access_screen.dart';

class EmergencyAccessScreen extends StatefulWidget {
  const EmergencyAccessScreen({super.key});

  @override
  State<EmergencyAccessScreen> createState() =>
      _EmergencyAccessScreenState();
}

class _EmergencyAccessScreenState extends State<EmergencyAccessScreen> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<EmergencyAccessProvider>()
          .loadLogs(refresh: true);
    });
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      context.read<EmergencyAccessProvider>().loadMore();
    }
  }

  Future<void> _showReviewDialog(EmergencyAccessModel log) async {
    final notesCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Review Emergency Access'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Provider: ${log.providerName ?? "Unknown"}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                'Patient: ${log.patientName ?? log.masterPatientId}',
              ),
              Text(
                'Type: ${log.emergencyTypeDisplay}',
              ),
              Text(
                'Date: ${_formatDate(log.accessedAt)}',
                style:
                    const TextStyle(color: AppTheme.gray600, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Review notes *',
                  hintText: 'Acknowledge and record your review…',
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                autofocus: true,
                validator: (v) {
                  if (v == null || v.trim().length < 10) {
                    return 'Min. 10 characters required';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          AdaptiveTextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          AdaptiveFilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: const Text('Mark Reviewed'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final provider = context.read<EmergencyAccessProvider>();
    final ok = await provider.review(log.id, notesCtrl.text.trim());

    if (!mounted) return;
    if (ok) {
      showAdaptiveToast(context, 'Emergency access event marked as reviewed.', type: ToastType.success);
    } else {
      showAdaptiveToast(context, provider.error ?? 'Failed to mark reviewed', type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canTrigger =
        context.select<AuthProvider, bool>((a) => a.canEmergencyAccess);

    return Scaffold(
      appBar: kIsIOS
          ? CupertinoNavigationBar(
              middle: const Text('Emergency Access'),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => context
                    .read<EmergencyAccessProvider>()
                    .loadLogs(refresh: true),
                child: const Icon(CupertinoIcons.refresh),
              ),
            )
          : AppBar(
              title: const Text('Emergency Access'),
              actions: [
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh),
                  onPressed: () => context
                      .read<EmergencyAccessProvider>()
                      .loadLogs(refresh: true),
                ),
              ],
            ),
      floatingActionButton: canTrigger
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
              onPressed: () async {
                final provider =
                    context.read<EmergencyAccessProvider>();
                final created = await Navigator.of(context).push<bool>(
                  kIsIOS
                      ? CupertinoPageRoute(
                          builder: (_) =>
                              const TriggerEmergencyAccessScreen())
                      : MaterialPageRoute(
                          builder: (_) =>
                              const TriggerEmergencyAccessScreen()),
                );
                if (created == true && mounted) {
                  provider.loadLogs(refresh: true);
                }
              },
              icon: const Icon(Icons.warning_amber_rounded),
              label: const Text('Break Glass'),
            )
          : null,
      body: Consumer<EmergencyAccessProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.logs.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null && provider.logs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: AppTheme.errorColor),
                    const SizedBox(height: 12),
                    Text(provider.error!,
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () =>
                          provider.loadLogs(refresh: true),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (provider.logs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_user_outlined,
                      size: 56, color: AppTheme.gray600),
                  SizedBox(height: 12),
                  Text('No emergency access events.',
                      style: TextStyle(color: AppTheme.gray600)),
                ],
              ),
            );
          }

          final currentUserId =
              context.read<AuthProvider>().currentUser?.id;

          return RefreshIndicator(
            onRefresh: () => provider.loadLogs(refresh: true),
            child: ListView.separated(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: provider.logs.length +
                  (provider.hasMore ? 1 : 0),
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index == provider.logs.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final log = provider.logs[index];
                return _EmergencyLogCard(
                  log: log,
                  isNotifiedProvider:
                      currentUserId != null &&
                          log.notifiedProviderId == currentUserId,
                  onReview: () => _showReviewDialog(log),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ── Log Card ─────────────────────────────────────────────────────────────────

class _EmergencyLogCard extends StatelessWidget {
  final EmergencyAccessModel log;
  final bool isNotifiedProvider;
  final VoidCallback onReview;

  const _EmergencyLogCard({
    required this.log,
    required this.isNotifiedProvider,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    final needsReview = log.needsReview && isNotifiedProvider;

    return Card(
      elevation: needsReview ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: needsReview
              ? AppTheme.warningColor.withValues(alpha: 0.6)
              : AppTheme.gray100,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _TypeChip(type: log.emergencyType),
                const Spacer(),
                _StatusChip(log: log),
              ],
            ),
            const SizedBox(height: 10),
            _LabeledText(
                label: 'Patient',
                value: log.patientName ?? log.masterPatientId),
            _LabeledText(
                label: 'Provider', value: log.providerName ?? '—'),
            if (log.facilityName != null)
              _LabeledText(label: 'Facility', value: log.facilityName!),
            _LabeledText(
                label: 'Accessed',
                value: _formatDate(log.accessedAt),
                muted: true),

            if (log.escalatedToSupervisor) ...[
              const SizedBox(height: 8),
              _AlertRow(
                icon: Icons.escalator_warning,
                color: AppTheme.errorColor,
                text: 'Escalated to supervisor${log.escalatedAt != null ? ' on ${_formatDate(log.escalatedAt!)}' : ''}',
              ),
            ] else if (log.needsEscalation && !log.reviewedByPrimary) ...[
              const SizedBox(height: 8),
              const _AlertRow(
                icon: Icons.timer_outlined,
                color: AppTheme.warningColor,
                text: 'Pending review — may be escalated',
              ),
            ],

            if (needsReview) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor),
                  onPressed: onReview,
                  icon: const Icon(Icons.rate_review_outlined, size: 18),
                  label: const Text('Review This Event'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Small helpers ─────────────────────────────────────────────────────────────

class _TypeChip extends StatelessWidget {
  final String type;
  const _TypeChip({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 13, color: AppTheme.errorColor),
          const SizedBox(width: 4),
          Text(
            _label(type),
            style: const TextStyle(
                color: AppTheme.errorColor,
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  String _label(String type) => switch (type) {
        'life_threatening'  => 'Life Threatening',
        'unconscious'       => 'Unconscious',
        'unable_to_consent' => 'Cannot Consent',
        'critical_care'     => 'Critical Care',
        _                   => type,
      };
}

class _StatusChip extends StatelessWidget {
  final EmergencyAccessModel log;
  const _StatusChip({required this.log});

  @override
  Widget build(BuildContext context) {
    final (label, color) = log.reviewedByPrimary
        ? ('Reviewed', AppTheme.successColor)
        : log.escalatedToSupervisor
            ? ('Escalated', AppTheme.errorColor)
            : ('Pending Review', AppTheme.warningColor);

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600)),
    );
  }
}

class _LabeledText extends StatelessWidget {
  final String label;
  final String value;
  final bool muted;

  const _LabeledText(
      {required this.label, required this.value, this.muted = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              '$label:',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.gray600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                  fontSize: 13,
                  color: muted ? AppTheme.gray600 : null),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _AlertRow(
      {required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}

String _formatDate(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inDays == 0) {
    final h = diff.inHours;
    if (h == 0) return '${diff.inMinutes}m ago';
    return '${h}h ago';
  }
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year}';
}
