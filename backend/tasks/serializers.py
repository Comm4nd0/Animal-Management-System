from rest_framework import serializers
from .models import BackgroundTask


class BackgroundTaskSerializer(serializers.ModelSerializer):
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    task_type_display = serializers.CharField(source='get_task_type_display', read_only=True)

    class Meta:
        model = BackgroundTask
        fields = [
            'id', 'task_type', 'task_type_display', 'status', 'status_display',
            'params', 'result', 'error', 'progress',
            'created_at', 'updated_at',
        ]
        read_only_fields = [
            'id', 'status', 'result', 'error', 'progress',
            'created_at', 'updated_at',
        ]
