// lib/presentation/patients/screens/patient_messages_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/patient_message_models.dart';
import '../../../data/providers/patient_message_provider.dart';

class PatientMessagesScreen extends StatefulWidget {
  final String patientId;
  final String patientName;

  const PatientMessagesScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<PatientMessagesScreen> createState() => _PatientMessagesScreenState();
}

class _PatientMessagesScreenState extends State<PatientMessagesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PatientMessageProvider>().loadInbox(widget.patientId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Messages — ${widget.patientName}'),
        actions: [
          Consumer<PatientMessageProvider>(
            builder: (context, provider, _) => IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: () => provider.loadInbox(widget.patientId),
            ),
          ),
        ],
      ),
      body: Consumer<PatientMessageProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.messages.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: () => provider.loadInbox(widget.patientId),
            child: Column(
              children: [
                if (provider.error != null)
                  Container(
                    width: double.infinity,
                    color: Colors.red.shade50,
                    padding: const EdgeInsets.all(12),
                    child: Text(provider.error!,
                        style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
                  ),
                Expanded(
                  child: provider.messages.isEmpty
                      ? Center(
                          child: Text('No messages yet.',
                              style: TextStyle(color: Colors.grey.shade600)),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: provider.messages.length,
                          itemBuilder: (_, i) => _MessageCard(
                            message: provider.messages[i],
                            onReply: (m) => _showReplySheet(context, m),
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showReplySheet(BuildContext context, PatientMessageModel message) async {
    final ctrl = TextEditingController();
    final provider = context.read<PatientMessageProvider>();

    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Reply to ${message.subject ?? 'message'}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Your reply *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                if (ctrl.text.trim().isEmpty) return;
                final ok = await provider.reply(
                    widget.patientId, message.id, ctrl.text.trim());
                if (sheetContext.mounted) Navigator.of(sheetContext).pop(ok);
              },
              child: const Text('Send Reply'),
            ),
          ],
        ),
      ),
    );

    if (sent == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reply sent.')),
      );
    }
    ctrl.dispose();
  }
}

class _MessageCard extends StatelessWidget {
  final PatientMessageModel message;
  final void Function(PatientMessageModel) onReply;

  const _MessageCard({required this.message, required this.onReply});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  message.isFromPatient ? Icons.person_outline : Icons.medical_services_outlined,
                  size: 18,
                  color: message.isFromPatient ? Colors.blue : Colors.green,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message.subject ?? (message.isFromPatient ? 'Patient message' : 'Your reply'),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
                if (message.isUnread && message.isFromPatient)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('New', style: TextStyle(fontSize: 10)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(message.body ?? '', style: const TextStyle(fontSize: 13, height: 1.4)),
            const SizedBox(height: 6),
            Text(_formatDate(message.createdAt),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            if (message.isFromPatient) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.reply, size: 16),
                  label: const Text('Reply'),
                  onPressed: () => onReply(message),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime dt) =>
    '${dt.day.toString().padLeft(2, '0')}/'
    '${dt.month.toString().padLeft(2, '0')}/'
    '${dt.year} '
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
