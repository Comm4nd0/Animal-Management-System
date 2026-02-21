"""
Celery tasks for expensive background computations.

Each task accepts a BackgroundTask UUID, loads it from the DB, runs the
computation, and writes the result back.
"""

import logging
from celery import shared_task
from animals.serializers import AnimalListSerializer

logger = logging.getLogger(__name__)


@shared_task(bind=True, max_retries=1, soft_time_limit=240)
def compute_pedigree_tree(self, task_id):
    """Build a pedigree tree for an animal in the background."""
    from tasks.models import BackgroundTask
    from genetics import services

    task = BackgroundTask.objects.get(pk=task_id)
    task.celery_task_id = self.request.id or ''
    task.mark_running()

    try:
        animal_id = task.params['animal_id']
        generations = task.params.get('generations', 5)

        task.update_progress(10, message='Building pedigree tree...')
        tree = services.build_pedigree_tree(animal_id, max_generations=generations)

        if tree is None:
            task.mark_failed('Animal not found')
            return

        task.update_progress(80, message='Serializing results...')

        # Serialize the tree for JSON storage
        serialized = _serialize_pedigree_tree(tree)

        task.mark_completed(serialized)
    except Exception as e:
        logger.exception('Pedigree tree computation failed for task %s', task_id)
        task.mark_failed(str(e))


@shared_task(bind=True, max_retries=1, soft_time_limit=240)
def compute_breeding_suggestions(self, task_id):
    """Generate breeding suggestions for an animal in the background."""
    from tasks.models import BackgroundTask
    from genetics import services

    task = BackgroundTask.objects.get(pk=task_id)
    task.celery_task_id = self.request.id or ''
    task.mark_running()

    try:
        animal_id = task.params['animal_id']
        max_results = task.params.get('max_results', 10)
        max_coi = task.params.get('max_coi', 12.5)

        task.update_progress(10, message='Analyzing breeding compatibility...')

        suggestions = services.generate_breeding_suggestions(
            animal_id, max_results=max_results, max_coi=max_coi,
        )

        task.update_progress(80, message='Serializing results...')

        # Serialize suggestions for JSON storage
        serialized = []
        for s in suggestions:
            sire_data = AnimalListSerializer(s['sire']).data
            dam_data = AnimalListSerializer(s['dam']).data
            serialized.append({
                'sire': sire_data,
                'dam': dam_data,
                'compatibility_score': s['compatibility_score'],
                'estimated_coi': s['estimated_coi'],
                'score_grade': s['score_grade'],
                'coi_rating': s['coi_rating'],
                'is_recommended': s['is_recommended'],
                'pros': s['pros'],
                'cons': s['cons'],
                'genetic_risks': s['genetic_risks'],
                'trait_predictions': s['trait_predictions'],
            })

        task.mark_completed({'suggestions': serialized})
    except Exception as e:
        logger.exception('Breeding suggestions failed for task %s', task_id)
        task.mark_failed(str(e))


@shared_task(bind=True, max_retries=1, soft_time_limit=120)
def compute_coi(self, task_id):
    """Calculate COI for a sire/dam pair in the background."""
    from tasks.models import BackgroundTask
    from genetics import services

    task = BackgroundTask.objects.get(pk=task_id)
    task.celery_task_id = self.request.id or ''
    task.mark_running()

    try:
        sire_id = task.params['sire_id']
        dam_id = task.params['dam_id']
        generations = task.params.get('generations', 5)

        task.update_progress(10, message='Calculating coefficient of inbreeding...')

        coi = services.calculate_coi(sire_id, dam_id, max_generations=generations)

        task.update_progress(90, message='Finalizing...')

        task.mark_completed({
            'sire_id': sire_id,
            'dam_id': dam_id,
            'coi_percentage': round(coi, 4),
            'coi_rating': services._coi_rating(coi),
            'generations_analyzed': generations,
        })
    except Exception as e:
        logger.exception('COI calculation failed for task %s', task_id)
        task.mark_failed(str(e))


