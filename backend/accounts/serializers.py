from rest_framework import serializers
from django.contrib.auth.models import User
from .models import UserProfile, SERVICE_TIER_LIMITS, ServiceTier


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

    class Meta:
        model = UserProfile
        fields = [
            'id', 'user', 'service_tier', 'tier_label', 'tier_description',
            'registered_species', 'registered_breed',
            'max_animals', 'allows_multi_breed',
            'animal_count', 'animals_remaining',
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


class ChangeTierSerializer(serializers.Serializer):
    service_tier = serializers.ChoiceField(choices=ServiceTier.choices)
