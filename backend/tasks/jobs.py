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

        task.update_progress(10)
        tree = services.build_pedigree_tree(animal_id, max_generations=generations)

        if tree is None:
            task.mark_failed('Animal not found')
            return

        task.update_progress(80)

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

        task.update_progress(10)

        suggestions = services.generate_breeding_suggestions(
            animal_id, max_results=max_results, max_coi=max_coi,
        )

        task.update_progress(80)

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

        task.update_progress(10)

        coi = services.calculate_coi(sire_id, dam_id, max_generations=generations)

        task.update_progress(90)

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
