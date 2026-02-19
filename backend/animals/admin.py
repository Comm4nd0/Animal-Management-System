from django.contrib import admin
from .models import Animal, HealthRecord, BreedingRecord, Litter


@admin.register(Animal)
class AnimalAdmin(admin.ModelAdmin):
    list_display = ['name', 'species', 'breed', 'sex', 'status', 'date_of_birth']
    list_filter = ['species', 'breed', 'sex', 'status']
    search_fields = ['name', 'breed', 'registration_number', 'microchip_number']
    raw_id_fields = ['sire', 'dam']


@admin.register(HealthRecord)
class HealthRecordAdmin(admin.ModelAdmin):
    list_display = ['title', 'animal', 'type', 'date', 'next_due_date']
    list_filter = ['type', 'date']
    search_fields = ['title', 'animal__name']
    raw_id_fields = ['animal']


@admin.register(BreedingRecord)
class BreedingRecordAdmin(admin.ModelAdmin):
    list_display = ['sire', 'dam', 'breeding_date', 'status']
    list_filter = ['status']
    raw_id_fields = ['sire', 'dam', 'litter']


@admin.register(Litter)
class LitterAdmin(admin.ModelAdmin):
    list_display = ['sire', 'dam', 'date_of_birth', 'total_puppies']
    raw_id_fields = ['sire', 'dam']
