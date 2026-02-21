"""API views for creating, polling, listing, and managing background tasks."""

from celery.result import AsyncResult
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
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
        user=request.user if request.user.is_authenticated else None,
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
        user=request.user if request.user.is_authenticated else None,
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
        user=request.user if request.user.is_authenticated else None,
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


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def create_bulk_import_task(request):
    """
    Start a background bulk import of animals from CSV or JSON.

    Accepts multipart/form-data with a 'file' field (.csv or .json).
    For large files, the import runs asynchronously and the client polls
    for progress and completion.
    """
    uploaded = request.FILES.get('file')
    if not uploaded:
        return Response(
            {'error': 'No file provided.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    filename = uploaded.name.lower()
    if filename.endswith('.json'):
        file_type = 'json'
    elif filename.endswith('.csv'):
        file_type = 'csv'
    else:
        return Response(
            {'error': 'Unsupported file type. Use .csv or .json.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    try:
        file_content = uploaded.read().decode('utf-8')
    except UnicodeDecodeError as e:
        return Response(
            {'error': f'Cannot read file: {e}'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    task = BackgroundTask.objects.create(
        task_type=BackgroundTask.TaskType.BULK_IMPORT,
        user=request.user,
        params={
            'file_type': file_type,
            'file_content': file_content,
            'file_name': uploaded.name,
            'user_id': request.user.pk,
        },
        status_message='Queued for processing',
    )

    jobs.run_bulk_import.delay(str(task.pk))

    return Response(
        BackgroundTaskSerializer(task).data,
        status=status.HTTP_202_ACCEPTED,
    )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def create_bulk_export_task(request):
    """
    Start a background bulk export of animals to CSV or JSON.

    Body: { "format": "csv" | "json" }
    Returns: { "id": "<task-uuid>", "status": "Pending", ... }
    """
    export_format = request.data.get('format', 'csv')
    if export_format not in ('csv', 'json'):
        return Response(
            {'error': 'Format must be "csv" or "json".'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    task = BackgroundTask.objects.create(
        task_type=BackgroundTask.TaskType.BULK_EXPORT,
        user=request.user,
        params={
            'format': export_format,
            'user_id': request.user.pk,
        },
        status_message='Queued for processing',
    )

    jobs.run_bulk_export.delay(str(task.pk))

    return Response(
        BackgroundTaskSerializer(task).data,
        status=status.HTTP_202_ACCEPTED,
    )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def create_dashboard_stats_task(request):
    """
    Start a background dashboard statistics computation.

    For large datasets, the dashboard stats are computed asynchronously
    and the client polls for the result.
    """
    task = BackgroundTask.objects.create(
        task_type=BackgroundTask.TaskType.DASHBOARD_STATS,
        user=request.user,
        params={'user_id': request.user.pk},
        status_message='Queued for processing',
    )

    jobs.compute_dashboard_stats.delay(str(task.pk))

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


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def list_user_tasks(request):
    """
    List all background tasks for the authenticated user.

    Query params:
        status: Filter by status (pending, running, completed, failed, cancelled)
        task_type: Filter by task type integer
        limit: Max results (default 20)
    """
    qs = BackgroundTask.objects.filter(user=request.user)

    status_filter = request.query_params.get('status')
    if status_filter is not None:
        status_map = {
            'pending': BackgroundTask.Status.PENDING,
            'running': BackgroundTask.Status.RUNNING,
            'completed': BackgroundTask.Status.COMPLETED,
            'failed': BackgroundTask.Status.FAILED,
            'cancelled': BackgroundTask.Status.CANCELLED,
        }
        status_val = status_map.get(status_filter.lower())
        if status_val is not None:
            qs = qs.filter(status=status_val)

    task_type = request.query_params.get('task_type')
    if task_type is not None:
        try:
            qs = qs.filter(task_type=int(task_type))
        except (ValueError, TypeError):
            pass

    limit = min(int(request.query_params.get('limit', 20)), 100)
    qs = qs[:limit]

    return Response(BackgroundTaskSerializer(qs, many=True).data)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def active_user_tasks(request):
    """
    List currently active (pending or running) tasks for the authenticated user.

    Useful for showing an activity indicator in the UI.
    """
    qs = BackgroundTask.objects.filter(
        user=request.user,
        status__in=[BackgroundTask.Status.PENDING, BackgroundTask.Status.RUNNING],
    )
    return Response(BackgroundTaskSerializer(qs, many=True).data)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def cancel_task(request, task_id):
    """
    Cancel a pending or running background task.

    Revokes the Celery task and marks the BackgroundTask as cancelled.
    """
    try:
        task = BackgroundTask.objects.get(pk=task_id, user=request.user)
    except BackgroundTask.DoesNotExist:
        return Response(
            {'error': 'Task not found'},
            status=status.HTTP_404_NOT_FOUND,
        )

    if task.status not in (BackgroundTask.Status.PENDING, BackgroundTask.Status.RUNNING):
        return Response(
            {'error': 'Only pending or running tasks can be cancelled.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    # Revoke the Celery task
    if task.celery_task_id:
        AsyncResult(task.celery_task_id).revoke(terminate=True)

    task.mark_cancelled()

    return Response(BackgroundTaskSerializer(task).data)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def retry_task(request, task_id):
    """
    Retry a failed or cancelled task by creating a new task with the same params.
    """
    try:
        original = BackgroundTask.objects.get(pk=task_id, user=request.user)
    except BackgroundTask.DoesNotExist:
        return Response(
            {'error': 'Task not found'},
            status=status.HTTP_404_NOT_FOUND,
        )

    if original.status not in (BackgroundTask.Status.FAILED, BackgroundTask.Status.CANCELLED):
        return Response(
            {'error': 'Only failed or cancelled tasks can be retried.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    # Create a new task with the same parameters
    new_task = BackgroundTask.objects.create(
        task_type=original.task_type,
        user=request.user,
        params=original.params,
        status_message='Retrying...',
    )

    # Dispatch to the correct Celery task
    task_dispatch = {
        BackgroundTask.TaskType.PEDIGREE_TREE: jobs.compute_pedigree_tree,
        BackgroundTask.TaskType.BREEDING_SUGGESTIONS: jobs.compute_breeding_suggestions,
        BackgroundTask.TaskType.COI_CALCULATION: jobs.compute_coi,
        BackgroundTask.TaskType.BULK_IMPORT: jobs.run_bulk_import,
        BackgroundTask.TaskType.BULK_EXPORT: jobs.run_bulk_export,
        BackgroundTask.TaskType.DASHBOARD_STATS: jobs.compute_dashboard_stats,
    }

    celery_task = task_dispatch.get(original.task_type)
    if celery_task:
        celery_task.delay(str(new_task.pk))

    return Response(
        BackgroundTaskSerializer(new_task).data,
        status=status.HTTP_202_ACCEPTED,
    )
