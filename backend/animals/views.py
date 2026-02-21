from django.core.exceptions import ValidationError as DjangoValidationError
from django.db import models as db_models
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework.filters import SearchFilter, OrderingFilter

from rest_framework.parsers import MultiPartParser, FormParser

from accounts.permissions import ReadOnlyForReadOnlyUsers
from .models import Animal, AnimalImage, HealthRecord, BreedingRecord, Litter, CustomFieldDefinition, Contact, WeightRecord, ShowResult, FinancialRecord, DocumentAttachment
from .serializers import (
    AnimalListSerializer,
    AnimalDetailSerializer,
    AnimalImageSerializer,
    HealthRecordSerializer,
    BreedingRecordSerializer,
    LitterSerializer,
    CustomFieldDefinitionSerializer,
    ContactSerializer,
    WeightRecordSerializer,
    ShowResultSerializer,
    FinancialRecordSerializer,
    DocumentAttachmentSerializer,
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

    Role enforcement:
    - Read-only users can only perform GET requests.
    - Contributors, admins, and owners can perform all CRUD operations.
    """
    queryset = Animal.objects.all()
    permission_classes = [ReadOnlyForReadOnlyUsers]
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
        else:
            return qs.none()

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

    @action(detail=False, methods=['get'], url_path='dashboard-stats')
    def dashboard_stats(self, request):
        """
        Aggregated stats for the dashboard charts:
        - registration_timeline: animals added per month
        - sex_distribution: count per sex
        - status_distribution: count per status
        - breed_distribution: count per breed (top 10 + others)
        - age_distribution: count per age cohort
        - genetic_diversity: unique sires/dams, average COI, etc.
        - health_summary: count per health record type
        """
        from collections import Counter
        from datetime import date
        from django.db.models.functions import TruncMonth

        qs = self.get_queryset()

        # ── Registration timeline (animals created per month) ─────
        from django.db.models.functions import TruncMonth
        timeline_qs = (
            qs.annotate(month=TruncMonth('created_at'))
            .values('month')
            .annotate(count=db_models.Count('id'))
            .order_by('month_trunc')
        )
        registration_timeline = [
            {
                'month': row['month'].strftime('%Y-%m') if row['month'] else None,
                'count': row['count'],
            }
            for row in timeline_qs
        ]

        # ── Sex distribution ──────────────────────────────────────
        sex_counts = qs.values('sex').annotate(count=db_models.Count('id'))
        sex_labels = {0: 'Male', 1: 'Female', 2: 'Unknown'}
        sex_distribution = [
            {'label': sex_labels.get(row['sex'], 'Unknown'), 'value': row['count']}
            for row in sex_counts
        ]

        # ── Status distribution ───────────────────────────────────
        status_counts = qs.values('status').annotate(count=db_models.Count('id'))
        status_labels = {0: 'Alive', 1: 'Deceased', 2: 'Sold', 3: 'Transferred'}
        status_distribution = [
            {'label': status_labels.get(row['status'], 'Other'), 'value': row['count']}
            for row in status_counts
        ]

        # ── Breed distribution (top 10) ───────────────────────────
        breed_counts = (
            qs.values('breed')
            .annotate(count=db_models.Count('id'))
            .order_by('-count')
        )
        breed_list = list(breed_counts)
        if len(breed_list) > 10:
            top = breed_list[:10]
            others = sum(b['count'] for b in breed_list[10:])
            breed_distribution = [
                {'label': b['breed'], 'value': b['count']} for b in top
            ]
            breed_distribution.append({'label': 'Other', 'value': others})
        else:
            breed_distribution = [
                {'label': b['breed'], 'value': b['count']} for b in breed_list
            ]

        # ── Age distribution (cohorts) ────────────────────────────
        today = date.today()
        age_buckets = Counter()
        for dob in qs.exclude(date_of_birth=None).values_list('date_of_birth', flat=True):
            age_years = (today - dob).days / 365.25
            if age_years < 1:
                age_buckets['< 1 yr'] += 1
            elif age_years < 3:
                age_buckets['1-2 yrs'] += 1
            elif age_years < 6:
                age_buckets['3-5 yrs'] += 1
            elif age_years < 10:
                age_buckets['6-9 yrs'] += 1
            else:
                age_buckets['10+ yrs'] += 1
        unknown_age = qs.filter(date_of_birth=None).count()
        if unknown_age:
            age_buckets['Unknown'] = unknown_age
        age_order = ['< 1 yr', '1-2 yrs', '3-5 yrs', '6-9 yrs', '10+ yrs', 'Unknown']
        age_distribution = [
            {'label': label, 'value': age_buckets.get(label, 0)}
            for label in age_order
            if age_buckets.get(label, 0) > 0
        ]

        # ── Genetic diversity ─────────────────────────────────────
        total = qs.count()
        unique_sires = qs.exclude(sire=None).values('sire').distinct().count()
        unique_dams = qs.exclude(dam=None).values('dam').distinct().count()
        animals_with_sire = qs.exclude(sire=None).count()
        animals_with_dam = qs.exclude(dam=None).count()

        coi_values = []
        for traits in qs.exclude(genetic_traits={}).values_list('genetic_traits', flat=True):
            if isinstance(traits, dict) and 'coi' in traits:
                try:
                    coi_values.append(float(traits['coi']))
                except (TypeError, ValueError):
                    pass

        avg_coi = sum(coi_values) / len(coi_values) if coi_values else None

        # Effective population size: Ne = (4 * Nm * Nf) / (Nm + Nf)
        effective_pop_size = None
        if unique_sires > 0 and unique_dams > 0:
            effective_pop_size = round(
                (4 * unique_sires * unique_dams) / (unique_sires + unique_dams), 1
            )

        genetic_diversity = {
            'total_animals': total,
            'unique_sires': unique_sires,
            'unique_dams': unique_dams,
            'animals_with_sire': animals_with_sire,
            'animals_with_dam': animals_with_dam,
            'average_coi': round(avg_coi, 4) if avg_coi is not None else None,
            'coi_sample_size': len(coi_values),
            'effective_population_size': effective_pop_size,
        }

        # ── Health summary ────────────────────────────────────────
        health_counts = (
            HealthRecord.objects.filter(animal__in=qs)
            .values('type')
            .annotate(count=db_models.Count('id'))
        )
        health_labels = {
            0: 'Vaccination', 1: 'Examination', 2: 'Surgery',
            3: 'Medication', 4: 'Lab Test', 5: 'Deworming',
            6: 'Dental', 7: 'Other',
        }
        health_summary = [
            {'label': health_labels.get(row['type'], 'Other'), 'value': row['count']}
            for row in health_counts
        ]

        # ── Counts (so the dashboard can show totals without loading all animals)
        males = qs.filter(sex=Animal.Sex.MALE).count()
        females = qs.filter(sex=Animal.Sex.FEMALE).count()
        breeds = qs.values('breed').distinct().count()
        species = qs.values('species').distinct().count()
        alive = qs.filter(status=Animal.Status.ALIVE).count()
        stats = {
            'total': total,
            'males': males,
            'females': females,
            'breeds': breeds,
            'species': species,
            'alive': alive,
        }

        # ── Recent animals (lightweight, most recently created, limit 5)
        recent_qs = qs.order_by('-created_at')[:5]
        recent_animals = AnimalListSerializer(
            recent_qs, many=True, context={'request': request},
        ).data

        # ── Health reminders (upcoming + overdue) ────────────────
        from datetime import timedelta
        upcoming_date = today + timedelta(days=30)
        animal_ids = qs.values_list('pk', flat=True)

        overdue_records = HealthRecord.objects.filter(
            animal_id__in=animal_ids,
            next_due_date__lt=today,
        ).select_related('animal').order_by('next_due_date')[:10]

        upcoming_records = HealthRecord.objects.filter(
            animal_id__in=animal_ids,
            next_due_date__gte=today,
            next_due_date__lte=upcoming_date,
        ).select_related('animal').order_by('next_due_date')[:10]

        health_reminders = {
            'overdue': [
                {
                    'id': str(r.pk),
                    'title': r.title,
                    'animal_id': str(r.animal_id),
                    'animal_name': r.animal.name,
                    'next_due_date': str(r.next_due_date),
                    'type': r.type,
                }
                for r in overdue_records
            ],
            'upcoming': [
                {
                    'id': str(r.pk),
                    'title': r.title,
                    'animal_id': str(r.animal_id),
                    'animal_name': r.animal.name,
                    'next_due_date': str(r.next_due_date),
                    'type': r.type,
                }
                for r in upcoming_records
            ],
        }

        # ── Active breedings ────────────────────────────────────
        active_statuses = [
            BreedingRecord.Status.PLANNED,
            BreedingRecord.Status.CONFIRMED,
            BreedingRecord.Status.PREGNANT,
            BreedingRecord.Status.WHELPING,
        ]
        active_breedings_qs = BreedingRecord.objects.filter(
            status__in=active_statuses,
        ).select_related('sire', 'dam')[:5]
        active_breedings = BreedingRecordSerializer(
            active_breedings_qs, many=True,
        ).data

        return Response({
            'stats': stats,
            'registration_timeline': registration_timeline,
            'sex_distribution': sex_distribution,
            'status_distribution': status_distribution,
            'breed_distribution': breed_distribution,
            'age_distribution': age_distribution,
            'genetic_diversity': genetic_diversity,
            'health_summary': health_summary,
            'recent_animals': recent_animals,
            'health_reminders': health_reminders,
            'active_breedings': active_breedings,
        })

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

        # Also search across all custom_fields values.
        # Use a database-agnostic approach: cast the JSONField to text
        # using Django's Value/CharField and filter with __icontains.
        from django.db.models import TextField
        from django.db.models.functions import Cast

        animals = base_qs.filter(standard_q)

        # Search custom fields by casting JSON to text
        custom_matches = base_qs.exclude(
            custom_fields={},
        ).annotate(
            custom_fields_text=Cast('custom_fields', output_field=TextField()),
        ).filter(
            custom_fields_text__icontains=query,
        )
        animals = (animals | custom_matches).distinct()[:25]

        serializer = AnimalListSerializer(animals, many=True)
        return Response(serializer.data)

    @action(detail=True, methods=['get', 'post'], url_path='images',
            parser_classes=[MultiPartParser, FormParser])
    def images(self, request, pk=None):
        """
        GET: List all images for this animal.
        POST: Upload a new image (multipart/form-data with 'image' field).
        """
        animal = self.get_object()

        if request.method == 'GET':
            images = AnimalImage.objects.filter(animal=animal)
            serializer = AnimalImageSerializer(
                images, many=True, context={'request': request}
            )
            return Response(serializer.data)

        # POST: upload image
        serializer = AnimalImageSerializer(
            data=request.data, context={'request': request}
        )
        serializer.is_valid(raise_exception=True)
        # If this is the first image, make it the profile
        is_first = not AnimalImage.objects.filter(animal=animal).exists()
        serializer.save(
            animal=animal,
            is_profile=request.data.get('is_profile', 'false').lower() == 'true' or is_first,
        )
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['post'], url_path='set-profile-image')
    def set_profile_image(self, request, pk=None):
        """Set an existing image as the profile image for this animal."""
        animal = self.get_object()
        image_id = request.data.get('image_id')
        if not image_id:
            return Response(
                {'error': 'image_id is required'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        try:
            image = AnimalImage.objects.get(pk=image_id, animal=animal)
        except AnimalImage.DoesNotExist:
            return Response(
                {'error': 'Image not found'},
                status=status.HTTP_404_NOT_FOUND,
            )
        # Clear existing profile and set new one
        AnimalImage.objects.filter(animal=animal, is_profile=True).update(is_profile=False)
        image.is_profile = True
        image.save(update_fields=['is_profile'])
        return Response(AnimalImageSerializer(image, context={'request': request}).data)

    @action(detail=True, methods=['delete'], url_path='images/(?P<image_id>[^/.]+)')
    def delete_image(self, request, pk=None, image_id=None):
        """Delete a specific image from this animal."""
        animal = self.get_object()
        try:
            image = AnimalImage.objects.get(pk=image_id, animal=animal)
        except AnimalImage.DoesNotExist:
            return Response(status=status.HTTP_404_NOT_FOUND)
        was_profile = image.is_profile
        image.image.delete(save=False)
        image.delete()
        # If deleted image was profile, promote the next one
        if was_profile:
            next_img = AnimalImage.objects.filter(animal=animal).first()
            if next_img:
                next_img.is_profile = True
                next_img.save(update_fields=['is_profile'])
        return Response(status=status.HTTP_204_NO_CONTENT)

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
    permission_classes = [ReadOnlyForReadOnlyUsers]
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
    permission_classes = [ReadOnlyForReadOnlyUsers]
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
    permission_classes = [ReadOnlyForReadOnlyUsers]
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
    permission_classes = [ReadOnlyForReadOnlyUsers]
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
        else:
            return qs.none()
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
    permission_classes = [ReadOnlyForReadOnlyUsers]
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
        else:
            return qs.none()
        return qs

    def perform_create(self, serializer):
        """Auto-assign the contact to the authenticated user's account."""
        profile = _get_user_profile(self.request)
        if profile is not None:
            serializer.save(account=profile)
        else:
            serializer.save()


class WeightRecordViewSet(viewsets.ModelViewSet):
    """CRUD API for weight/growth tracking records."""
    queryset = WeightRecord.objects.all()
    permission_classes = [ReadOnlyForReadOnlyUsers]
    serializer_class = WeightRecordSerializer
    filter_backends = [DjangoFilterBackend, OrderingFilter]
    filterset_fields = ['animal']
    ordering_fields = ['date', 'created_at']
    ordering = ['-date']


class ShowResultViewSet(viewsets.ModelViewSet):
    """CRUD API for show/competition results."""
    queryset = ShowResult.objects.all()
    permission_classes = [ReadOnlyForReadOnlyUsers]
    serializer_class = ShowResultSerializer
    filter_backends = [DjangoFilterBackend, OrderingFilter]
    filterset_fields = ['animal', 'placement']
    ordering_fields = ['show_date', 'created_at']
    ordering = ['-show_date']


class FinancialRecordViewSet(viewsets.ModelViewSet):
    """CRUD API for financial records (income/expenses)."""
    queryset = FinancialRecord.objects.all()
    permission_classes = [ReadOnlyForReadOnlyUsers]
    serializer_class = FinancialRecordSerializer
    filter_backends = [DjangoFilterBackend, OrderingFilter]
    filterset_fields = ['animal', 'transaction_type', 'category']
    ordering_fields = ['date', 'created_at']
    ordering = ['-date']


class DocumentAttachmentViewSet(viewsets.ModelViewSet):
    """CRUD API for document attachments."""
    queryset = DocumentAttachment.objects.all()
    permission_classes = [ReadOnlyForReadOnlyUsers]
    serializer_class = DocumentAttachmentSerializer
    filter_backends = [DjangoFilterBackend, OrderingFilter]
    filterset_fields = ['animal', 'document_type']
    ordering_fields = ['uploaded_at']
    ordering = ['-uploaded_at']
