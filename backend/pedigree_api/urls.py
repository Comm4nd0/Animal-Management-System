"""URL configuration for pedigree_api project."""

from django.contrib import admin
from django.urls import path, include
from rest_framework.routers import DefaultRouter
from animals.views import (
    AnimalViewSet,
    HealthRecordViewSet,
    BreedingRecordViewSet,
    LitterViewSet,
)
from genetics.views import GeneticsViewSet

router = DefaultRouter()
router.register(r'animals', AnimalViewSet, basename='animal')
router.register(r'health-records', HealthRecordViewSet, basename='health-record')
router.register(r'breeding-records', BreedingRecordViewSet, basename='breeding-record')
router.register(r'litters', LitterViewSet, basename='litter')
router.register(r'genetics', GeneticsViewSet, basename='genetics')

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/v1/', include(router.urls)),
    path('api/auth/', include('rest_framework.urls')),
]
