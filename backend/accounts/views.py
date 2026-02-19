from rest_framework import viewsets, status, permissions
from rest_framework.decorators import action
from rest_framework.response import Response

from .models import UserProfile, SERVICE_TIER_LIMITS, ServiceTier
from .serializers import (
    UserProfileSerializer,
    UserRegistrationSerializer,
    ServiceTierInfoSerializer,
    ChangeTierSerializer,
)


class AccountViewSet(viewsets.ViewSet):
    """
    Account management endpoints.

    register: POST /api/v1/accounts/register/
    me: GET /api/v1/accounts/me/
    tiers: GET /api/v1/accounts/tiers/
    change_tier: POST /api/v1/accounts/change-tier/
    """

    @action(detail=False, methods=['post'], url_path='register')
    def register(self, request):
        """Create a new user account with a selected service tier."""
        serializer = UserRegistrationSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        profile = serializer.save()
        return Response(
            UserProfileSerializer(profile).data,
            status=status.HTTP_201_CREATED,
        )

    @action(detail=False, methods=['get'], url_path='me')
    def me(self, request):
        """Get the current user's profile including tier info."""
        if not request.user.is_authenticated:
            return Response(
                {'error': 'Authentication required'},
                status=status.HTTP_401_UNAUTHORIZED,
            )
        try:
            profile = request.user.profile
        except UserProfile.DoesNotExist:
            profile = UserProfile.objects.create(user=request.user)
        return Response(UserProfileSerializer(profile).data)

    @action(detail=False, methods=['get'], url_path='tiers')
    def tiers(self, request):
        """List all available service tiers with their limits."""
        tiers = []
        for tier_id, limits in SERVICE_TIER_LIMITS.items():
            tiers.append({
                'tier_id': tier_id,
                'label': limits['label'],
                'description': limits['description'],
                'max_animals': limits['max_animals'],
                'allows_multi_breed': limits['allows_multi_breed'],
            })
        serializer = ServiceTierInfoSerializer(tiers, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=['post'], url_path='change-tier')
    def change_tier(self, request):
        """
        Change the user's service tier.

        Downgrading is only allowed if the current animal count
        fits within the new tier's limits.
        """
        if not request.user.is_authenticated:
            return Response(
                {'error': 'Authentication required'},
                status=status.HTTP_401_UNAUTHORIZED,
            )

        serializer = ChangeTierSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        new_tier = serializer.validated_data['service_tier']

        try:
            profile = request.user.profile
        except UserProfile.DoesNotExist:
            return Response(
                {'error': 'Profile not found'},
                status=status.HTTP_404_NOT_FOUND,
            )

        new_limits = SERVICE_TIER_LIMITS[new_tier]
        current_count = profile.get_animal_count()

        # Check animal count fits
        if new_limits['max_animals'] is not None and current_count > new_limits['max_animals']:
            return Response(
                {
                    'error': (
                        f'Cannot downgrade to {new_limits["label"]}. '
                        f'You have {current_count} animals but the limit is '
                        f'{new_limits["max_animals"]}. Remove animals first.'
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Check multi-breed restriction
        if not new_limits['allows_multi_breed'] and profile.allows_multi_breed:
            from animals.models import Animal
            animals = Animal.objects.filter(owner=profile)
            breeds = set(animals.values_list('breed', flat=True))
            species = set(animals.values_list('species', flat=True))
            if len(breeds) > 1 or len(species) > 1:
                return Response(
                    {
                        'error': (
                            f'Cannot downgrade to {new_limits["label"]}. '
                            f'You have animals of multiple breeds/species. '
                            f'Non-Enterprise tiers only allow a single breed.'
                        )
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )

        profile.service_tier = new_tier
        profile.save(update_fields=['service_tier'])

        return Response(UserProfileSerializer(profile).data)
