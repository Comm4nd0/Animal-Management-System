from django.contrib import admin
from .models import UserProfile


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
