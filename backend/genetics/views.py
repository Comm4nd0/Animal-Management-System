from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response

from animals.serializers import (
    AnimalListSerializer,
    BreedingSuggestionSerializer,
    PedigreeNodeSerializer,
)
from . import services


def _serialize_tree(node):
    """Convert a pedigree tree with Animal objects to serializable dicts."""
    if node is None:
        return None
    return {
        'animal': node['animal'],
        'generation': node['generation'],
        'sire': _serialize_tree(node.get('sire')),
        'dam': _serialize_tree(node.get('dam')),
    }


class GeneticsViewSet(viewsets.ViewSet):
    """
    API endpoints for genetics analysis.

    pedigree: GET /api/v1/genetics/{animal_id}/pedigree/
    coi: GET /api/v1/genetics/coi/?sire={id}&dam={id}
    suggestions: GET /api/v1/genetics/{animal_id}/suggestions/
    common_ancestors: GET /api/v1/genetics/common-ancestors/?animal1={id}&animal2={id}
    """

    @action(detail=True, methods=['get'], url_path='pedigree')
    def pedigree(self, request, pk=None):
        """Get the full pedigree tree for an animal."""
        generations = int(request.query_params.get('generations', 5))
        tree = services.build_pedigree_tree(pk, max_generations=generations)
        if tree is None:
            return Response(
                {'error': 'Animal not found'},
                status=status.HTTP_404_NOT_FOUND,
            )
        serialized = _serialize_tree(tree)
        serializer = PedigreeNodeSerializer(serialized)
        return Response(serializer.data)

    @action(detail=False, methods=['get'], url_path='coi')
    def coi(self, request):
        """
        Calculate the Coefficient of Inbreeding for a hypothetical mating.

        Query params: sire (UUID), dam (UUID), generations (int, optional)
        """
        sire_id = request.query_params.get('sire')
        dam_id = request.query_params.get('dam')
        if not sire_id or not dam_id:
            return Response(
                {'error': 'Both sire and dam query parameters are required'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        generations = int(request.query_params.get('generations', 5))
        coi = services.calculate_coi(sire_id, dam_id, max_generations=generations)
        return Response({
            'sire_id': sire_id,
            'dam_id': dam_id,
            'coi_percentage': round(coi, 4),
            'coi_rating': services._coi_rating(coi),
            'generations_analyzed': generations,
        })

    @action(detail=True, methods=['get'], url_path='suggestions')
    def suggestions(self, request, pk=None):
        """Get breeding suggestions for an animal."""
        max_results = int(request.query_params.get('max_results', 10))
        max_coi = float(request.query_params.get('max_coi', 12.5))
        suggestions = services.generate_breeding_suggestions(
            pk, max_results=max_results, max_coi=max_coi
        )
        serializer = BreedingSuggestionSerializer(suggestions, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=['get'], url_path='common-ancestors')
    def common_ancestors(self, request):
        """Find common ancestors between two animals."""
        id1 = request.query_params.get('animal1')
        id2 = request.query_params.get('animal2')
        if not id1 or not id2:
            return Response(
                {'error': 'Both animal1 and animal2 query parameters are required'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        ancestors = services.find_common_ancestors(id1, id2)
        serializer = AnimalListSerializer(ancestors, many=True)
        return Response(serializer.data)
