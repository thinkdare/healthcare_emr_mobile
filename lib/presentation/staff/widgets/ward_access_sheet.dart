// lib/presentation/staff/widgets/ward_access_sheet.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/providers/ward_workflow_provider.dart';

class WardAccessSheet extends StatefulWidget {
  final String membershipId;
  final String staffName;

  const WardAccessSheet({
    super.key,
    required this.membershipId,
    required this.staffName,
  });

  @override
  State<WardAccessSheet> createState() => _WardAccessSheetState();
}

class _WardAccessSheetState extends State<WardAccessSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WardWorkflowProvider>().loadWardAccess(widget.membershipId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) => Consumer<WardWorkflowProvider>(
        builder: (context, ward, _) {
          final grantedWardIds = ward.wardAccessGrants.map((g) => g.wardId).toSet();
          final ungranted =
              ward.wards.where((w) => !grantedWardIds.contains(w.id)).toList();

          return Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Ward Access',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                    Text(widget.staffName,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (ward.error != null)
                Container(
                  color: Colors.red.shade50,
                  padding: const EdgeInsets.all(12),
                  child: Text(ward.error!,
                      style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
                ),
              if (ward.isLoading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text('Granted wards',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 8),
                      if (ward.wardAccessGrants.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text('No ward access granted yet.',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                        )
                      else
                        ...ward.wardAccessGrants.map((grant) {
                          final w = ward.wards.where((w) => w.id == grant.wardId);
                          final name = w.isEmpty ? grant.wardId : w.first.name;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            child: ListTile(
                              title: Text(name),
                              trailing: IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                tooltip: 'Revoke',
                                onPressed: () => context
                                    .read<WardWorkflowProvider>()
                                    .revokeWardAccess(widget.membershipId, grant.id),
                              ),
                            ),
                          );
                        }),
                      const SizedBox(height: 20),
                      const Text('Grant access',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 8),
                      if (ungranted.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text('All wards already granted.',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                        )
                      else
                        ...ungranted.map((w) => Card(
                              margin: const EdgeInsets.only(bottom: 6),
                              child: ListTile(
                                title: Text(w.name),
                                subtitle: Text('${w.availableBedCount}/${w.bedCount} beds free'),
                                trailing: FilledButton.tonal(
                                  onPressed: ward.isSubmitting
                                      ? null
                                      : () => context
                                          .read<WardWorkflowProvider>()
                                          .grantWardAccess(widget.membershipId, w.id),
                                  child: const Text('Grant'),
                                ),
                              ),
                            )),
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
