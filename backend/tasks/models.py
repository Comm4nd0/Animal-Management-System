import uuid
from django.conf import settings
from django.db import models
from django.utils import timezone


class BackgroundTask(models.Model):
    """Tracks the status and result of long-running background jobs."""

    class Status(models.IntegerChoices):
        PENDING = 0, 'Pending'
        RUNNING = 1, 'Running'
        COMPLETED = 2, 'Completed'
        FAILED = 3, 'Failed'
        CANCELLED = 4, 'Cancelled'

    class TaskType(models.IntegerChoices):
        PEDIGREE_TREE = 0, 'Pedigree Tree'
        BREEDING_SUGGESTIONS = 1, 'Breeding Suggestions'
        COI_CALCULATION = 2, 'COI Calculation'
        BULK_IMPORT = 3, 'Bulk Import'
        BULK_EXPORT = 4, 'Bulk Export'
        DASHBOARD_STATS = 5, 'Dashboard Statistics'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='background_tasks',
    )
    task_type = models.IntegerField(choices=TaskType.choices)
    status = models.IntegerField(choices=Status.choices, default=Status.PENDING)
    params = models.JSONField(default=dict, help_text='Input parameters for the task')
    result = models.JSONField(null=True, blank=True, help_text='Task output data')
    error = models.TextField(blank=True, default='')
    progress = models.IntegerField(default=0, help_text='Progress percentage 0-100')
    status_message = models.CharField(
        max_length=500, blank=True, default='',
        help_text='Human-readable status message for the current step',
    )
    total_items = models.IntegerField(
        default=0, help_text='Total number of items to process',
    )
    processed_items = models.IntegerField(
        default=0, help_text='Number of items processed so far',
    )
    estimated_completion = models.DateTimeField(
        null=True, blank=True,
        help_text='Estimated time of completion',
    )
    celery_task_id = models.CharField(max_length=255, blank=True, default='')
    started_at = models.DateTimeField(
        null=True, blank=True,
        help_text='When the task actually started running',
    )
    completed_at = models.DateTimeField(
        null=True, blank=True,
        help_text='When the task finished (completed or failed)',
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', '-created_at']),
            models.Index(fields=['status']),
        ]

    def __str__(self):
        return f'{self.get_task_type_display()} - {self.get_status_display()}'

    def mark_running(self):
        self.status = self.Status.RUNNING
        self.started_at = timezone.now()
        self.status_message = 'Starting...'
        self.save(update_fields=[
            'status', 'started_at', 'status_message', 'updated_at',
        ])

    def mark_completed(self, result):
        self.status = self.Status.COMPLETED
        self.result = result
        self.progress = 100
        self.completed_at = timezone.now()
        self.status_message = 'Completed'
        self.estimated_completion = None
        self.save(update_fields=[
            'status', 'result', 'progress', 'completed_at',
            'status_message', 'estimated_completion', 'updated_at',
        ])

    def mark_failed(self, error_message):
        self.status = self.Status.FAILED
        self.error = error_message
        self.completed_at = timezone.now()
        self.status_message = 'Failed'
        self.estimated_completion = None
        self.save(update_fields=[
            'status', 'error', 'completed_at', 'status_message',
            'estimated_completion', 'updated_at',
        ])

    def mark_cancelled(self):
        self.status = self.Status.CANCELLED
        self.completed_at = timezone.now()
        self.status_message = 'Cancelled'
        self.estimated_completion = None
        self.save(update_fields=[
            'status', 'completed_at', 'status_message',
            'estimated_completion', 'updated_at',
        ])

    def update_progress(self, progress, message='', processed=None, total=None):
        self.progress = progress
        if message:
            self.status_message = message
        if processed is not None:
            self.processed_items = processed
        if total is not None:
            self.total_items = total

        # Estimate completion time based on processing rate
        if (self.started_at and processed and total and processed > 0
                and progress < 100):
            elapsed = (timezone.now() - self.started_at).total_seconds()
            rate = processed / elapsed  # items per second
            remaining = total - processed
            if rate > 0:
                eta_seconds = remaining / rate
                self.estimated_completion = (
                    timezone.now() + timezone.timedelta(seconds=eta_seconds)
                )

        self.save(update_fields=[
            'progress', 'status_message', 'processed_items',
            'total_items', 'estimated_completion', 'updated_at',
        ])
