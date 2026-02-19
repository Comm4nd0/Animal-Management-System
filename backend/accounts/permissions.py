from rest_framework.permissions import BasePermission

from .models import UserRole


class IsAuthenticated(BasePermission):
    """Requires the user to be authenticated."""

    def has_permission(self, request, view):
        return request.user and request.user.is_authenticated


class IsOwnerOrAdmin(BasePermission):
    """
    Allows access only to account owners and admins.
    Used for user management endpoints.
    """

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        try:
            profile = request.user.profile
        except Exception:
            return False
        return profile.role in (UserRole.OWNER, UserRole.ADMIN)


class IsContributorOrAbove(BasePermission):
    """
    Allows write access to contributors, admins, and owners.
    Read-only users are denied.
    """

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        try:
            profile = request.user.profile
        except Exception:
            return False
        return profile.can_write_data


class ReadOnlyForReadOnlyUsers(BasePermission):
    """
    Allows read access for all authenticated users.
    Write operations (POST, PUT, PATCH, DELETE) require contributor role or above.
    """

    SAFE_METHODS = ('GET', 'HEAD', 'OPTIONS')

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        if request.method in self.SAFE_METHODS:
            return True
        try:
            profile = request.user.profile
        except Exception:
            return False
        return profile.can_write_data
