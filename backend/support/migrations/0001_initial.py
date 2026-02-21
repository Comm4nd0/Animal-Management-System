import django.db.models.deletion
import uuid
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='SupportTicket',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('guest_name', models.CharField(blank=True, default='', help_text='Name of the person submitting the ticket (required for guests).', max_length=200)),
                ('guest_email', models.EmailField(blank=True, default='', help_text='Contact email (required for guests).', max_length=254)),
                ('guest_phone', models.CharField(blank=True, default='', help_text='Contact phone number (required for guests).', max_length=30)),
                ('subject', models.CharField(max_length=300)),
                ('status', models.IntegerField(choices=[(0, 'Open'), (1, 'In Progress'), (2, 'Resolved'), (3, 'Closed')], default=0)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('user', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='support_tickets', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'ordering': ['-updated_at'],
            },
        ),
        migrations.CreateModel(
            name='SupportMessage',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('body', models.TextField()),
                ('is_staff_reply', models.BooleanField(default=False, help_text='True if this message was sent by support staff.')),
                ('is_read', models.BooleanField(default=False, help_text='Whether the recipient has read this message.')),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('ticket', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='messages', to='support.supportticket')),
                ('staff_user', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='support_replies', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'ordering': ['created_at'],
            },
        ),
    ]
