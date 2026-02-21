from rest_framework import serializers
from .models import BackgroundTask


class BackgroundTaskSerializer(serializers.ModelSerializer):
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    task_type_display = serializers.CharField(source='get_task_type_display', read_only=True)
    estimated_seconds_remaining = serializers.SerializerMethodField()

    class Meta:
        model = BackgroundTask
        fields = [
            'id', 'task_type', 'task_type_display', 'status', 'status_display',
            'params', 'result', 'error', 'progress',
            'status_message', 'total_items', 'processed_items',
            'estimated_completion', 'estimated_seconds_remaining',
            'started_at', 'completed_at',
            'created_at', 'updated_at',
        ]
        read_only_fields = [
            'id', 'status', 'result', 'error', 'progress',
            'status_message', 'total_items', 'processed_items',
            'estimated_completion', 'started_at', 'completed_at',
            'created_at', 'updated_at',
        ]

    def get_estimated_seconds_remaining(self, obj):
        if obj.estimated_completion is None:
            return None
        from django.utils import timezone
        delta = (obj.estimated_completion - timezone.now()).total_seconds()
        return max(0, round(delta))
