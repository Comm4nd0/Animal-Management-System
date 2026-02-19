import uuid
import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='UserProfile',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('role', models.IntegerField(choices=[(0, 'Read Only'), (1, 'Contributor'), (2, 'Admin'), (3, 'Owner')], default=3, help_text="The user's role within their organization.")),
                ('service_tier', models.IntegerField(choices=[(0, 'Starter'), (1, 'Standard'), (2, 'Professional'), (3, 'Enterprise')], default=0)),
                ('registered_species', models.CharField(blank=True, default='', help_text='The species this account manages. Set on first animal or by user.', max_length=100)),
                ('registered_breed', models.CharField(blank=True, default='', help_text='The breed this account manages. Set on first animal or by user.', max_length=200)),
                ('farm_name', models.CharField(blank=True, default='', max_length=300)),
                ('contact_phone', models.CharField(blank=True, default='', max_length=30)),
                ('address', models.TextField(blank=True, default='')),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('user', models.OneToOneField(on_delete=django.db.models.deletion.CASCADE, related_name='profile', to=settings.AUTH_USER_MODEL)),
                ('organization', models.ForeignKey(blank=True, help_text='The owner profile this user belongs to. NULL for owners.', null=True, on_delete=django.db.models.deletion.CASCADE, related_name='team_members', to='accounts.userprofile')),
            ],
            options={
                'ordering': ['-created_at'],
            },
        ),
    ]
