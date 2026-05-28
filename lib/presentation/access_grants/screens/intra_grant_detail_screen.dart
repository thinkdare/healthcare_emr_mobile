import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/platform.dart';
import '../../../data/models/intra_grant_models.dart';
import '../../../data/providers/intra_grant_provider.dart';

/// Detail screen for an intra-facility consultation grant.
/// Shows the message thread when the grant is accepted, with 5-second polling.
/// Polling pauses on background and stops on dispose or when grant is no longer accepted.
class IntraGrantDetailScreen extends StatefulWidget {
  final IntraAccessGrantModel grant;
  final String currentUserId;

  const IntraGrantDetailScreen({
    super.key,
    required this.grant,
    required this.currentUserId,
  });

  @override
  State<IntraGrantDetailScreen> createState() => _IntraGrantDetailScreenState();
}

class _IntraGrantDetailScreenState extends State<IntraGrantDetailScreen>
    with WidgetsBindingObserver {
  final _msgCtrl     = TextEditingController();
  final _scrollCtrl  = ScrollController();
  bool _sending = false;

  IntraAccessGrantModel get _grant => widget.grant;
  bool get _isDoctor  => _grant.grantedToId  == widget.currentUserId;
  bool get _isOwner   => _grant.grantedById  == widget.currentUserId;
  bool get _canMessage => _grant.isAccepted && (_isDoctor || _isOwner);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (_grant.isAccepted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<IntraGrantProvider>().startMessagePolling(_grant.id);
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final provider = context.read<IntraGrantProvider>();
    if (state == AppLifecycleState.paused) {
      provider.pausePolling();
    } else if (state == AppLifecycleState.resumed) {
      provider.resumePolling();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    context.read<IntraGrantProvider>().stopPolling();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final body = _msgCtrl.text.trim();
    if (body.isEmpty) return;

    setState(() => _sending = true);
    _msgCtrl.clear();

    final msg = await context.read<IntraGrantProvider>().sendMessage(_grant.id, body);
    if (!mounted) return;
    setState(() => _sending = false);

    if (msg != null) {
      _scrollToBottom();
    } else {
      showAdaptiveToast(context, 'Failed to send message.', type: ToastType.error);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _showCompleteDialog() async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete consultation'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Write your final clinical summary or recommendation…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (ctrl.text.trim().length >= 5) Navigator.of(ctx).pop(ctrl.text.trim());
            },
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (confirmed != null && mounted) {
      final ok = await context.read<IntraGrantProvider>().complete(_grant.id, confirmed);
      if (mounted) {
        showAdaptiveToast(
          context,
          ok ? 'Consultation completed.' : 'Failed to complete.',
          type: ok ? ToastType.success : ToastType.error,
        );
        if (ok) Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_grant.patientName ?? 'Consultation'),
        actions: [
          if (_grant.isAccepted && _isDoctor)
            TextButton(
              onPressed: _showCompleteDialog,
              child: const Text('Complete'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Grant info header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: theme.colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16,
                    color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _statusDescription(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Message thread
          Expanded(
            child: Consumer<IntraGrantProvider>(
              builder: (context, provider, child) {
                final messages = provider.messages;

                if (messages.isEmpty && provider.messagesLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (messages.isEmpty) {
                  return Center(
                    child: Text('No messages yet.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  );
                }

                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (_, i) => _MessageBubble(
                    message: messages[i],
                    currentUserId: widget.currentUserId,
                  ),
                );
              },
            ),
          ),

          // Close-out response (if grant is closed and has a response)
          if (_grant.isClosed && _grant.hasResponse)
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Clinical summary',
                      style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(_grant.response!, style: theme.textTheme.bodySmall),
                ],
              ),
            ),

          // Message input
          if (_canMessage)
            Container(
              padding: EdgeInsets.fromLTRB(
                  12, 8, 12, MediaQuery.of(context).viewInsets.bottom + 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(top: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      maxLines: null,
                      maxLength: 4000,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: 'Type a message…',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _sendMessage,
                    icon: _sending
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _statusDescription() {
    return switch (_grant.status) {
      'pending'   => 'Consultation request pending — waiting for colleague response.',
      'accepted'  => 'Consultation in progress.',
      'declined'  => 'Consultation declined.',
      'completed' => 'Consultation completed.',
      'cancelled' => 'Consultation cancelled.',
      _           => _grant.status,
    };
  }
}

class _MessageBubble extends StatelessWidget {
  final ConsultationMessageModel message;
  final String currentUserId;

  const _MessageBubble({required this.message, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final isOwn  = message.isOwn;
    final time   = '${message.sentAt.hour.toString().padLeft(2, '0')}:${message.sentAt.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isOwn
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft:     const Radius.circular(16),
            topRight:    const Radius.circular(16),
            bottomLeft:  Radius.circular(isOwn ? 16 : 4),
            bottomRight: Radius.circular(isOwn ? 4  : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isOwn
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 10,
                color: (isOwn
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant)
                    .withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
