// lib/presentation/referrals/widgets/referral_message_thread.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/referral_provider.dart';

class ReferralMessageThread extends StatefulWidget {
  final String referralId;
  final bool isOpen;

  const ReferralMessageThread({
    super.key,
    required this.referralId,
    required this.isOpen,
  });

  @override
  State<ReferralMessageThread> createState() => _ReferralMessageThreadState();
}

class _ReferralMessageThreadState extends State<ReferralMessageThread> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReferralProvider>().loadMessages(widget.referralId);
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
    final ok = await context
        .read<ReferralProvider>()
        .sendMessage(widget.referralId, text);
    if (ok && mounted) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId =
        context.read<AuthProvider>().currentUserId ?? '';

    return Consumer<ReferralProvider>(
      builder: (context, provider, _) {
        final messages = provider.messagesFor(widget.referralId);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('Messages',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
            ),
            if (messages.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                child: Text('No messages yet.',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500)),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final m = messages[i];
                    final isMe = m.senderId == currentUserId;
                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin:
                            const EdgeInsets.symmetric(vertical: 3),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        constraints: BoxConstraints(
                            maxWidth:
                                MediaQuery.of(context).size.width *
                                    0.75),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.blue.shade600
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: isMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            if (!isMe)
                              Text(m.senderName,
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w600)),
                            Text(m.message,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: isMe
                                        ? Colors.white
                                        : Colors.grey.shade900)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (widget.isOpen)
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: 'Send a message…',
                          border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(20)),
                          contentPadding:
                              const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                          isDense: true,
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    provider.isSendingMessage
                        ? const SizedBox(
                            width: 36,
                            height: 36,
                            child: CircularProgressIndicator(
                                strokeWidth: 2))
                        : IconButton(
                            onPressed: _send,
                            icon: const Icon(Icons.send),
                            color: Colors.blue.shade600,
                          ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
