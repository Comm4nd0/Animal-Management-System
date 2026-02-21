import uuid
from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = []

    operations = [
        migrations.CreateModel(
            name='BackgroundTask',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('task_type', models.IntegerField(choices=[(0, 'Pedigree Tree'), (1, 'Breeding Suggestions'), (2, 'COI Calculation')])),
                ('status', models.IntegerField(choices=[(0, 'Pending'), (1, 'Running'), (2, 'Completed'), (3, 'Failed')], default=0)),
                ('params', models.JSONField(default=dict, help_text='Input parameters for the task')),
                ('result', models.JSONField(blank=True, help_text='Task output data', null=True)),
                ('error', models.TextField(blank=True, default='')),
                ('progress', models.IntegerField(default=0, help_text='Progress percentage 0-100')),
                ('celery_task_id', models.CharField(blank=True, default='', max_length=255)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
            ],
            options={
                'ordering': ['-created_at'],
            },
        ),
    ]
