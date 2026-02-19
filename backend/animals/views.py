from django.core.exceptions import ValidationError as DjangoValidationError
from django.db import models as db_models
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework.filters import SearchFilter, OrderingFilter

from .models import Animal, HealthRecord, BreedingRecord, Litter, CustomFieldDefinition, Contact
from .serializers import (
    AnimalListSerializer,
    AnimalDetailSerializer,
    HealthRecordSerializer,
    BreedingRecordSerializer,
    LitterSerializer,
    CustomFieldDefinitionSerializer,
    ContactSerializer,
)


def _get_user_profile(request):
    """Get the UserProfile for the authenticated user, or None."""
    if not request.user.is_authenticated:
        return None
    try:
        return request.user.profile
    except Exception:
        return None


class AnimalViewSet(viewsets.ModelViewSet):
    """
    CRUD API for animals.

    Tier enforcement:
    - On create, validates the animal count and breed against the user's service tier.
    - Non-Enterprise tiers are locked to a single breed (set by the first animal added).
    - Enterprise tier allows unlimited animals and multiple species/breeds.
    """
    queryset = Animal.objects.all()
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    filterset_fields = ['species', 'breed', 'sex', 'status']
    search_fields = ['name', 'breed', 'registration_number', 'microchip_number']
    ordering_fields = ['name', 'date_of_birth', 'breed', 'created_at']
    ordering = ['name']

    def get_serializer_class(self):
        if self.action == 'list':
            return AnimalListSerializer
        return AnimalDetailSerializer

    def get_queryset(self):
        """
        Filter animals by the authenticated user's account and
        apply custom field filters from query params.

        Custom field filters use the prefix 'cf_':
            ?cf_ear_tag=ABC123
            ?cf_horn_status=Polled
        """
        qs = super().get_queryset()
        profile = _get_user_profile(self.request)
        if profile is not None:
            qs = qs.filter(account=profile)

        # Apply custom field filters (params prefixed with 'cf_')
        for param, value in self.request.query_params.items():
            if param.startswith('cf_'):
                field_key = param[3:]  # strip 'cf_' prefix
                qs = qs.filter(
                    **{f'custom_fields__{field_key}__icontains': value}
                )

        return qs

    def create(self, request, *args, **kwargs):
        """
        Create an animal with tier-based validation.

        Checks:
        1. Has the user reached their animal limit?
        2. Is the species/breed allowed for this account's tier?
        """
        profile = _get_user_profile(request)

        if profile is not None:
            species = request.data.get('species', '')
            breed = request.data.get('breed', '')

            is_valid, error_msg = profile.validate_animal_addition(species, breed)
            if not is_valid:
                return Response(
                    {'error': error_msg, 'tier': profile.tier_label},
                    status=status.HTTP_403_FORBIDDEN,
                )

        response = super().create(request, *args, **kwargs)

        # Lock breed on first animal for non-Enterprise tiers
        if profile is not None and response.status_code == 201:
            species = request.data.get('species', '')
            breed = request.data.get('breed', '')
            profile.lock_breed(species, breed)

        return response

    def perform_create(self, serializer):
        """Automatically assign the animal to the authenticated user."""
        profile = _get_user_profile(self.request)
        try:
            if profile is not None:
                serializer.save(account=profile)
            else:
                serializer.save()
        except DjangoValidationError as e:
            from rest_framework.exceptions import ValidationError
            raise ValidationError(e.message_dict if hasattr(e, 'message_dict') else {'detail': e.messages})

    def perform_update(self, serializer):
        """Validate pedigree integrity on update."""
        try:
            serializer.save()
        except DjangoValidationError as e:
            from rest_framework.exceptions import ValidationError
            raise ValidationError(e.message_dict if hasattr(e, 'message_dict') else {'detail': e.messages})

    @action(detail=True, methods=['get'])
    def offspring(self, request, pk=None):
        """Get all direct offspring of this animal."""
        animal = self.get_object()
        offspring = Animal.objects.filter(
            sire=animal
        ) | Animal.objects.filter(dam=animal)
        serializer = AnimalListSerializer(offspring, many=True)
        return Response(serializer.data)

    @action(detail=True, methods=['get'])
    def health_records(self, request, pk=None):
        """Get all health records for this animal."""
        animal = self.get_object()
        records = HealthRecord.objects.filter(animal=animal)
        serializer = HealthRecordSerializer(records, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=['get'])
    def stats(self, request):
        """Get aggregate statistics for the user's animals."""
        qs = self.get_queryset()
        total = qs.count()
        males = qs.filter(sex=Animal.Sex.MALE).count()
        females = qs.filter(sex=Animal.Sex.FEMALE).count()
        breeds = qs.values('breed').distinct().count()
        species = qs.values('species').distinct().count()
        alive = qs.filter(status=Animal.Status.ALIVE).count()

        result = {
            'total': total,
            'males': males,
            'females': females,
            'breeds': breeds,
            'species': species,
            'alive': alive,
        }

        # Include tier info if authenticated
        profile = _get_user_profile(request)
        if profile is not None:
            result['tier'] = profile.tier_label
            result['max_animals'] = profile.max_animals
            result['animals_remaining'] = profile.animals_remaining()
            result['allows_multi_breed'] = profile.allows_multi_breed
            result['registered_breed'] = profile.registered_breed or None
            result['registered_species'] = profile.registered_species or None

        return Response(result)

    @action(detail=False, methods=['get'])
    def search(self, request):
        """
        Search animals by query string.
        Searches standard fields and all custom field values.
        """
        query = request.query_params.get('q', '')
        if not query:
            return Response([])

        base_qs = self.get_queryset()
        # Search standard fields
        standard_q = (
            db_models.Q(name__icontains=query)
            | db_models.Q(breed__icontains=query)
            | db_models.Q(registration_number__icontains=query)
            | db_models.Q(microchip_number__icontains=query)
        )

        # Also search across all custom_fields values using JSON containment
        # This finds any animal whose custom_fields JSON contains the query text
        animals = base_qs.filter(standard_q)

        # Additionally search custom fields by checking if any value matches
        custom_matches = base_qs.exclude(
            custom_fields={},
        ).extra(
            where=["CAST(custom_fields AS TEXT) ILIKE %s"],
            params=[f'%{query}%'],
        )
        animals = (animals | custom_matches).distinct()[:25]

        serializer = AnimalListSerializer(animals, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=['post'], url_path='import')
    def bulk_import(self, request):
        """
        Bulk import animals from CSV or JSON.

        Accepts multipart/form-data with a 'file' field (.csv or .json).
        Uses bulk_create in batches for performance with large datasets.
        Skips pedigree validation during bulk insert and returns a
        summary so the user can run a data audit afterwards.
        """
        import csv
        import io
        import json as json_lib
        import uuid as uuid_lib

        uploaded = request.FILES.get('file')
        if not uploaded:
            return Response(
                {'error': 'No file provided.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        profile = _get_user_profile(request)
        filename = uploaded.name.lower()
        errors = []
        animals_to_create = []

        if filename.endswith('.json'):
            try:
                data = json_lib.loads(uploaded.read().decode('utf-8'))
                if not isinstance(data, list):
                    return Response(
                        {'error': 'JSON must be an array of objects.'},
                        status=status.HTTP_400_BAD_REQUEST,
                    )
            except (json_lib.JSONDecodeError, UnicodeDecodeError) as e:
                return Response(
                    {'error': f'Invalid JSON: {e}'},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            for i, obj in enumerate(data):
                try:
                    animal = self._parse_import_row(obj, profile, uuid_lib)
                    animals_to_create.append(animal)
                except Exception as e:
                    errors.append({'row': i + 1, 'error': str(e)})

        elif filename.endswith('.csv'):
            try:
                content = uploaded.read().decode('utf-8')
                reader = csv.DictReader(io.StringIO(content))
            except UnicodeDecodeError as e:
                return Response(
                    {'error': f'Cannot read file: {e}'},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            for i, row in enumerate(reader):
                # Normalise keys
                norm = {self._normalise_key(k): v for k, v in row.items()}
                try:
                    animal = self._parse_import_row(norm, profile, uuid_lib)
                    animals_to_create.append(animal)
                except Exception as e:
                    errors.append({'row': i + 2, 'error': str(e)})
        else:
            return Response(
                {'error': 'Unsupported file type. Use .csv or .json.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Batch create (ignoring conflicts on existing IDs)
        batch_size = 500
        created = 0
        for i in range(0, len(animals_to_create), batch_size):
            batch = animals_to_create[i:i + batch_size]
            Animal.objects.bulk_create(batch, ignore_conflicts=True, batch_size=batch_size)
            created += len(batch)

        return Response({
            'total_rows': len(animals_to_create) + len(errors),
            'imported': created,
            'skipped': len(errors),
            'errors': errors[:100],  # Cap error details
        }, status=status.HTTP_201_CREATED)

    @action(detail=False, methods=['get'], url_path='export')
    def bulk_export(self, request):
        """
        Export animals as CSV or JSON.

        Query params:
            format: 'csv' or 'json' (default: csv)
        Uses streaming response for large datasets.
        """
        import csv
        import io

        export_format = request.query_params.get('format', 'csv')
        qs = self.get_queryset()

        if export_format == 'json':
            from django.http import JsonResponse
            data = []
            for animal in qs.iterator(chunk_size=500):
                data.append({
                    'id': str(animal.pk),
                    'name': animal.name,
                    'species': animal.species,
                    'breed': animal.breed,
                    'sex': animal.get_sex_display(),
                    'status': animal.get_status_display(),
                    'date_of_birth': str(animal.date_of_birth) if animal.date_of_birth else None,
                    'date_of_death': str(animal.date_of_death) if animal.date_of_death else None,
                    'color': animal.color,
                    'markings': animal.markings,
                    'registration_number': animal.registration_number,
                    'microchip_number': animal.microchip_number,
                    'dna_profile_id': animal.dna_profile_id,
                    'sire_id': str(animal.sire_id) if animal.sire_id else None,
                    'dam_id': str(animal.dam_id) if animal.dam_id else None,
                    'weight': float(animal.weight) if animal.weight else None,
                    'height': float(animal.height) if animal.height else None,
                    'notes': animal.notes,
                    'custom_fields': animal.custom_fields,
                })
            return JsonResponse(data, safe=False)

        # CSV export
        from django.http import HttpResponse
        response = HttpResponse(content_type='text/csv')
        response['Content-Disposition'] = 'attachment; filename="animals_export.csv"'

        writer = csv.writer(response)
        headers = [
            'id', 'name', 'species', 'breed', 'sex', 'status',
            'date_of_birth', 'date_of_death', 'color', 'markings',
            'registration_number', 'microchip_number', 'dna_profile_id',
            'sire_id', 'dam_id', 'weight', 'height', 'notes',
        ]
        writer.writerow(headers)

        for animal in qs.iterator(chunk_size=500):
            writer.writerow([
                str(animal.pk),
                animal.name,
                animal.species,
                animal.breed,
                animal.get_sex_display(),
                animal.get_status_display(),
                animal.date_of_birth or '',
                animal.date_of_death or '',
                animal.color,
                animal.markings,
                animal.registration_number,
                animal.microchip_number,
                animal.dna_profile_id,
                animal.sire_id or '',
                animal.dam_id or '',
                animal.weight or '',
                animal.height or '',
                animal.notes,
            ])

        return response

    @staticmethod
    def _normalise_key(key):
        """Normalise CSV header to snake_case."""
        import re
        s = re.sub(r'([a-z])([A-Z])', r'\1_\2', key.strip())
        s = re.sub(r'[\s\-]+', '_', s)
        return s.lower()

    @staticmethod
    def _parse_import_row(row, profile, uuid_lib):
        """Parse a dict into an Animal instance for bulk_create."""
        from datetime import date

        def get(key, default=''):
            v = row.get(key, default)
            if v is None:
                return ''
            return str(v).strip()

        name = get('name')
        species = get('species')
        breed = get('breed')

        if not name:
            raise ValueError('Missing required field: name')
        if not species:
            raise ValueError('Missing required field: species')
        if not breed:
            raise ValueError('Missing required field: breed')

        # Parse sex
        sex_str = get('sex', 'unknown').lower()
        sex_map = {
            'male': Animal.Sex.MALE, 'm': Animal.Sex.MALE, '0': Animal.Sex.MALE,
            'female': Animal.Sex.FEMALE, 'f': Animal.Sex.FEMALE, '1': Animal.Sex.FEMALE,
        }
        sex = sex_map.get(sex_str, Animal.Sex.UNKNOWN)

        # Parse status
        status_str = get('status', 'alive').lower()
        status_map = {
            'alive': Animal.Status.ALIVE, '0': Animal.Status.ALIVE,
            'deceased': Animal.Status.DECEASED, 'dead': Animal.Status.DECEASED, '1': Animal.Status.DECEASED,
            'sold': Animal.Status.SOLD, '2': Animal.Status.SOLD,
            'transferred': Animal.Status.TRANSFERRED, '3': Animal.Status.TRANSFERRED,
        }
        animal_status = status_map.get(status_str, Animal.Status.ALIVE)

        def parse_date(val):
            if not val:
                return None
            try:
                return date.fromisoformat(val)
            except ValueError:
                return None

        def parse_decimal(val):
            if not val:
                return None
            try:
                from decimal import Decimal
                return Decimal(val)
            except Exception:
                return None

        def parse_uuid(val):
            if not val:
                return None
            try:
                return uuid_lib.UUID(val)
            except ValueError:
                return None

        animal_id = get('id')
        pk = uuid_lib.UUID(animal_id) if animal_id else uuid_lib.uuid4()

        return Animal(
            pk=pk,
            name=name,
            species=species,
            breed=breed,
            sex=sex,
            status=animal_status,
            date_of_birth=parse_date(get('date_of_birth') or get('dob')),
            date_of_death=parse_date(get('date_of_death')),
            color=get('color'),
            markings=get('markings'),
            registration_number=get('registration_number') or get('reg_number'),
            microchip_number=get('microchip_number') or get('microchip'),
            dna_profile_id=get('dna_profile_id'),
            sire_id=parse_uuid(get('sire_id') or get('sire')),
            dam_id=parse_uuid(get('dam_id') or get('dam')),
            weight=parse_decimal(get('weight')),
            height=parse_decimal(get('height')),
            notes=get('notes'),
            account=profile,
        )


class HealthRecordViewSet(viewsets.ModelViewSet):
    """
    CRUD API for health records.
    Filter by animal: GET /api/v1/health-records/?animal={uuid}
    """
    queryset = HealthRecord.objects.all()
    serializer_class = HealthRecordSerializer
    filter_backends = [DjangoFilterBackend, OrderingFilter]
    filterset_fields = ['animal', 'type']
    ordering_fields = ['date', 'created_at']
    ordering = ['-date']

    @action(detail=False, methods=['get'])
    def upcoming(self, request):
        """Get health records that are due within 30 days."""
        from datetime import date, timedelta
        today = date.today()
        upcoming_date = today + timedelta(days=30)
        records = HealthRecord.objects.filter(
            next_due_date__gte=today,
            next_due_date__lte=upcoming_date,
        )
        serializer = self.get_serializer(records, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=['get'])
    def overdue(self, request):
        """Get health records that are overdue."""
        from datetime import date
        records = HealthRecord.objects.filter(
            next_due_date__lt=date.today(),
        )
        serializer = self.get_serializer(records, many=True)
        return Response(serializer.data)


class BreedingRecordViewSet(viewsets.ModelViewSet):
    """
    CRUD API for breeding records.
    Filter by sire/dam: GET /api/v1/breeding-records/?sire={uuid}&dam={uuid}
    """
    queryset = BreedingRecord.objects.all()
    serializer_class = BreedingRecordSerializer
    filter_backends = [DjangoFilterBackend, OrderingFilter]
    filterset_fields = ['sire', 'dam', 'status']
    ordering_fields = ['breeding_date', 'created_at']
    ordering = ['-breeding_date']

    @action(detail=False, methods=['get'])
    def active(self, request):
        """Get all active (non-completed, non-cancelled) breeding records."""
        active_statuses = [
            BreedingRecord.Status.PLANNED,
            BreedingRecord.Status.CONFIRMED,
            BreedingRecord.Status.PREGNANT,
            BreedingRecord.Status.WHELPING,
        ]
        records = BreedingRecord.objects.filter(status__in=active_statuses)
        serializer = self.get_serializer(records, many=True)
        return Response(serializer.data)


class LitterViewSet(viewsets.ModelViewSet):
    """
    CRUD API for litters.
    Filter by sire/dam: GET /api/v1/litters/?sire={uuid}&dam={uuid}
    """
    queryset = Litter.objects.all()
    serializer_class = LitterSerializer
    filter_backends = [DjangoFilterBackend, OrderingFilter]
    filterset_fields = ['sire', 'dam']
    ordering_fields = ['date_of_birth', 'created_at']
    ordering = ['-date_of_birth']


class CustomFieldDefinitionViewSet(viewsets.ModelViewSet):
    """
    CRUD API for custom field definitions.

    Each user defines their own set of custom fields which are then available
    on all their animals. The actual field values are stored in each
    Animal's custom_fields JSONField.
    """
    queryset = CustomFieldDefinition.objects.all()
    serializer_class = CustomFieldDefinitionSerializer
    filter_backends = [OrderingFilter]
    ordering_fields = ['display_order', 'name', 'created_at']
    ordering = ['display_order', 'name']

    def get_queryset(self):
        """Only return field definitions owned by the authenticated user."""
        qs = super().get_queryset()
        profile = _get_user_profile(self.request)
        if profile is not None:
            qs = qs.filter(owner=profile)
        return qs

    def perform_create(self, serializer):
        """Automatically assign the definition to the authenticated user."""
        profile = _get_user_profile(self.request)
        if profile is not None:
            serializer.save(owner=profile)
        else:
            serializer.save()


class ContactViewSet(viewsets.ModelViewSet):
    """
    CRUD API for contacts (breeders and owners).

    Contacts are scoped to the authenticated user's account.
    The same contact can be assigned as a breeder on one animal
    and current owner on another.
    """
    queryset = Contact.objects.all()
    serializer_class = ContactSerializer
    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]
    search_fields = ['name', 'farm_name', 'email', 'prefix']
    ordering_fields = ['name', 'created_at']
    ordering = ['name']

    def get_queryset(self):
        """Only return contacts belonging to the authenticated user."""
        qs = super().get_queryset()
        profile = _get_user_profile(self.request)
        if profile is not None:
            qs = qs.filter(account=profile)
        return qs

    def perform_create(self, serializer):
        """Auto-assign the contact to the authenticated user's account."""
        profile = _get_user_profile(self.request)
        if profile is not None:
            serializer.save(account=profile)
        else:
            serializer.save()
