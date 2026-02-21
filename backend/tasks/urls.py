from django.urls import path
from . import views

urlpatterns = [
    # Task creation endpoints
    path('pedigree/', views.create_pedigree_task, name='task-pedigree'),
    path('breeding-suggestions/', views.create_breeding_suggestions_task, name='task-breeding-suggestions'),
    path('coi/', views.create_coi_task, name='task-coi'),
    path('bulk-import/', views.create_bulk_import_task, name='task-bulk-import'),
    path('bulk-export/', views.create_bulk_export_task, name='task-bulk-export'),
    path('dashboard-stats/', views.create_dashboard_stats_task, name='task-dashboard-stats'),

    # Job management endpoints
    path('list/', views.list_user_tasks, name='task-list'),
    path('active/', views.active_user_tasks, name='task-active'),
    path('<uuid:task_id>/', views.get_task_status, name='task-status'),
    path('<uuid:task_id>/cancel/', views.cancel_task, name='task-cancel'),
    path('<uuid:task_id>/retry/', views.retry_task, name='task-retry'),
]