@shared_task(bind=True, max_retries=1, soft_time_limit=600)
def run_bulk_import(self, task_id):
    """Import animals from an uploaded CSV or JSON file in the background."""
    import csv
    import io
    import json as json_lib
    import uuid as uuid_lib

    from tasks.models import BackgroundTask
    from animals.models import Animal
    from animals.views import AnimalViewSet

    task = BackgroundTask.objects.get(pk=task_id)
    task.celery_task_id = self.request.id or ''
    task.mark_running()

    try:
        file_content = task.params['file_content']
        file_type = task.params['file_type']  # 'csv' or 'json'
        user_id = task.params.get('user_id')

        # Get user profile for account association
        profile = None
        if user_id:
            from accounts.models import UserProfile
            try:
                from django.contrib.auth import get_user_model
                User = get_user_model()
                user = User.objects.get(pk=user_id)
                profile = user.profile
            except Exception:
                pass

        errors = []
        animals_to_create = []

        if file_type == 'json':
            data = json_lib.loads(file_content)
            if not isinstance(data, list):
                task.mark_failed('JSON must be an array of objects.')
                return
            total_rows = len(data)
            task.update_progress(5, message=f'Parsing {total_rows} records...',
                                 total=total_rows, processed=0)

            for i, obj in enumerate(data):
                try:
                    animal = AnimalViewSet._parse_import_row(obj, profile, uuid_lib)
                    animals_to_create.append(animal)
                except Exception as e:
                    errors.append({'row': i + 1, 'error': str(e)})

                if (i + 1) % 100 == 0 or i == len(data) - 1:
                    pct = int(5 + (i + 1) / total_rows * 45)
                    task.update_progress(
                        pct,
                        message=f'Parsed {i + 1} of {total_rows} records...',
                        processed=i + 1,
                        total=total_rows,
                    )

        elif file_type == 'csv':
            reader = csv.DictReader(io.StringIO(file_content))
            rows = list(reader)
            total_rows = len(rows)
            task.update_progress(5, message=f'Parsing {total_rows} records...',
                                 total=total_rows, processed=0)

            for i, row in enumerate(rows):
                norm = {AnimalViewSet._normalise_key(k): v for k, v in row.items()}
                try:
                    animal = AnimalViewSet._parse_import_row(norm, profile, uuid_lib)
                    animals_to_create.append(animal)
                except Exception as e:
                    errors.append({'row': i + 2, 'error': str(e)})

                if (i + 1) % 100 == 0 or i == total_rows - 1:
                    pct = int(5 + (i + 1) / total_rows * 45)
                    task.update_progress(
                        pct,
                        message=f'Parsed {i + 1} of {total_rows} records...',
                        processed=i + 1,
                        total=total_rows,
                    )
        else:
            task.mark_failed(f'Unsupported file type: {file_type}')
            return

        # Batch create
        batch_size = 500
        created = 0
        total_to_insert = len(animals_to_create)
        task.update_progress(
            50, message=f'Inserting {total_to_insert} records into database...',
            total=total_to_insert + len(errors),
        )

        for i in range(0, total_to_insert, batch_size):
            batch = animals_to_create[i:i + batch_size]
            Animal.objects.bulk_create(batch, ignore_conflicts=True,
                                       batch_size=batch_size)
            created += len(batch)
            pct = int(50 + created / max(total_to_insert, 1) * 45)
            task.update_progress(
                pct,
                message=f'Inserted {created} of {total_to_insert} records...',
                processed=created,
                total=total_to_insert + len(errors),
            )

        task.mark_completed({
            'total_rows': total_to_insert + len(errors),
            'imported': created,
            'skipped': len(errors),
            'errors': errors[:100],
        })

    except Exception as e:
        logger.exception('Bulk import failed for task %s', task_id)
        task.mark_failed(str(e))


@shared_task(bind=True, max_retries=1, soft_time_limit=600)
def run_bulk_export(self, task_id):
    """Export animals to CSV or JSON in the background."""
    import csv
    import io
    import json as json_lib

    from tasks.models import BackgroundTask
    from animals.models import Animal

    task = BackgroundTask.objects.get(pk=task_id)
    task.celery_task_id = self.request.id or ''
    task.mark_running()

    try:
        export_format = task.params.get('format', 'csv')
        user_id = task.params.get('user_id')

        # Build queryset for the user's animals
        qs = Animal.objects.all()
        if user_id:
            from django.contrib.auth import get_user_model
            User = get_user_model()
            try:
                user = User.objects.get(pk=user_id)
                qs = qs.filter(account=user.profile)
            except Exception:
                pass

        total_count = qs.count()
        task.update_progress(
            5, message=f'Exporting {total_count} animals...',
            total=total_count, processed=0,
        )

        if export_format == 'json':
            data = []
            for idx, animal in enumerate(qs.iterator(chunk_size=500)):
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

                processed = idx + 1
                if processed % 200 == 0 or processed == total_count:
                    pct = int(5 + processed / max(total_count, 1) * 90)
                    task.update_progress(
                        pct,
                        message=f'Exported {processed} of {total_count} animals...',
                        processed=processed,
                        total=total_count,
                    )

            task.mark_completed({
                'format': 'json',
                'total_exported': len(data),
                'data': data,
            })

        else:
            # CSV export
            output = io.StringIO()
            writer = csv.writer(output)
            headers = [
                'id', 'name', 'species', 'breed', 'sex', 'status',
                'date_of_birth', 'date_of_death', 'color', 'markings',
                'registration_number', 'microchip_number', 'dna_profile_id',
                'sire_id', 'dam_id', 'weight', 'height', 'notes',
            ]
            writer.writerow(headers)

            for idx, animal in enumerate(qs.iterator(chunk_size=500)):
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

                processed = idx + 1
                if processed % 200 == 0 or processed == total_count:
                    pct = int(5 + processed / max(total_count, 1) * 90)
                    task.update_progress(
                        pct,
                        message=f'Exported {processed} of {total_count} animals...',
                        processed=processed,
                        total=total_count,
                    )

            task.mark_completed({
                'format': 'csv',
                'total_exported': total_count,
                'csv_content': output.getvalue(),
            })

    except Exception as e:
        logger.exception('Bulk export failed for task %s', task_id)
        task.mark_failed(str(e))


