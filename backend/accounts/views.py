from rest_framework import viewsets, status, permissions
from rest_framework.decorators import action
from rest_framework.response import Response

from .models import UserProfile, ServiceTier, UserRole, get_tier_limits, get_all_tier_limits
from .permissions import IsOwnerOrAdmin
from .serializers import (
    UserProfileSerializer,
    UserRegistrationSerializer,
    ServiceTierInfoSerializer,
    ChangeTierSerializer,
    TeamMemberSerializer,
    InviteUserSerializer,
    UpdateRoleSerializer,
)


class AccountViewSet(viewsets.ViewSet):
    """
    Account management endpoints.

    register:       POST /api/v1/accounts/register/
    me:             GET  /api/v1/accounts/me/
    tiers:          GET  /api/v1/accounts/tiers/
    change_tier:    POST /api/v1/accounts/change-tier/
    team:           GET  /api/v1/accounts/team/
    invite_user:    POST /api/v1/accounts/invite-user/
    update_role:    POST /api/v1/accounts/update-role/
    remove_user:    POST /api/v1/accounts/remove-user/
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
        """Get the current user's profile including tier and role info."""
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
        """List all available service tiers with their limits (from DB or defaults)."""
        all_limits = get_all_tier_limits()
        tiers = []
        for tier_id, limits in all_limits.items():
            tiers.append({
                'tier_id': tier_id,
                'label': limits['label'],
                'description': limits['description'],
                'max_animals': limits['max_animals'],
                'allows_multi_breed': limits['allows_multi_breed'],
                'max_users': limits['max_users'],
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

        # Only the owner can change the tier
        if not profile.is_owner:
            return Response(
                {'error': 'Only the account owner can change the service tier.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        new_limits = get_tier_limits(new_tier)
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

        # Check team count fits
        team_count = profile.get_team_count()
        if new_limits['max_users'] is not None and team_count > new_limits['max_users']:
            return Response(
                {
                    'error': (
                        f'Cannot downgrade to {new_limits["label"]}. '
                        f'You have {team_count} team members but the limit is '
                        f'{new_limits["max_users"]}. Remove team members first.'
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

        # Update team members' tier to match
        UserProfile.objects.filter(organization=profile).update(
            service_tier=new_tier,
        )

        return Response(UserProfileSerializer(profile).data)

    # ─── Team Management ──────────────────────────────────────────

    @action(detail=False, methods=['get'], url_path='team',
            permission_classes=[permissions.IsAuthenticated])
    def team(self, request):
        """List all team members in the user's organization."""
        try:
            profile = request.user.profile
        except UserProfile.DoesNotExist:
            return Response(
                {'error': 'Profile not found'},
                status=status.HTTP_404_NOT_FOUND,
            )

        members = profile.get_team_members().select_related('user')
        serializer = TeamMemberSerializer(members, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=['post'], url_path='invite-user',
            permission_classes=[IsOwnerOrAdmin])
    def invite_user(self, request):
        """
        Invite a new user to the organization.
        Only owners and admins can invite users.
        Admins cannot invite other admins (only owners can).
        """
        try:
            profile = request.user.profile
        except UserProfile.DoesNotExist:
            return Response(
                {'error': 'Profile not found'},
                status=status.HTTP_404_NOT_FOUND,
            )

        # Check team member limit
        if not profile.can_add_user():
            limit = profile.max_users
            return Response(
                {
                    'error': (
                        f'User limit reached. Your plan allows up to {limit} '
                        f'team members. Upgrade your plan to add more.'
                    )
                },
                status=status.HTTP_403_FORBIDDEN,
            )

        # Admins can only invite contributors and read-only users
        requested_role = int(request.data.get('role', UserRole.READ_ONLY))
        if profile.is_admin and requested_role >= UserRole.ADMIN:
            return Response(
                {'error': 'Admins can only invite Contributors and Read-Only users.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        serializer = InviteUserSerializer(
            data=request.data,
            context={'inviter_profile': profile},
        )
        serializer.is_valid(raise_exception=True)
        new_profile = serializer.save()
        return Response(
            TeamMemberSerializer(new_profile).data,
            status=status.HTTP_201_CREATED,
        )

    @action(detail=False, methods=['post'], url_path='update-role',
            permission_classes=[IsOwnerOrAdmin])
    def update_role(self, request):
        """
        Change a team member's role.
        Only owners and admins can update roles.
        Admins cannot promote users to Admin or change other admins.
        """
        try:
            profile = request.user.profile
        except UserProfile.DoesNotExist:
            return Response(
                {'error': 'Profile not found'},
                status=status.HTTP_404_NOT_FOUND,
            )

        member_id = request.data.get('member_id')
        if not member_id:
            return Response(
                {'error': 'member_id is required'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Find the target member
        try:
            member = UserProfile.objects.select_related('user').get(pk=member_id)
        except UserProfile.DoesNotExist:
            return Response(
                {'error': 'Team member not found'},
                status=status.HTTP_404_NOT_FOUND,
            )

        # Verify they belong to the same organization
        if member.organization_owner != profile.organization_owner:
            return Response(
                {'error': 'User is not in your organization'},
                status=status.HTTP_403_FORBIDDEN,
            )

        # Cannot change the owner's role
        if member.is_owner:
            return Response(
                {'error': 'Cannot change the account owner\'s role.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        serializer = UpdateRoleSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        new_role = serializer.validated_data['role']

        # Admins cannot promote to Admin or change other admins
        if profile.is_admin:
            if member.is_admin:
                return Response(
                    {'error': 'Admins cannot change other admins\' roles.'},
                    status=status.HTTP_403_FORBIDDEN,
                )
            if new_role >= UserRole.ADMIN:
                return Response(
                    {'error': 'Only the account owner can promote users to Admin.'},
                    status=status.HTTP_403_FORBIDDEN,
                )

        member.role = new_role
        member.save(update_fields=['role'])
        return Response(TeamMemberSerializer(member).data)

    @action(detail=False, methods=['post'], url_path='remove-user',
            permission_classes=[IsOwnerOrAdmin])
    def remove_user(self, request):
        """
        Remove a team member from the organization.
        This deletes the user account entirely.
        Owners can remove anyone. Admins can remove contributors and read-only.
        """
        try:
            profile = request.user.profile
        except UserProfile.DoesNotExist:
            return Response(
                {'error': 'Profile not found'},
                status=status.HTTP_404_NOT_FOUND,
            )

        member_id = request.data.get('member_id')
        if not member_id:
            return Response(
                {'error': 'member_id is required'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            member = UserProfile.objects.select_related('user').get(pk=member_id)
        except UserProfile.DoesNotExist:
            return Response(
                {'error': 'Team member not found'},
                status=status.HTTP_404_NOT_FOUND,
            )

        # Verify same organization
        if member.organization_owner != profile.organization_owner:
            return Response(
                {'error': 'User is not in your organization'},
                status=status.HTTP_403_FORBIDDEN,
            )

        # Cannot remove the owner
        if member.is_owner:
            return Response(
                {'error': 'Cannot remove the account owner.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        # Cannot remove yourself
        if member.pk == profile.pk:
            return Response(
                {'error': 'Cannot remove yourself. Contact the account owner.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        # Admins cannot remove other admins
        if profile.is_admin and member.is_admin:
            return Response(
                {'error': 'Admins cannot remove other admins.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        # Delete the Django user (cascades to profile)
        member.user.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
