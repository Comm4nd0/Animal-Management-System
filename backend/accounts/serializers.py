from rest_framework import serializers
from django.contrib.auth.models import User
from .models import UserProfile, ServiceTier, UserRole


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'first_name', 'last_name']
        read_only_fields = ['id']


class UserProfileSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)
    tier_label = serializers.ReadOnlyField()
    tier_description = serializers.ReadOnlyField()
    max_animals = serializers.ReadOnlyField()
    allows_multi_breed = serializers.ReadOnlyField()
    animal_count = serializers.SerializerMethodField()
    animals_remaining = serializers.SerializerMethodField()
    role_label = serializers.ReadOnlyField()
    can_manage_users = serializers.ReadOnlyField()
    can_write_data = serializers.ReadOnlyField()
    max_users = serializers.ReadOnlyField()
    team_count = serializers.SerializerMethodField()

    class Meta:
        model = UserProfile
        fields = [
            'id', 'user', 'role', 'role_label',
            'can_manage_users', 'can_write_data',
            'service_tier', 'tier_label', 'tier_description',
            'registered_species', 'registered_breed',
            'max_animals', 'allows_multi_breed',
            'animal_count', 'animals_remaining',
            'max_users', 'team_count',
            'farm_name', 'contact_phone', 'address',
            'created_at', 'updated_at',
        ]
        read_only_fields = [
            'id', 'registered_species', 'registered_breed',
            'created_at', 'updated_at',
        ]

    def get_animal_count(self, obj):
        return obj.get_animal_count()

    def get_animals_remaining(self, obj):
        return obj.animals_remaining()

    def get_team_count(self, obj):
        return obj.get_team_count()


class TeamMemberSerializer(serializers.ModelSerializer):
    """Serializer for listing team members within an organization."""
    user = UserSerializer(read_only=True)
    role_label = serializers.ReadOnlyField()

    class Meta:
        model = UserProfile
        fields = [
            'id', 'user', 'role', 'role_label',
            'created_at',
        ]
        read_only_fields = ['id', 'created_at']


class InviteUserSerializer(serializers.Serializer):
    """Serializer for inviting a new user to the organization."""
    username = serializers.CharField(max_length=150)
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True, min_length=8)
    first_name = serializers.CharField(max_length=150, required=False, default='')
    last_name = serializers.CharField(max_length=150, required=False, default='')
    role = serializers.ChoiceField(
        choices=[(UserRole.READ_ONLY, 'Read Only'),
                 (UserRole.CONTRIBUTOR, 'Contributor'),
                 (UserRole.ADMIN, 'Admin')],
    )

    def validate_username(self, value):
        if User.objects.filter(username=value).exists():
            raise serializers.ValidationError('Username already taken.')
        return value

    def validate_email(self, value):
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError('Email already registered.')
        return value

    def validate_role(self, value):
        value = int(value)
        if value == UserRole.OWNER:
            raise serializers.ValidationError('Cannot invite a user as Owner.')
        return value

    def create(self, validated_data):
        # The requesting user's profile is passed via context
        inviter_profile = self.context['inviter_profile']
        organization_owner = inviter_profile.organization_owner

        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            password=validated_data['password'],
            first_name=validated_data.get('first_name', ''),
            last_name=validated_data.get('last_name', ''),
        )
        profile = UserProfile.objects.create(
            user=user,
            role=validated_data['role'],
            organization=organization_owner,
            # Sub-users inherit the org's tier and breed registration
            service_tier=organization_owner.service_tier,
            registered_species=organization_owner.registered_species,
            registered_breed=organization_owner.registered_breed,
            farm_name=organization_owner.farm_name,
        )
        return profile


class UpdateRoleSerializer(serializers.Serializer):
    """Serializer for updating a team member's role."""
    role = serializers.ChoiceField(
        choices=[(UserRole.READ_ONLY, 'Read Only'),
                 (UserRole.CONTRIBUTOR, 'Contributor'),
                 (UserRole.ADMIN, 'Admin')],
    )

    def validate_role(self, value):
        value = int(value)
        if value == UserRole.OWNER:
            raise serializers.ValidationError('Cannot assign Owner role.')
        return value


class UserRegistrationSerializer(serializers.Serializer):
    username = serializers.CharField(max_length=150)
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True, min_length=8)
    first_name = serializers.CharField(max_length=150, required=False, default='')
    last_name = serializers.CharField(max_length=150, required=False, default='')
    service_tier = serializers.ChoiceField(choices=ServiceTier.choices)
    farm_name = serializers.CharField(max_length=300, required=False, default='')

    def validate_username(self, value):
        if User.objects.filter(username=value).exists():
            raise serializers.ValidationError('Username already taken.')
        return value

    def validate_email(self, value):
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError('Email already registered.')
        return value

    def create(self, validated_data):
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            password=validated_data['password'],
            first_name=validated_data.get('first_name', ''),
            last_name=validated_data.get('last_name', ''),
        )
        profile = UserProfile.objects.create(
            user=user,
            role=UserRole.OWNER,  # Registration always creates an owner
            service_tier=validated_data['service_tier'],
            farm_name=validated_data.get('farm_name', ''),
        )
        return profile


class ServiceTierInfoSerializer(serializers.Serializer):
    """Read-only serializer to list available service tiers."""
    tier_id = serializers.IntegerField()
    label = serializers.CharField()
    description = serializers.CharField()
    max_animals = serializers.IntegerField(allow_null=True)
    allows_multi_breed = serializers.BooleanField()
    max_users = serializers.IntegerField(allow_null=True)


class ChangeTierSerializer(serializers.Serializer):
    service_tier = serializers.ChoiceField(choices=ServiceTier.choices)
