/// Status of a support ticket, matching the backend TicketStatus IntegerChoices.
enum TicketStatus {
  open,       // 0
  inProgress, // 1
  resolved,   // 2
  closed,     // 3
}

String ticketStatusLabel(TicketStatus s) {
  switch (s) {
    case TicketStatus.open:
      return 'Open';
    case TicketStatus.inProgress:
      return 'In Progress';
    case TicketStatus.resolved:
      return 'Resolved';
    case TicketStatus.closed:
      return 'Closed';
  }
}

/// A single message within a support conversation.
class SupportMessage {
  final String id;
  final String ticketId;
  final String body;
  final bool isStaffReply;
  final bool isRead;
  final DateTime createdAt;

  const SupportMessage({
    required this.id,
    required this.ticketId,
    required this.body,
    this.isStaffReply = false,
    this.isRead = false,
    required this.createdAt,
  });

  factory SupportMessage.fromApi(Map<String, dynamic> m) {
    return SupportMessage(
      id: m['id'] as String,
      ticketId: m['ticket'] as String? ?? '',
      body: m['body'] as String,
      isStaffReply: m['is_staff_reply'] as bool? ?? false,
      isRead: m['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }
}

/// A support ticket (conversation thread).
class SupportTicket {
  final String id;
  final String subject;
  final TicketStatus status;
  final String statusLabel;
  final String contactName;
  final String contactEmail;
  final String guestName;
  final String guestEmail;
  final String guestPhone;
  final List<SupportMessage> messages;
  final int unreadCount;
  final Map<String, dynamic>? lastMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SupportTicket({
    required this.id,
    required this.subject,
    this.status = TicketStatus.open,
    this.statusLabel = 'Open',
    this.contactName = '',
    this.contactEmail = '',
    this.guestName = '',
    this.guestEmail = '',
    this.guestPhone = '',
    this.messages = const [],
    this.unreadCount = 0,
    this.lastMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SupportTicket.fromListApi(Map<String, dynamic> m) {
    return SupportTicket(
      id: m['id'] as String,
      subject: m['subject'] as String,
      status: TicketStatus.values[m['status'] as int? ?? 0],
      statusLabel: m['status_label'] as String? ?? 'Open',
      contactName: m['contact_name'] as String? ?? '',
      contactEmail: m['contact_email'] as String? ?? '',
      unreadCount: m['unread_count'] as int? ?? 0,
      lastMessage: m['last_message'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(m['created_at'] as String),
      updatedAt: DateTime.parse(m['updated_at'] as String),
    );
  }

  factory SupportTicket.fromDetailApi(Map<String, dynamic> m) {
    final messageList = (m['messages'] as List? ?? [])
        .map((msg) => SupportMessage.fromApi(msg as Map<String, dynamic>))
        .toList();

    return SupportTicket(
      id: m['id'] as String,
      subject: m['subject'] as String,
      status: TicketStatus.values[m['status'] as int? ?? 0],
      statusLabel: m['status_label'] as String? ?? 'Open',
      contactName: m['contact_name'] as String? ?? '',
      contactEmail: m['contact_email'] as String? ?? '',
      guestName: m['guest_name'] as String? ?? '',
      guestEmail: m['guest_email'] as String? ?? '',
      guestPhone: m['guest_phone'] as String? ?? '',
      messages: messageList,
      unreadCount: m['unread_count'] as int? ?? 0,
      createdAt: DateTime.parse(m['created_at'] as String),
      updatedAt: DateTime.parse(m['updated_at'] as String),
    );
  }
}
