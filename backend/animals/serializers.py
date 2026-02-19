from rest_framework import serializers
from .models import Animal, HealthRecord, BreedingRecord, Litter


class AnimalListSerializer(serializers.ModelSerializer):
    """Lightweight serializer for list views."""
    age_display = serializers.ReadOnlyField()
    sire_name = serializers.CharField(source='sire.name', read_only=True, default=None)
    dam_name = serializers.CharField(source='dam.name', read_only=True, default=None)

    class Meta:
        model = Animal
        fields = [
            'id', 'name', 'species', 'breed', 'sex', 'status',
            'date_of_birth', 'color', 'registration_number',
            'image', 'age_display', 'sire_name', 'dam_name',
            'created_at',
        ]


class AnimalDetailSerializer(serializers.ModelSerializer):
    """Full serializer for detail/create/update views."""
    age_display = serializers.ReadOnlyField()
    sire_name = serializers.CharField(source='sire.name', read_only=True, default=None)
    dam_name = serializers.CharField(source='dam.name', read_only=True, default=None)
    offspring_count = serializers.SerializerMethodField()

    class Meta:
        model = Animal
        fields = '__all__'
        read_only_fields = ['created_at', 'updated_at']

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
