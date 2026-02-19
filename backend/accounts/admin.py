from django.contrib import admin
from .models import UserProfile, TierConfiguration


@admin.register(UserProfile)
class UserProfileAdmin(admin.ModelAdmin):
    list_display = [
        'user', 'role', 'service_tier', 'organization',
        'registered_species', 'registered_breed',
        'farm_name', 'created_at',
    ]
    list_filter = ['service_tier', 'role', 'registered_species']
    search_fields = ['user__username', 'user__email', 'farm_name']
    raw_id_fields = ['user', 'organization']


@admin.register(TierConfiguration)
class TierConfigurationAdmin(admin.ModelAdmin):
    list_display = [
        'label', 'tier', 'max_animals', 'max_users',
        'allows_multi_breed',
    ]
    list_editable = ['max_animals', 'max_users', 'allows_multi_breed']
    ordering = ['tier']

    fieldsets = (
        (None, {
            'fields': ('tier', 'label', 'description'),
        }),
        ('Limits', {
            'fields': ('max_animals', 'max_users', 'allows_multi_breed'),
            'description': (
                'Leave "Max animals" or "Max users" blank for unlimited. '
                'Changes take effect immediately for all users on this tier.'
            ),
        }),
    )
