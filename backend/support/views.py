from rest_framework import viewsets, status, permissions
from rest_framework.decorators import action
from rest_framework.response import Response

from .models import SupportTicket, SupportMessage, TicketStatus
from .serializers import (
    SupportTicketListSerializer,
    SupportTicketDetailSerializer,
    CreateTicketSerializer,
    ReplySerializer,
)


class SupportViewSet(viewsets.ViewSet):
    """
    Support messaging endpoints.

    Authenticated users:
        list:          GET  /api/v1/support/          — list own tickets
        create:        POST /api/v1/support/create/   — create a new ticket
        retrieve:      GET  /api/v1/support/<id>/     — view ticket + messages
        reply:         POST /api/v1/support/<id>/reply/ — add a reply
        mark_read:     POST /api/v1/support/<id>/mark-read/ — mark messages read
        close:         POST /api/v1/support/<id>/close/ — close a ticket

    Guests (unauthenticated):
        create:        POST /api/v1/support/create/   — create (requires name/email/phone)
        guest_ticket:  GET  /api/v1/support/guest/<id>/ — view ticket by UUID
        guest_reply:   POST /api/v1/support/guest/<id>/reply/ — add a reply
        unread_count:  GET  /api/v1/support/unread-count/ — get unread message count
    """

    def list(self, request):
        """List all support tickets for the authenticated user."""
        if not request.user.is_authenticated:
            return Response(
                {'error': 'Authentication required to list tickets.'},
                status=status.HTTP_401_UNAUTHORIZED,
            )
        tickets = SupportTicket.objects.filter(user=request.user)
        serializer = SupportTicketListSerializer(
            tickets, many=True, context={'request': request},
        )
        return Response(serializer.data)

    def retrieve(self, request, pk=None):
        """Retrieve a specific ticket with all messages."""
        if not request.user.is_authenticated:
            return Response(
                {'error': 'Authentication required.'},
                status=status.HTTP_401_UNAUTHORIZED,
            )
        try:
            ticket = SupportTicket.objects.prefetch_related('messages').get(
                pk=pk, user=request.user,
            )
        except SupportTicket.DoesNotExist:
            return Response(
                {'error': 'Ticket not found.'},
                status=status.HTTP_404_NOT_FOUND,
            )
        serializer = SupportTicketDetailSerializer(
            ticket, context={'request': request},
        )
        return Response(serializer.data)

    @action(detail=False, methods=['post'], url_path='create')
    def create_ticket(self, request):
        """Create a new support ticket. Works for both guests and authenticated users."""
        serializer = CreateTicketSerializer(
            data=request.data,
            context={'request': request},
        )
        serializer.is_valid(raise_exception=True)
        ticket = serializer.save()
        detail = SupportTicketDetailSerializer(
            ticket, context={'request': request},
        )
        return Response(detail.data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['post'], url_path='reply')
    def reply(self, request, pk=None):
        """Add a reply to an existing ticket (authenticated user)."""
        if not request.user.is_authenticated:
            return Response(
                {'error': 'Authentication required.'},
                status=status.HTTP_401_UNAUTHORIZED,
            )
        try:
            ticket = SupportTicket.objects.get(pk=pk, user=request.user)
        except SupportTicket.DoesNotExist:
            return Response(
                {'error': 'Ticket not found.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        serializer = ReplySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        SupportMessage.objects.create(
            ticket=ticket,
            body=serializer.validated_data['message'],
            is_staff_reply=False,
        )

        # Re-open ticket if it was resolved/closed
        if ticket.status in (TicketStatus.RESOLVED, TicketStatus.CLOSED):
            ticket.status = TicketStatus.OPEN
            ticket.save(update_fields=['status'])

        detail = SupportTicketDetailSerializer(
            ticket, context={'request': request},
        )
        return Response(detail.data)

    @action(detail=True, methods=['post'], url_path='mark-read')
    def mark_read(self, request, pk=None):
        """Mark all staff replies as read for the authenticated user."""
        if not request.user.is_authenticated:
            return Response(
                {'error': 'Authentication required.'},
                status=status.HTTP_401_UNAUTHORIZED,
            )
        try:
            ticket = SupportTicket.objects.get(pk=pk, user=request.user)
        except SupportTicket.DoesNotExist:
            return Response(
                {'error': 'Ticket not found.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        ticket.messages.filter(is_staff_reply=True, is_read=False).update(is_read=True)
        return Response({'status': 'ok'})

    @action(detail=True, methods=['post'], url_path='close')
    def close_ticket(self, request, pk=None):
        """Close a ticket (authenticated user)."""
        if not request.user.is_authenticated:
            return Response(
                {'error': 'Authentication required.'},
                status=status.HTTP_401_UNAUTHORIZED,
            )
        try:
            ticket = SupportTicket.objects.get(pk=pk, user=request.user)
        except SupportTicket.DoesNotExist:
            return Response(
                {'error': 'Ticket not found.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        ticket.status = TicketStatus.CLOSED
        ticket.save(update_fields=['status'])
        return Response({'status': 'closed'})

    @action(detail=False, methods=['get'], url_path='unread-count')
    def unread_count(self, request):
        """Get total unread support message count for the authenticated user."""
        if not request.user.is_authenticated:
            return Response({'unread_count': 0})

        count = SupportMessage.objects.filter(
            ticket__user=request.user,
            is_staff_reply=True,
            is_read=False,
        ).count()
        return Response({'unread_count': count})

    # ─── Guest endpoints ──────────────────────────────────────────

    @action(detail=False, methods=['get'], url_path='guest/(?P<ticket_id>[^/.]+)')
    def guest_ticket(self, request, ticket_id=None):
        """
        Retrieve a guest ticket by its UUID.

        The UUID acts as a shared secret — only someone who knows the
        ticket ID can view it.
        """
        try:
            ticket = SupportTicket.objects.prefetch_related('messages').get(
                pk=ticket_id, user__isnull=True,
            )
        except SupportTicket.DoesNotExist:
            return Response(
                {'error': 'Ticket not found.'},
                status=status.HTTP_404_NOT_FOUND,
            )
        serializer = SupportTicketDetailSerializer(
            ticket, context={'request': request},
        )
        return Response(serializer.data)

    @action(
        detail=False, methods=['post'],
        url_path='guest/(?P<ticket_id>[^/.]+)/reply',
    )
    def guest_reply(self, request, ticket_id=None):
        """Add a reply to a guest ticket."""
        try:
            ticket = SupportTicket.objects.get(pk=ticket_id, user__isnull=True)
        except SupportTicket.DoesNotExist:
            return Response(
                {'error': 'Ticket not found.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        serializer = ReplySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        SupportMessage.objects.create(
            ticket=ticket,
            body=serializer.validated_data['message'],
            is_staff_reply=False,
        )

        if ticket.status in (TicketStatus.RESOLVED, TicketStatus.CLOSED):
            ticket.status = TicketStatus.OPEN
            ticket.save(update_fields=['status'])

        detail = SupportTicketDetailSerializer(
            ticket, context={'request': request},
        )
        return Response(detail.data)
