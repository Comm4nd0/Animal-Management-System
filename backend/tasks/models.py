import uuid
from django.db import models


class BackgroundTask(models.Model):
    """Tracks the status and result of long-running background jobs."""

    class Status(models.IntegerChoices):
        PENDING = 0, 'Pending'
        RUNNING = 1, 'Running'
        COMPLETED = 2, 'Completed'
        FAILED = 3, 'Failed'

    class TaskType(models.IntegerChoices):
        PEDIGREE_TREE = 0, 'Pedigree Tree'
        BREEDING_SUGGESTIONS = 1, 'Breeding Suggestions'
        COI_CALCULATION = 2, 'COI Calculation'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    task_type = models.IntegerField(choices=TaskType.choices)
    status = models.IntegerField(choices=Status.choices, default=Status.PENDING)
    params = models.JSONField(default=dict, help_text='Input parameters for the task')
    result = models.JSONField(null=True, blank=True, help_text='Task output data')
    error = models.TextField(blank=True, default='')
    progress = models.IntegerField(default=0, help_text='Progress percentage 0-100')
    celery_task_id = models.CharField(max_length=255, blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'{self.get_task_type_display()} - {self.get_status_display()}'

    def mark_running(self):
        self.status = self.Status.RUNNING
        self.save(update_fields=['status', 'updated_at'])

    def mark_completed(self, result):
        self.status = self.Status.COMPLETED
        self.result = result
        self.progress = 100
        self.save(update_fields=['status', 'result', 'progress', 'updated_at'])

    def mark_failed(self, error_message):
        self.status = self.Status.FAILED
        self.error = error_message
        self.save(update_fields=['status', 'error', 'updated_at'])

    def update_progress(self, progress):
        self.progress = progress
        self.save(update_fields=['progress', 'updated_at'])
