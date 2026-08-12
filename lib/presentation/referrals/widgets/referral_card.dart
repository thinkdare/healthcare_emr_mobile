// lib/presentation/referrals/widgets/referral_card.dart

import 'package:flutter/material.dart';
import '../../../data/models/referral_models.dart';
import '../screens/referral_detail_screen.dart';

class ReferralCard extends StatelessWidget {
  final ReferralModel referral;

  const ReferralCard({super.key, required this.referral});

  @override
  Widget build(BuildContext context) {
    final r = referral;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ReferralDetailScreen(referral: r),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _RoleBadge(isSent: r.isSent),
                  const SizedBox(width: 8),
                  _UrgencyDot(urgency: r.urgency),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      r.patientName ?? 'Patient',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _StatusChip(status: r.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                r.isSent
                    ? '${r.specialty} · → ${r.toTenantName}'
                    : '${r.specialty} · ← ${r.fromTenantName}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    r.referringProviderName,
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                  Text(' · ',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey)),
                  Text(
                    _relative(r.referredAt),
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                  if (r.isOverdue) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.warning_amber_rounded,
                        size: 13, color: Colors.orange),
                    const Text(' Overdue',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange,
                            fontWeight: FontWeight.w500)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _relative(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _RoleBadge extends StatelessWidget {
  final bool isSent;
  const _RoleBadge({required this.isSent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isSent
            ? Colors.purple.withValues(alpha: 0.12)
            : Colors.teal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isSent ? 'SENT' : 'RECEIVED',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: isSent ? Colors.purple.shade700 : Colors.teal.shade700,
        ),
      ),
    );
  }
}

class _UrgencyDot extends StatelessWidget {
  final String urgency;
  const _UrgencyDot({required this.urgency});

  @override
  Widget build(BuildContext context) {
    final color = switch (urgency) {
      'emergency' => Colors.red,
      'urgent'    => Colors.orange,
      _           => Colors.grey.shade400,
    };
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (status) {
      'pending'   => (const Color(0xFFFFF3E0), const Color(0xFFE65100), 'Pending'),
      'accepted'  => (const Color(0xFFE3F2FD), const Color(0xFF1565C0), 'Accepted'),
      'scheduled' => (const Color(0xFFE8F5E9), const Color(0xFF2E7D32), 'Scheduled'),
      'completed' => (const Color(0xFFF3E5F5), const Color(0xFF6A1B9A), 'Completed'),
      'cancelled' => (const Color(0xFFEEEEEE), const Color(0xFF616161), 'Cancelled'),
      _           => (const Color(0xFFEEEEEE), const Color(0xFF616161), status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, color: fg, fontWeight: FontWeight.w600)),
    );
  }
}
