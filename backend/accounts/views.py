import logging

from django.conf import settings
from django.contrib.auth import authenticate
from django.contrib.auth.models import User
from django.core.mail import send_mail
from rest_framework import viewsets, status, permissions
from rest_framework.authtoken.models import Token
from rest_framework.decorators import action
from rest_framework.response import Response

from .models import UserProfile, ServiceTier, UserRole, get_tier_limits, get_all_tier_limits, PasswordResetToken
from .permissions import IsOwnerOrAdmin
from .serializers import (
    UserProfileSerializer,
    UserRegistrationSerializer,
    ServiceTierInfoSerializer,
    ChangeTierSerializer,
    TeamMemberSerializer,
    InviteUserSerializer,
    UpdateRoleSerializer,
    RequestPasswordResetSerializer,
    ConfirmPasswordResetSerializer,
    ChangePasswordSerializer,
)

logger = logging.getLogger(__name__)


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

    @action(detail=False, methods=['post'], url_path='login')
    def login(self, request):
        """Authenticate and return an auth token."""
        username = request.data.get('username', '')
        password = request.data.get('password', '')

        # Allow login with email as username
        if '@' in username:
            from django.contrib.auth.models import User
            try:
                user = User.objects.get(email=username)
                username = user.username
            except User.DoesNotExist:
                pass

        user = authenticate(username=username, password=password)
        if user is None:
            return Response(
                {'error': 'Invalid credentials'},
                status=status.HTTP_401_UNAUTHORIZED,
            )

        token, _ = Token.objects.get_or_create(user=user)
        try:
            profile = user.profile
        except UserProfile.DoesNotExist:
            profile = UserProfile.objects.create(user=user)

        return Response({
            'token': token.key,
            'user': UserProfileSerializer(profile).data,
        })

    @action(detail=False, methods=['post'], url_path='logout')
    def logout(self, request):
        """Delete the user's auth token."""
        if request.user.is_authenticated:
            Token.objects.filter(user=request.user).delete()
        return Response(status=status.HTTP_204_NO_CONTENT)

    @action(detail=False, methods=['post'], url_path='register')
    def register(self, request):
        """Create a new user account with a selected service tier."""
        serializer = UserRegistrationSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        profile = serializer.save()
        token, _ = Token.objects.get_or_create(user=profile.user)
        return Response(
            {
                'token': token.key,
                'user': UserProfileSerializer(profile).data,
            },
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

    # ─── Password Reset ─────────────────────────────────────────

    @action(detail=False, methods=['post'], url_path='request-password-reset')
    def request_password_reset(self, request):
        """
        Request a password reset code.

        POST /api/v1/accounts/request-password-reset/
        Body: {"email": "user@example.com"}

        Sends a 6-digit code to the user's email. The code expires in 15 minutes.
        Always returns 200 to avoid leaking whether an email is registered.
        """
        serializer = RequestPasswordResetSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        email = serializer.validated_data['email']

        try:
            user = User.objects.get(email=email)
        except User.DoesNotExist:
            # Don't reveal whether the email exists
            return Response(
                {'message': 'If an account with that email exists, a reset code has been sent.'},
            )

        # Invalidate any previous unused tokens for this user
        PasswordResetToken.objects.filter(user=user, used=False).update(used=True)

        # Create a new token
        token = PasswordResetToken.objects.create(user=user)

        # Send the email
        try:
            send_mail(
                subject='Pedigree Manager - Password Reset Code',
                message=(
                    f'Your password reset code is: {token.code}\n\n'
                    f'This code will expire in 15 minutes.\n\n'
                    f'If you did not request a password reset, please ignore this email.'
                ),
                from_email=settings.DEFAULT_FROM_EMAIL,
                recipient_list=[email],
                fail_silently=False,
            )
        except Exception:
            logger.exception('Failed to send password reset email to %s', email)
            return Response(
                {'error': 'Failed to send email. Please try again later.'},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        return Response(
            {'message': 'If an account with that email exists, a reset code has been sent.'},
        )

    @action(detail=False, methods=['post'], url_path='confirm-password-reset')
    def confirm_password_reset(self, request):
        """
        Confirm a password reset with the 6-digit code.

        POST /api/v1/accounts/confirm-password-reset/
        Body: {"email": "user@example.com", "code": "123456", "new_password": "..."}
        """
        serializer = ConfirmPasswordResetSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        email = serializer.validated_data['email']
        code = serializer.validated_data['code']
        new_password = serializer.validated_data['new_password']

        try:
            user = User.objects.get(email=email)
        except User.DoesNotExist:
            return Response(
                {'error': 'Invalid email or code.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Find the most recent unused, unexpired token with matching code
        token = PasswordResetToken.objects.filter(
            user=user,
            code=code,
            used=False,
        ).order_by('-created_at').first()

        if token is None or not token.is_valid:
            return Response(
                {'error': 'Invalid or expired code. Please request a new one.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Mark token as used and set the new password
        token.used = True
        token.save(update_fields=['used'])

        user.set_password(new_password)
        user.save()

        # Invalidate existing auth tokens so user must log in with new password
        Token.objects.filter(user=user).delete()

        return Response({'message': 'Password has been reset successfully.'})

    @action(detail=False, methods=['post'], url_path='change-password',
            permission_classes=[permissions.IsAuthenticated])
    def change_password(self, request):
        """
        Change password for an authenticated user.

        POST /api/v1/accounts/change-password/
        Body: {"current_password": "...", "new_password": "..."}
        """
        serializer = ChangePasswordSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        user = request.user
        current_password = serializer.validated_data['current_password']
        new_password = serializer.validated_data['new_password']

        if not user.check_password(current_password):
            return Response(
                {'error': 'Current password is incorrect.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user.set_password(new_password)
        user.save()

        # Re-create the auth token
        Token.objects.filter(user=user).delete()
        new_token, _ = Token.objects.get_or_create(user=user)

        return Response({
            'message': 'Password changed successfully.',
            'token': new_token.key,
        })

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
