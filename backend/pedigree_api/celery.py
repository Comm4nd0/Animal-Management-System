"""
Celery application configuration for the Pedigree API.

Provides background task processing for expensive operations like
pedigree tree computation and breeding suggestion analysis.
"""

import os
from celery import Celery

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'pedigree_api.settings')

app = Celery('pedigree_api')

# Load config from Django settings, using the CELERY_ namespace.
app.config_from_object('django.conf:settings', namespace='CELERY')

# Auto-discover tasks in all installed apps.
app.autodiscover_tasks()
