import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/theme.dart';
import '../../../core/platform.dart';
import '../../../data/models/clinical_models.dart';
import '../../../data/providers/clinical_provider.dart';

/// Patient ↔ provider message thread for a single patient. Patients start
/// the conversation from the patient portal; this screen can only reply to
/// an existing thread, not start one — there is no provider-initiate
/// endpoint on the backend (PatientMessageController).
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
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClinicalProvider>().loadMessages(widget.patientId);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    final cp = context.read<ClinicalProvider>();
    final ok = await cp.sendMessageReply(widget.patientId, text);
    if (ok && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } else if (!ok && mounted && cp.messagesError != null) {
      showAdaptiveToast(context, cp.messagesError!, type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: kIsIOS
          ? CupertinoNavigationBar(
              middle: Text('Messages — ${widget.patientName}'),
            )
          : AppBar(title: Text('Messages — ${widget.patientName}')),
      body: Consumer<ClinicalProvider>(
        builder: (context, cp, _) {
          return Column(
            children: [
              Expanded(child: _buildBody(cp)),
              _buildComposer(cp),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody(ClinicalProvider cp) {
    if (cp.isLoadingMessages && cp.messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (cp.messagesError != null && cp.messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
              const SizedBox(height: 12),
              Text(cp.messagesError!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => cp.loadMessages(widget.patientId),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (cp.messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chat_bubble_outline, size: 48, color: AppTheme.gray600),
              const SizedBox(height: 12),
              Text('No messages yet',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                'The patient hasn\'t started a conversation from the patient portal yet.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.gray600),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: cp.messages.length,
      itemBuilder: (context, i) => _MessageBubble(message: cp.messages[i]),
    );
  }

  Widget _buildComposer(ClinicalProvider cp) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Reply to patient…',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                isDense: true,
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          cp.isSendingMessage
              ? const SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : IconButton(
                  onPressed: _send,
                  icon: const Icon(Icons.send),
                  color: AppTheme.primaryColor,
                ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final PatientMessageModel message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isMe = message.isFromProvider;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.primaryColor : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(isMe ? 'You' : 'Patient',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isMe ? Colors.white70 : Colors.grey.shade600)),
            const SizedBox(height: 2),
            Text(message.body,
                style: TextStyle(
                    fontSize: 13,
                    color: isMe ? Colors.white : Colors.grey.shade900)),
            const SizedBox(height: 2),
            Text(_formatTime(message.createdAt),
                style: TextStyle(
                    fontSize: 9,
                    color: isMe ? Colors.white60 : Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}
