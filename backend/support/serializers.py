from rest_framework import serializers
from .models import SupportTicket, SupportMessage, TicketStatus


class SupportMessageSerializer(serializers.ModelSerializer):
    class Meta:
        model = SupportMessage
        fields = [
            'id', 'ticket', 'body', 'is_staff_reply',
            'is_read', 'created_at',
        ]
        read_only_fields = ['id', 'ticket', 'is_staff_reply', 'is_read', 'created_at']


class SupportTicketListSerializer(serializers.ModelSerializer):
    """Lightweight serializer for ticket list views."""
    last_message = serializers.SerializerMethodField()
    unread_count = serializers.SerializerMethodField()
    contact_name = serializers.ReadOnlyField()
    contact_email = serializers.ReadOnlyField()
    status_label = serializers.SerializerMethodField()

    class Meta:
        model = SupportTicket
        fields = [
            'id', 'subject', 'status', 'status_label',
            'contact_name', 'contact_email',
            'last_message', 'unread_count',
            'created_at', 'updated_at',
        ]
        read_only_fields = fields

    def get_last_message(self, obj):
        msg = obj.messages.order_by('-created_at').first()
        if msg:
            return {
                'body': msg.body[:100],
                'is_staff_reply': msg.is_staff_reply,
                'created_at': msg.created_at.isoformat(),
            }
        return None

    def get_unread_count(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            # For logged-in users, count unread staff replies
            return obj.messages.filter(is_staff_reply=True, is_read=False).count()
        # For guests, count unread staff replies too
        return obj.messages.filter(is_staff_reply=True, is_read=False).count()

    def get_status_label(self, obj):
        return obj.get_status_display()


class SupportTicketDetailSerializer(serializers.ModelSerializer):
    """Full serializer including all messages."""
    messages = SupportMessageSerializer(many=True, read_only=True)
    contact_name = serializers.ReadOnlyField()
    contact_email = serializers.ReadOnlyField()
    status_label = serializers.SerializerMethodField()
    unread_count = serializers.SerializerMethodField()

    class Meta:
        model = SupportTicket
        fields = [
            'id', 'subject', 'status', 'status_label',
            'guest_name', 'guest_email', 'guest_phone',
            'contact_name', 'contact_email',
            'messages', 'unread_count',
            'created_at', 'updated_at',
        ]
        read_only_fields = fields

    def get_status_label(self, obj):
        return obj.get_status_display()

    def get_unread_count(self, obj):
        return obj.messages.filter(is_staff_reply=True, is_read=False).count()


class CreateTicketSerializer(serializers.Serializer):
    """
    Creates a new support ticket with an initial message.

    For guests: guest_name, guest_email, and guest_phone are required.
    For authenticated users: those fields are optional (pulled from profile).
    """
    subject = serializers.CharField(max_length=300)
    message = serializers.CharField()
    guest_name = serializers.CharField(max_length=200, required=False, default='')
    guest_email = serializers.EmailField(required=False, default='')
    guest_phone = serializers.CharField(max_length=30, required=False, default='')

    def validate(self, data):
        request = self.context.get('request')
        is_authenticated = request and request.user.is_authenticated

        if not is_authenticated:
            if not data.get('guest_email'):
                raise serializers.ValidationError(
                    {'guest_email': 'Email is required for guest submissions.'}
                )
            if not data.get('guest_phone'):
                raise serializers.ValidationError(
                    {'guest_phone': 'Phone number is required for guest submissions.'}
                )
            if not data.get('guest_name'):
                raise serializers.ValidationError(
                    {'guest_name': 'Name is required for guest submissions.'}
                )
        return data

    def create(self, validated_data):
        request = self.context['request']
        message_body = validated_data.pop('message')

        ticket_data = {
            'subject': validated_data['subject'],
            'guest_name': validated_data.get('guest_name', ''),
            'guest_email': validated_data.get('guest_email', ''),
            'guest_phone': validated_data.get('guest_phone', ''),
        }

        if request.user.is_authenticated:
            ticket_data['user'] = request.user

        ticket = SupportTicket.objects.create(**ticket_data)
        SupportMessage.objects.create(
            ticket=ticket,
            body=message_body,
            is_staff_reply=False,
        )
        return ticket


class ReplySerializer(serializers.Serializer):
    """Add a reply message to an existing ticket."""
    message = serializers.CharField()
