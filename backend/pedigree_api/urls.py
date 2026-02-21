"""URL configuration for pedigree_api project."""

from django.contrib import admin
from django.urls import path, include, re_path
from rest_framework.routers import DefaultRouter
from accounts.views import AccountViewSet
from animals.views import (
    AnimalViewSet,
    HealthRecordViewSet,
    BreedingRecordViewSet,
    LitterViewSet,
    CustomFieldDefinitionViewSet,
    ContactViewSet,
    WeightRecordViewSet,
    ShowResultViewSet,
    FinancialRecordViewSet,
    DocumentAttachmentViewSet,
)
from genetics.views import GeneticsViewSet
from support.views import SupportViewSet
from .views import frontend

router = DefaultRouter()
router.register(r'accounts', AccountViewSet, basename='account')
router.register(r'animals', AnimalViewSet, basename='animal')
router.register(r'health-records', HealthRecordViewSet, basename='health-record')
router.register(r'breeding-records', BreedingRecordViewSet, basename='breeding-record')
router.register(r'litters', LitterViewSet, basename='litter')
router.register(r'custom-fields', CustomFieldDefinitionViewSet, basename='custom-field')
router.register(r'contacts', ContactViewSet, basename='contact')
router.register(r'weight-records', WeightRecordViewSet, basename='weight-record')
router.register(r'show-results', ShowResultViewSet, basename='show-result')
router.register(r'financial-records', FinancialRecordViewSet, basename='financial-record')
router.register(r'documents', DocumentAttachmentViewSet, basename='document')
router.register(r'genetics', GeneticsViewSet, basename='genetics')
router.register(r'support', SupportViewSet, basename='support')

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/v1/', include(router.urls)),
    path('api/auth/', include('rest_framework.urls')),
    # Flutter web frontend catch-all (must be last)
    re_path(r'^(?!admin/|api/|static/).*$', frontend, name='frontend'),
]
