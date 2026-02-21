import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/animal_provider.dart';
import '../../services/notification_service.dart';
import '../../utils/app_theme.dart';

/// Chat-style conversation view for a single support ticket.
class SupportConversationScreen extends StatefulWidget {
  final String ticketId;
  final bool isGuest;

  const SupportConversationScreen({
    super.key,
    required this.ticketId,
    required this.isGuest,
  });

  @override
  State<SupportConversationScreen> createState() =>
      _SupportConversationScreenState();
}

class _SupportConversationScreenState extends State<SupportConversationScreen> {
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  SupportTicket? _ticket;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTicket();
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTicket() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final provider = context.read<AnimalProvider>();
      SupportTicket ticket;
      if (widget.isGuest) {
        ticket = await provider.loadGuestSupportTicket(widget.ticketId);
      } else {
        ticket = await provider.loadSupportTicketDetail(widget.ticketId);
        // Mark messages as read
        if (ticket.unreadCount > 0) {
          await provider.markSupportTicketRead(widget.ticketId);
        }
      }
      if (mounted) {
        setState(() {
          _ticket = ticket;
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load ticket: $e';
          _loading = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendReply() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);

    try {
      final provider = context.read<AnimalProvider>();
      SupportTicket ticket;
      if (widget.isGuest) {
        ticket = await provider.replyGuestSupportTicket(widget.ticketId, text);
      } else {
        ticket = await provider.replySupportTicket(widget.ticketId, text);
      }
      _messageCtrl.clear();
      if (mounted) {
        setState(() {
          _ticket = ticket;
          _sending = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_ticket?.subject ?? 'Support'),
        actions: [
          if (_ticket != null && !widget.isGuest)
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'close') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Close Ticket'),
                      content: const Text(
                        'Are you sure you want to close this ticket? '
                        'You can reopen it by sending a new message.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && mounted) {
                    await context
                        .read<AnimalProvider>()
                        .closeSupportTicket(widget.ticketId);
                    await _loadTicket();
                  }
                } else if (value == 'refresh') {
                  await _loadTicket();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'refresh',
                  child: ListTile(
                    leading: Icon(Icons.refresh),
                    title: Text('Refresh'),
                  ),
                ),
                if (_ticket!.status != TicketStatus.closed)
                  const PopupMenuItem(
                    value: 'close',
                    child: ListTile(
                      leading: Icon(Icons.check_circle_outline),
                      title: Text('Close Ticket'),
                    ),
                  ),
              ],
            ),
          if (widget.isGuest)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: _loadTicket,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadTicket,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Status bar
                    _StatusBar(ticket: _ticket!),
                    // Messages
                    Expanded(
                      child: _ticket!.messages.isEmpty
                          ? Center(
                              child: Text(
                                'No messages yet',
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollCtrl,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              itemCount: _ticket!.messages.length,
                              itemBuilder: (context, index) {
                                return _MessageBubble(
                                  message: _ticket!.messages[index],
                                );
                              },
                            ),
                    ),
                    // Reply input
                    _ReplyInput(
                      controller: _messageCtrl,
                      sending: _sending,
                      onSend: _sendReply,
                      isClosed: _ticket!.status == TicketStatus.closed,
                    ),
                  ],
                ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  final SupportTicket ticket;

  const _StatusBar({required this.ticket});

  Color _statusColor(TicketStatus status) {
    switch (status) {
      case TicketStatus.open:
        return Colors.blue;
      case TicketStatus.inProgress:
        return Colors.orange;
      case TicketStatus.resolved:
        return AppTheme.primaryColor;
      case TicketStatus.closed:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(ticket.status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: color.withValues(alpha: 0.08),
      child: Row(
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 8),
          Text(
            ticket.statusLabel,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Text(
            'Created ${DateFormat.yMMMd().format(ticket.createdAt)}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final SupportMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isStaff = message.isStaffReply;
    final alignment =
        isStaff ? CrossAxisAlignment.start : CrossAxisAlignment.end;
    final bubbleColor = isStaff
        ? Colors.grey.shade200
        : AppTheme.primaryColor.withValues(alpha: 0.15);
    final textColor = isStaff ? Colors.black87 : Colors.black87;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          // Sender label
          Padding(
            padding: const EdgeInsets.only(bottom: 2, left: 4, right: 4),
            child: Text(
              isStaff ? 'Support Team' : 'You',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isStaff ? Colors.orange.shade700 : AppTheme.primaryColor,
              ),
            ),
          ),
          // Bubble
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isStaff ? 4 : 16),
                bottomRight: Radius.circular(isStaff ? 16 : 4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.body,
                  style: TextStyle(color: textColor, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat.jm().format(message.createdAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplyInput extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final bool isClosed;

  const _ReplyInput({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.isClosed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: isClosed
                    ? 'Ticket closed — send a message to reopen'
                    : 'Type your message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: sending ? null : onSend,
            icon: sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            color: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }
}
