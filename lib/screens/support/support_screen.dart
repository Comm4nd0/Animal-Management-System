import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/models.dart';
import '../../services/animal_provider.dart';
import '../../utils/app_theme.dart';
import 'support_conversation_screen.dart';

/// Main support screen.
///
/// - Authenticated users see their ticket list with a button to create new ones.
/// - Guests see a form to create a new ticket (or resume a previous one if
///   the ticket ID was saved locally).
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  bool _loading = true;
  String? _guestTicketId;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final provider = context.read<AnimalProvider>();
    if (provider.isLoggedIn) {
      await provider.loadSupportTickets();
    } else {
      // Check if there's a saved guest ticket
      final prefs = await SharedPreferences.getInstance();
      _guestTicketId = prefs.getString('guest_support_ticket_id');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AnimalProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Support'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : provider.isLoggedIn
              ? _AuthenticatedView(
                  tickets: provider.supportTickets,
                  onRefresh: () => provider.loadSupportTickets(),
                )
              : _GuestView(
                  existingTicketId: _guestTicketId,
                  onTicketCreated: (id) async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('guest_support_ticket_id', id);
                    setState(() => _guestTicketId = id);
                  },
                ),
      floatingActionButton: provider.isLoggedIn
          ? FloatingActionButton.extended(
              onPressed: () => _showNewTicketDialog(context),
              icon: const Icon(Icons.add_comment),
              label: const Text('New Ticket'),
            )
          : null,
    );
  }

  void _showNewTicketDialog(BuildContext context) {
    final provider = context.read<AnimalProvider>();
    final subjectCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool submitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('New Support Ticket'),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: subjectCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Subject *',
                        prefixIcon: Icon(Icons.subject),
                      ),
                      autofocus: true,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Subject is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: messageCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Message *',
                        prefixIcon: Icon(Icons.message),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 5,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Message is required' : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: submitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => submitting = true);
                      try {
                        final ticket = await provider.createSupportTicket(
                          subject: subjectCtrl.text.trim(),
                          message: messageCtrl.text.trim(),
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SupportConversationScreen(
                                ticketId: ticket.id,
                                isGuest: false,
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => submitting = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Failed to create ticket: $e')),
                          );
                        }
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ticket list view for authenticated users.
class _AuthenticatedView extends StatelessWidget {
  final List<SupportTicket> tickets;
  final VoidCallback onRefresh;

  const _AuthenticatedView({required this.tickets, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (tickets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.support_agent, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No support tickets yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the button below to ask us anything',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: tickets.length,
        itemBuilder: (context, index) {
          final ticket = tickets[index];
          return _TicketCard(
            ticket: ticket,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SupportConversationScreen(
                    ticketId: ticket.id,
                    isGuest: false,
                  ),
                ),
              ).then((_) => onRefresh());
            },
          );
        },
      ),
    );
  }
}

/// Guest view: create a new ticket or resume a previous one.
class _GuestView extends StatefulWidget {
  final String? existingTicketId;
  final void Function(String ticketId) onTicketCreated;

  const _GuestView({this.existingTicketId, required this.onTicketCreated});

  @override
  State<_GuestView> createState() => _GuestViewState();
}

class _GuestViewState extends State<_GuestView> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Resume previous ticket button
          if (widget.existingTicketId != null) ...[
            Card(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              child: ListTile(
                leading: const Icon(Icons.history, color: AppTheme.primaryColor),
                title: const Text('Continue Previous Conversation'),
                subtitle: const Text('View your existing support ticket'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SupportConversationScreen(
                        ticketId: widget.existingTicketId!,
                        isGuest: true,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'Or start a new conversation',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
          // New ticket form
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.support_agent,
                            size: 28, color: AppTheme.primaryColor),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Contact Support',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Have a question? We\'re here to help. Fill out the form below and we\'ll get back to you.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Your Name *',
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Email Address *',
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Email is required';
                        if (!v.contains('@') || !v.contains('.')) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number *',
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Phone number is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _subjectCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Subject *',
                        prefixIcon: Icon(Icons.subject),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Subject is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _messageCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Your Message *',
                        prefixIcon: Icon(Icons.message),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 5,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Message is required' : null,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send),
                      label: Text(_submitting ? 'Sending...' : 'Send Message'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      final provider = context.read<AnimalProvider>();
      final ticket = await provider.createSupportTicket(
        subject: _subjectCtrl.text.trim(),
        message: _messageCtrl.text.trim(),
        guestName: _nameCtrl.text.trim(),
        guestEmail: _emailCtrl.text.trim(),
        guestPhone: _phoneCtrl.text.trim(),
      );

      widget.onTicketCreated(ticket.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ticket submitted! We\'ll get back to you soon.'),
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SupportConversationScreen(
              ticketId: ticket.id,
              isGuest: true,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit: $e')),
        );
      }
    }
  }
}

/// Card showing a ticket summary in the list.
class _TicketCard extends StatelessWidget {
  final SupportTicket ticket;
  final VoidCallback onTap;

  const _TicketCard({required this.ticket, required this.onTap});

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
    final statusColor = _statusColor(ticket.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Status indicator
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.subject,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (ticket.lastMessage != null)
                      Text(
                        ticket.lastMessage!['body'] as String? ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Chip(
                    label: Text(
                      ticket.statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    backgroundColor: statusColor.withValues(alpha: 0.1),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    side: BorderSide.none,
                  ),
                  if (ticket.unreadCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${ticket.unreadCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
