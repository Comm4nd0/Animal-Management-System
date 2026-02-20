from rest_framework import serializers
from .models import Animal, AnimalImage, HealthRecord, BreedingRecord, Litter, CustomFieldDefinition, Contact, WeightRecord, ShowResult, FinancialRecord, DocumentAttachment


class ContactSerializer(serializers.ModelSerializer):
    """Serializer for contacts (breeders / owners)."""
    class Meta:
        model = Contact
        fields = [
            'id', 'name', 'farm_name', 'email', 'phone',
            'address', 'prefix', 'notes', 'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']


class ContactSummarySerializer(serializers.ModelSerializer):
    """Lightweight contact serializer for embedding in animal responses."""
    class Meta:
        model = Contact
        fields = ['id', 'name', 'farm_name']


class AnimalImageSerializer(serializers.ModelSerializer):
    """Serializer for animal images."""
    class Meta:
        model = AnimalImage
        fields = ['id', 'animal', 'image', 'caption', 'is_profile', 'uploaded_at']
        read_only_fields = ['id', 'uploaded_at']
        extra_kwargs = {'animal': {'required': False}}


class AnimalListSerializer(serializers.ModelSerializer):
    """Lightweight serializer for list views."""
    age_display = serializers.ReadOnlyField()
    profile_image_url = serializers.SerializerMethodField()
    sire_name = serializers.CharField(source='sire.name', read_only=True, default=None)
    dam_name = serializers.CharField(source='dam.name', read_only=True, default=None)
    breeder_name = serializers.CharField(source='breeder.name', read_only=True, default=None)
    owner_name = serializers.CharField(source='current_owner.name', read_only=True, default=None)

    class Meta:
        model = Animal
        fields = [
            'id', 'name', 'species', 'breed', 'sex', 'status',
            'date_of_birth', 'color', 'registration_number',
            'image', 'profile_image_url', 'age_display', 'sire_name', 'dam_name',
            'breeder', 'breeder_name', 'current_owner', 'owner_name',
            'created_at',
        ]

    def get_profile_image_url(self, obj):
        profile = obj.images.filter(is_profile=True).first()
        if profile and profile.image:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(profile.image.url)
            return profile.image.url
        if obj.image:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.image.url)
            return obj.image.url
        return None


class AnimalDetailSerializer(serializers.ModelSerializer):
    """Full serializer for detail/create/update views."""
    age_display = serializers.ReadOnlyField()
    profile_image_url = serializers.SerializerMethodField()
    images = AnimalImageSerializer(many=True, read_only=True)
    sire_name = serializers.CharField(source='sire.name', read_only=True, default=None)
    dam_name = serializers.CharField(source='dam.name', read_only=True, default=None)
    breeder_detail = ContactSummarySerializer(source='breeder', read_only=True)
    current_owner_detail = ContactSummarySerializer(source='current_owner', read_only=True)
    offspring_count = serializers.SerializerMethodField()

    class Meta:
        model = Animal
        fields = '__all__'
        read_only_fields = ['created_at', 'updated_at']

    def get_profile_image_url(self, obj):
        profile = obj.images.filter(is_profile=True).first()
        if profile and profile.image:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(profile.image.url)
            return profile.image.url
        if obj.image:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.image.url)
            return obj.image.url
        return None

    def get_offspring_count(self, obj):
        return (
            Animal.objects.filter(sire=obj).count()
            + Animal.objects.filter(dam=obj).count()
        )


class HealthRecordSerializer(serializers.ModelSerializer):
    is_overdue = serializers.ReadOnlyField()
    is_due_soon = serializers.ReadOnlyField()
    animal_name = serializers.CharField(
        source='animal.name', read_only=True
    )

    class Meta:
        model = HealthRecord
        fields = '__all__'
        read_only_fields = ['created_at']


class BreedingRecordSerializer(serializers.ModelSerializer):
    sire_name = serializers.CharField(source='sire.name', read_only=True)
    dam_name = serializers.CharField(source='dam.name', read_only=True)
    gestation_days_remaining = serializers.ReadOnlyField()

    class Meta:
        model = BreedingRecord
        fields = '__all__'
        read_only_fields = ['created_at']


class LitterSerializer(serializers.ModelSerializer):
    sire_name = serializers.CharField(source='sire.name', read_only=True)
    dam_name = serializers.CharField(source='dam.name', read_only=True)
    surviving_count = serializers.ReadOnlyField()
    offspring_ids = serializers.PrimaryKeyRelatedField(
        source='offspring',
        many=True,
        queryset=Animal.objects.all(),
        required=False,
    )

    class Meta:
        model = Litter
        fields = '__all__'
        read_only_fields = ['created_at']


class BreedingSuggestionSerializer(serializers.Serializer):
    """Read-only serializer for breeding suggestions."""
    sire = AnimalListSerializer()
    dam = AnimalListSerializer()
    compatibility_score = serializers.FloatField()
    estimated_coi = serializers.FloatField()
    score_grade = serializers.CharField()
    coi_rating = serializers.CharField()
    is_recommended = serializers.BooleanField()
    pros = serializers.ListField(child=serializers.CharField())
    cons = serializers.ListField(child=serializers.CharField())
    genetic_risks = serializers.ListField(child=serializers.CharField())
    trait_predictions = serializers.DictField()


class PedigreeNodeSerializer(serializers.Serializer):
    """Recursive serializer for pedigree tree nodes."""
    animal = AnimalListSerializer()
    generation = serializers.IntegerField()
    sire = serializers.SerializerMethodField()
    dam = serializers.SerializerMethodField()

    def get_sire(self, obj):
        if obj.get('sire'):
            return PedigreeNodeSerializer(obj['sire']).data
        return None

    def get_dam(self, obj):
        if obj.get('dam'):
            return PedigreeNodeSerializer(obj['dam']).data
        return None


class CustomFieldDefinitionSerializer(serializers.ModelSerializer):
    """Serializer for custom field definitions."""
    field_type_display = serializers.CharField(
        source='get_field_type_display', read_only=True
    )

    class Meta:
        model = CustomFieldDefinition
        fields = [
            'id', 'name', 'field_key', 'field_type', 'field_type_display',
            'required', 'options', 'display_order', 'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'field_key', 'created_at', 'updated_at']


class WeightRecordSerializer(serializers.ModelSerializer):
    animal_name = serializers.CharField(source='animal.name', read_only=True)

    class Meta:
        model = WeightRecord
        fields = '__all__'
        read_only_fields = ['created_at']


class ShowResultSerializer(serializers.ModelSerializer):
    animal_name = serializers.CharField(source='animal.name', read_only=True)
    placement_display = serializers.CharField(source='get_placement_display', read_only=True)

    class Meta:
        model = ShowResult
        fields = '__all__'
        read_only_fields = ['created_at']


class FinancialRecordSerializer(serializers.ModelSerializer):
    animal_name = serializers.CharField(source='animal.name', read_only=True)
    transaction_type_display = serializers.CharField(source='get_transaction_type_display', read_only=True)
    category_display = serializers.CharField(source='get_category_display', read_only=True)

    class Meta:
        model = FinancialRecord
        fields = '__all__'
        read_only_fields = ['created_at']


class DocumentAttachmentSerializer(serializers.ModelSerializer):
    animal_name = serializers.CharField(source='animal.name', read_only=True)
    document_type_display = serializers.CharField(source='get_document_type_display', read_only=True)

    class Meta:
        model = DocumentAttachment
        fields = '__all__'
        read_only_fields = ['uploaded_at']
