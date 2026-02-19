from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework.filters import SearchFilter, OrderingFilter

from .models import Animal, HealthRecord, BreedingRecord, Litter
from .serializers import (
    AnimalListSerializer,
    AnimalDetailSerializer,
    HealthRecordSerializer,
    BreedingRecordSerializer,
    LitterSerializer,
)


class AnimalViewSet(viewsets.ModelViewSet):
    """
    CRUD API for animals.

    list: GET /api/v1/animals/
    create: POST /api/v1/animals/
    retrieve: GET /api/v1/animals/{id}/
    update: PUT /api/v1/animals/{id}/
    partial_update: PATCH /api/v1/animals/{id}/
    destroy: DELETE /api/v1/animals/{id}/
    offspring: GET /api/v1/animals/{id}/offspring/
    stats: GET /api/v1/animals/stats/
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

    @action(detail=True, methods=['get'])
    def offspring(self, request, pk=None):
        """Get all direct offspring of this animal."""
        animal = self.get_object()
        offspring = Animal.objects.filter(
            models_sire=animal
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
        """Get aggregate statistics about all animals."""
        total = Animal.objects.count()
        males = Animal.objects.filter(sex=Animal.Sex.MALE).count()
        females = Animal.objects.filter(sex=Animal.Sex.FEMALE).count()
        breeds = Animal.objects.values('breed').distinct().count()
        species = Animal.objects.values('species').distinct().count()
        alive = Animal.objects.filter(status=Animal.Status.ALIVE).count()

        return Response({
            'total': total,
            'males': males,
            'females': females,
            'breeds': breeds,
            'species': species,
            'alive': alive,
        })

    @action(detail=False, methods=['get'])
    def search(self, request):
        """Search animals by query string."""
        query = request.query_params.get('q', '')
        if not query:
            return Response([])
        animals = Animal.objects.filter(
            models.Q(name__icontains=query)
            | models.Q(breed__icontains=query)
            | models.Q(registration_number__icontains=query)
            | models.Q(microchip_number__icontains=query)
        )[:25]
        serializer = AnimalListSerializer(animals, many=True)
        return Response(serializer.data)


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
