import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/platform.dart';
import '../../../data/providers/clinical_provider.dart';
import '../../../data/repositories/reporting_repository.dart'
    show AuditLogEntry;
import '../../../config/app_colors.dart';

/// Shows the immutable access-audit trail for a single patient. Restricted
/// server-side to the patient's primary provider or a super admin
/// (PatientController::auditLog) — anyone else gets a 403, surfaced here as
/// a plain error state rather than a generic failure.
class PatientAuditLogScreen extends StatefulWidget {
  final String patientId;
  final String patientName;

  const PatientAuditLogScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<PatientAuditLogScreen> createState() => _PatientAuditLogScreenState();
}

class _PatientAuditLogScreenState extends State<PatientAuditLogScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClinicalProvider>().loadAuditLog(
        widget.patientId,
        refresh: true,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: kIsIOS
          ? CupertinoNavigationBar(
              middle: Text('Audit Log — ${widget.patientName}'),
            )
          : AppBar(title: Text('Audit Log — ${widget.patientName}')),
      body: Consumer<ClinicalProvider>(
        builder: (context, cp, _) {
          if (cp.isLoadingAuditLog && cp.auditLog.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (cp.auditLogError != null && cp.auditLog.isEmpty) {
            return _ErrorState(
              message: cp.auditLogError!,
              onRetry: () => cp.loadAuditLog(widget.patientId, refresh: true),
            );
          }

          if (cp.auditLog.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.history,
                    size: 48,
                    color: AppColors.of(context).textSecondary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No audit events found',
                    style: TextStyle(
                      color: AppColors.of(context).textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => cp.loadAuditLog(widget.patientId, refresh: true),
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
                  cp.loadMoreAuditLog(widget.patientId);
                }
                return false;
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: cp.auditLog.length + (cp.auditLogHasMore ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i == cp.auditLog.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return _AuditEntryCard(entry: cp.auditLog[i]);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 48,
              color: AppColors.of(context).critical,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _AuditEntryCard extends StatelessWidget {
  final AuditLogEntry entry;
  const _AuditEntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final emergencyColor = entry.wasEmergency
        ? AppColors.of(context).critical
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: entry.wasEmergency
            ? BorderSide(
                color: AppColors.of(context).critical.withValues(alpha: 0.4),
              )
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (emergencyColor ?? AppColors.of(context).accent)
                    .withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _actionIcon(entry.action),
                size: 18,
                color: emergencyColor ?? AppColors.of(context).accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        entry.actionDisplay,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: emergencyColor,
                        ),
                      ),
                      if (entry.resourceType != null) ...[
                        Text(
                          ' · ',
                          style: TextStyle(
                            color: AppColors.of(context).textSecondary,
                          ),
                        ),
                        Text(
                          entry.resourceType!,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.of(context).textSecondary,
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (entry.wasEmergency)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.of(
                              context,
                            ).critical.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'EMERGENCY',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppColors.of(context).critical,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.authorityDisplay,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.of(context).textSecondary,
                    ),
                  ),
                  if (entry.accessedAt != null)
                    Text(
                      _formatDate(entry.accessedAt!),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.of(context).textSecondary,
                      ),
                    ),
                  if (entry.wasOffline)
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Text(
                        'Recorded offline',
                        style: TextStyle(
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _actionIcon(String action) => switch (action) {
    'viewed' => Icons.visibility,
    'created' => Icons.add_circle_outline,
    'updated' => Icons.edit_outlined,
    'deleted' => Icons.delete_outline,
    'emergency_access' => Icons.warning_amber,
    'access_denied' => Icons.block,
    _ => Icons.receipt_long_outlined,
  };

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      final h = diff.inHours;
      if (h == 0) return '${diff.inMinutes}m ago';
      return '${h}h ago';
    }
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}
