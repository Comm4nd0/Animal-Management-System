"""API views for creating and polling background tasks."""

from rest_framework import status
from rest_framework.decorators import api_view
from rest_framework.response import Response

from .models import BackgroundTask
from .serializers import BackgroundTaskSerializer
from . import jobs


@api_view(['POST'])
def create_pedigree_task(request):
    """
    Start a background pedigree tree computation.

    Body: { "animal_id": "<uuid>", "generations": 5 }
    Returns: { "id": "<task-uuid>", "status": "Pending", ... }
    """
    animal_id = request.data.get('animal_id')
    if not animal_id:
        return Response(
            {'error': 'animal_id is required'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    generations = int(request.data.get('generations', 5))

    task = BackgroundTask.objects.create(
        task_type=BackgroundTask.TaskType.PEDIGREE_TREE,
        params={'animal_id': str(animal_id), 'generations': generations},
    )

    jobs.compute_pedigree_tree.delay(str(task.pk))

    return Response(
        BackgroundTaskSerializer(task).data,
        status=status.HTTP_202_ACCEPTED,
    )


@api_view(['POST'])
def create_breeding_suggestions_task(request):
    """
    Start a background breeding suggestions computation.

    Body: { "animal_id": "<uuid>", "max_results": 10, "max_coi": 12.5 }
    Returns: { "id": "<task-uuid>", "status": "Pending", ... }
    """
    animal_id = request.data.get('animal_id')
    if not animal_id:
        return Response(
            {'error': 'animal_id is required'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    max_results = int(request.data.get('max_results', 10))
    max_coi = float(request.data.get('max_coi', 12.5))

    task = BackgroundTask.objects.create(
        task_type=BackgroundTask.TaskType.BREEDING_SUGGESTIONS,
        params={
            'animal_id': str(animal_id),
            'max_results': max_results,
            'max_coi': max_coi,
        },
    )

    jobs.compute_breeding_suggestions.delay(str(task.pk))

    return Response(
        BackgroundTaskSerializer(task).data,
        status=status.HTTP_202_ACCEPTED,
    )


@api_view(['POST'])
def create_coi_task(request):
    """
    Start a background COI calculation.

    Body: { "sire_id": "<uuid>", "dam_id": "<uuid>", "generations": 5 }
    Returns: { "id": "<task-uuid>", "status": "Pending", ... }
    """
    sire_id = request.data.get('sire_id')
    dam_id = request.data.get('dam_id')
    if not sire_id or not dam_id:
        return Response(
            {'error': 'Both sire_id and dam_id are required'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    generations = int(request.data.get('generations', 5))

    task = BackgroundTask.objects.create(
        task_type=BackgroundTask.TaskType.COI_CALCULATION,
        params={
            'sire_id': str(sire_id),
            'dam_id': str(dam_id),
            'generations': generations,
        },
    )

    jobs.compute_coi.delay(str(task.pk))

    return Response(
        BackgroundTaskSerializer(task).data,
        status=status.HTTP_202_ACCEPTED,
    )


@api_view(['GET'])
def get_task_status(request, task_id):
    """
    Poll the status and result of a background task.

    Returns the full task object including result when completed.
    """
    try:
        task = BackgroundTask.objects.get(pk=task_id)
    except BackgroundTask.DoesNotExist:
        return Response(
            {'error': 'Task not found'},
            status=status.HTTP_404_NOT_FOUND,
        )

    return Response(BackgroundTaskSerializer(task).data)
