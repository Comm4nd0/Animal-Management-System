from django.contrib import admin
from .models import SupportTicket, SupportMessage


class SupportMessageInline(admin.TabularInline):
    model = SupportMessage
    extra = 1
    readonly_fields = ('id', 'created_at')
    fields = ('body', 'is_staff_reply', 'staff_user', 'is_read', 'created_at')


@admin.register(SupportTicket)
class SupportTicketAdmin(admin.ModelAdmin):
    list_display = ('subject', 'contact_name', 'contact_email', 'status', 'created_at', 'updated_at')
    list_filter = ('status', 'created_at')
    search_fields = ('subject', 'guest_name', 'guest_email', 'user__username', 'user__email')
    readonly_fields = ('id', 'created_at', 'updated_at')
    inlines = [SupportMessageInline]

    def get_queryset(self, request):
        return super().get_queryset(request).prefetch_related('messages')


@admin.register(SupportMessage)
class SupportMessageAdmin(admin.ModelAdmin):
    list_display = ('ticket', 'is_staff_reply', 'is_read', 'created_at')
    list_filter = ('is_staff_reply', 'is_read', 'created_at')
    readonly_fields = ('id', 'created_at')
