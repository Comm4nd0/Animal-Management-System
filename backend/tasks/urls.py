from django.urls import path
from . import views

urlpatterns = [
    path('pedigree/', views.create_pedigree_task, name='task-pedigree'),
    path('breeding-suggestions/', views.create_breeding_suggestions_task, name='task-breeding-suggestions'),
    path('coi/', views.create_coi_task, name='task-coi'),
    path('<uuid:task_id>/', views.get_task_status, name='task-status'),
]