@shared_task(bind=True, max_retries=1, soft_time_limit=300)
def compute_dashboard_stats(self, task_id):
    """Compute comprehensive dashboard statistics in the background."""
    from collections import Counter
    from datetime import date, timedelta
    from django.db.models import Count
    from django.db.models.functions import TruncMonth

    from tasks.models import BackgroundTask
    from animals.models import Animal, HealthRecord, BreedingRecord
    from animals.serializers import AnimalListSerializer, BreedingRecordSerializer

    task = BackgroundTask.objects.get(pk=task_id)
    task.celery_task_id = self.request.id or ''
    task.mark_running()

    try:
        user_id = task.params.get('user_id')

        qs = Animal.objects.all()
        if user_id:
            from django.contrib.auth import get_user_model
            User = get_user_model()
            try:
                user = User.objects.get(pk=user_id)
                qs = qs.filter(account=user.profile)
            except Exception:
                pass

        task.update_progress(10, message='Calculating basic statistics...')

        total = qs.count()

        # Registration timeline
        task.update_progress(15, message='Building registration timeline...')
        timeline_qs = (
            qs.annotate(month=TruncMonth('created_at'))
            .values('month')
            .annotate(count=Count('id'))
            .order_by('month')
        )
        registration_timeline = [
            {
                'month': row['month'].strftime('%Y-%m') if row['month'] else None,
                'count': row['count'],
            }
            for row in timeline_qs
        ]

        # Sex distribution
        task.update_progress(25, message='Analyzing distributions...')
        sex_counts = qs.values('sex').annotate(count=Count('id'))
        sex_labels = {0: 'Male', 1: 'Female', 2: 'Unknown'}
        sex_distribution = [
            {'label': sex_labels.get(row['sex'], 'Unknown'), 'value': row['count']}
            for row in sex_counts
        ]

        # Status distribution
        status_counts = qs.values('status').annotate(count=Count('id'))
        status_labels = {0: 'Alive', 1: 'Deceased', 2: 'Sold', 3: 'Transferred'}
        status_distribution = [
            {'label': status_labels.get(row['status'], 'Other'), 'value': row['count']}
            for row in status_counts
        ]

        # Breed distribution (top 10)
        task.update_progress(35, message='Analyzing breed distribution...')
        breed_counts = (
            qs.values('breed')
            .annotate(count=Count('id'))
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

        # Age distribution
        task.update_progress(45, message='Calculating age distribution...')
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

        # Genetic diversity
        task.update_progress(55, message='Analyzing genetic diversity...')
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

        # Health summary
        task.update_progress(70, message='Summarizing health records...')
        health_counts = (
            HealthRecord.objects.filter(animal__in=qs)
            .values('type')
            .annotate(count=Count('id'))
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

        # Counts
        task.update_progress(80, message='Finalizing statistics...')
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

        # Recent animals
        recent_qs = qs.order_by('-created_at')[:5]
        recent_animals = AnimalListSerializer(recent_qs, many=True).data

        # Health reminders
        task.update_progress(85, message='Checking health reminders...')
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

        # Active breedings
        task.update_progress(90, message='Loading active breedings...')
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

        task.mark_completed({
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

    except Exception as e:
        logger.exception('Dashboard stats computation failed for task %s', task_id)
        task.mark_failed(str(e))


def _serialize_pedigree_tree(node):
    """Convert a pedigree tree with Animal objects to a JSON-serializable dict."""
    if node is None:
        return None

    animal = node['animal']
    return {
        'animal': AnimalListSerializer(animal).data,
        'generation': node['generation'],
        'sire': _serialize_pedigree_tree(node.get('sire')),
        'dam': _serialize_pedigree_tree(node.get('dam')),
    }
