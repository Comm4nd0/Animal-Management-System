from django.contrib import admin
from .models import Animal, HealthRecord, BreedingRecord, Litter, CustomFieldDefinition, Contact


@admin.register(Contact)
class ContactAdmin(admin.ModelAdmin):
    list_display = ['name', 'farm_name', 'email', 'phone', 'prefix']
    search_fields = ['name', 'farm_name', 'email', 'prefix']
    raw_id_fields = ['account']


@admin.register(Animal)
class AnimalAdmin(admin.ModelAdmin):
    list_display = ['name', 'species', 'breed', 'sex', 'status', 'date_of_birth']
    list_filter = ['species', 'breed', 'sex', 'status']
    search_fields = ['name', 'breed', 'registration_number', 'microchip_number']
    raw_id_fields = ['sire', 'dam', 'breeder', 'current_owner']


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


@admin.register(CustomFieldDefinition)
class CustomFieldDefinitionAdmin(admin.ModelAdmin):
    list_display = ['name', 'field_key', 'field_type', 'required', 'owner', 'display_order']
    list_filter = ['field_type', 'required']
    search_fields = ['name', 'field_key']
    raw_id_fields = ['owner']
