"""
Add background job infrastructure: new task types, user ownership,
ETA tracking, progress messaging, and cancellation support.
"""

from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('tasks', '0001_initial'),
    ]

    operations = [
        # Add user foreign key
        migrations.AddField(
            model_name='backgroundtask',
            name='user',
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.CASCADE,
                related_name='background_tasks',
                to=settings.AUTH_USER_MODEL,
            ),
        ),

        # Add status message
        migrations.AddField(
            model_name='backgroundtask',
            name='status_message',
            field=models.CharField(
                blank=True,
                default='',
                help_text='Human-readable status message for the current step',
                max_length=500,
            ),
        ),

        # Add item tracking fields
        migrations.AddField(
            model_name='backgroundtask',
            name='total_items',
            field=models.IntegerField(
                default=0,
                help_text='Total number of items to process',
            ),
        ),
        migrations.AddField(
            model_name='backgroundtask',
            name='processed_items',
            field=models.IntegerField(
                default=0,
                help_text='Number of items processed so far',
            ),
        ),

        # Add ETA field
        migrations.AddField(
            model_name='backgroundtask',
            name='estimated_completion',
            field=models.DateTimeField(
                blank=True,
                null=True,
                help_text='Estimated time of completion',
            ),
        ),

        # Add timing fields
        migrations.AddField(
            model_name='backgroundtask',
            name='started_at',
            field=models.DateTimeField(
                blank=True,
                null=True,
                help_text='When the task actually started running',
            ),
        ),
        migrations.AddField(
            model_name='backgroundtask',
            name='completed_at',
            field=models.DateTimeField(
                blank=True,
                null=True,
                help_text='When the task finished (completed or failed)',
            ),
        ),

        # Update task_type choices to include new types
        migrations.AlterField(
            model_name='backgroundtask',
            name='task_type',
            field=models.IntegerField(
                choices=[
                    (0, 'Pedigree Tree'),
                    (1, 'Breeding Suggestions'),
                    (2, 'COI Calculation'),
                    (3, 'Bulk Import'),
                    (4, 'Bulk Export'),
                    (5, 'Dashboard Statistics'),
                ],
            ),
        ),

        # Update status choices to include Cancelled
        migrations.AlterField(
            model_name='backgroundtask',
            name='status',
            field=models.IntegerField(
                choices=[
                    (0, 'Pending'),
                    (1, 'Running'),
                    (2, 'Completed'),
                    (3, 'Failed'),
                    (4, 'Cancelled'),
                ],
                default=0,
            ),
        ),

        # Add indexes
        migrations.AddIndex(
            model_name='backgroundtask',
            index=models.Index(
                fields=['user', '-created_at'],
                name='tasks_backg_user_id_created_idx',
            ),
        ),
        migrations.AddIndex(
            model_name='backgroundtask',
            index=models.Index(
                fields=['status'],
                name='tasks_backg_status_idx',
            ),
        ),
    ]
