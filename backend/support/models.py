import uuid
from django.conf import settings
from django.db import models


class TicketStatus(models.IntegerChoices):
    OPEN = 0, 'Open'
    IN_PROGRESS = 1, 'In Progress'
    RESOLVED = 2, 'Resolved'
    CLOSED = 3, 'Closed'


class SupportTicket(models.Model):
    """
    A support conversation thread.

    Can be created by authenticated users or anonymous guests.
    Guests must provide their email and phone number so staff can
    follow up. Authenticated users have these pulled from their profile
    but may override them.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    # Authenticated user (NULL for guest tickets)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='support_tickets',
    )

    # Contact info — required for guests, optional override for logged-in users
    guest_name = models.CharField(
        max_length=200,
        blank=True,
        default='',
        help_text='Name of the person submitting the ticket (required for guests).',
    )
    guest_email = models.EmailField(
        blank=True,
        default='',
        help_text='Contact email (required for guests).',
    )
    guest_phone = models.CharField(
        max_length=30,
        blank=True,
        default='',
        help_text='Contact phone number (required for guests).',
    )

    subject = models.CharField(max_length=300)
    status = models.IntegerField(
        choices=TicketStatus.choices,
        default=TicketStatus.OPEN,
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-updated_at']

    def __str__(self):
        who = self.user.username if self.user else self.guest_name or self.guest_email
        return f'[{self.get_status_display()}] {self.subject} ({who})'

    @property
    def is_guest_ticket(self):
        return self.user is None

    @property
    def contact_email(self):
        if self.guest_email:
            return self.guest_email
        if self.user:
            return self.user.email
        return ''

    @property
    def contact_name(self):
        if self.guest_name:
            return self.guest_name
        if self.user:
            name = f'{self.user.first_name} {self.user.last_name}'.strip()
            return name or self.user.username
        return ''


class SupportMessage(models.Model):
    """
    A single message within a support ticket conversation.

    Messages can be sent by the ticket creator (is_staff_reply=False)
    or by support staff (is_staff_reply=True).
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    ticket = models.ForeignKey(
        SupportTicket,
        on_delete=models.CASCADE,
        related_name='messages',
    )
    body = models.TextField()
    is_staff_reply = models.BooleanField(
        default=False,
        help_text='True if this message was sent by support staff.',
    )
    # The staff user who replied (NULL for customer messages)
    staff_user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='support_replies',
    )
    is_read = models.BooleanField(
        default=False,
        help_text='Whether the recipient has read this message.',
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['created_at']

    def __str__(self):
        sender = 'Staff' if self.is_staff_reply else 'Customer'
        return f'{sender}: {self.body[:60]}'
