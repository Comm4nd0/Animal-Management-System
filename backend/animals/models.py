import uuid
from django.db import models


class Animal(models.Model):
    """Represents a pedigree animal with lineage tracking."""

    class Sex(models.IntegerChoices):
        MALE = 0, 'Male'
        FEMALE = 1, 'Female'
        UNKNOWN = 2, 'Unknown'

    class Status(models.IntegerChoices):
        ALIVE = 0, 'Alive'
        DECEASED = 1, 'Deceased'
        SOLD = 2, 'Sold'
        TRANSFERRED = 3, 'Transferred'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=200)
    species = models.CharField(max_length=100, db_index=True)
    breed = models.CharField(max_length=200, db_index=True)
    sex = models.IntegerField(choices=Sex.choices)
    date_of_birth = models.DateField(null=True, blank=True)
    date_of_death = models.DateField(null=True, blank=True)
    color = models.CharField(max_length=100, blank=True, default='')
    markings = models.CharField(max_length=200, blank=True, default='')
    registration_number = models.CharField(
        max_length=100, blank=True, default='', db_index=True
    )
    microchip_number = models.CharField(
        max_length=100, blank=True, default='', db_index=True
    )
    dna_profile_id = models.CharField(max_length=100, blank=True, default='')
    sire = models.ForeignKey(
        'self',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='sire_offspring',
    )
    dam = models.ForeignKey(
        'self',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='dam_offspring',
    )
    owner_name = models.CharField(max_length=200, blank=True, default='')
    breeder_name = models.CharField(max_length=200, blank=True, default='')
    image = models.ImageField(upload_to='animals/', null=True, blank=True)
    weight = models.DecimalField(
        max_digits=8, decimal_places=2, null=True, blank=True,
        help_text='Weight in kg'
    )
    height = models.DecimalField(
        max_digits=8, decimal_places=2, null=True, blank=True,
        help_text='Height in cm'
    )
    status = models.IntegerField(choices=Status.choices, default=Status.ALIVE)
    genetic_traits = models.JSONField(default=dict, blank=True)
    custom_fields = models.JSONField(default=dict, blank=True)
    notes = models.TextField(blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['name']
        indexes = [
            models.Index(fields=['species', 'breed']),
            models.Index(fields=['sire']),
            models.Index(fields=['dam']),
        ]

    def __str__(self):
        return f'{self.name} ({self.breed})'

    @property
    def offspring(self):
        """Returns all direct offspring of this animal."""
        if self.sex == self.Sex.MALE:
            return Animal.objects.filter(sire=self)
        return Animal.objects.filter(dam=self)

    @property
    def age_display(self):
        if not self.date_of_birth:
            return None
        from datetime import date
        end = self.date_of_death or date.today()
        delta = end - self.date_of_birth
        days = delta.days
        years = days // 365
        months = (days % 365) // 30
        if years > 0:
            return f'{years} yr{"s" if years > 1 else ""} {months} mo'
        if months > 0:
            return f'{months} mo'
        return f'{days} days'


class HealthRecord(models.Model):
    """Tracks vaccinations, exams, surgeries, and other health events."""

    class RecordType(models.IntegerChoices):
        VACCINATION = 0, 'Vaccination'
        EXAMINATION = 1, 'Examination'
        SURGERY = 2, 'Surgery'
        MEDICATION = 3, 'Medication'
        LAB_TEST = 4, 'Lab Test'
        DEWORMING = 5, 'Deworming'
        DENTAL = 6, 'Dental'
        OTHER = 7, 'Other'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    animal = models.ForeignKey(
        Animal, on_delete=models.CASCADE, related_name='health_records'
    )
    type = models.IntegerField(choices=RecordType.choices)
    title = models.CharField(max_length=200)
    description = models.TextField(blank=True, default='')
    date = models.DateField()
    next_due_date = models.DateField(null=True, blank=True)
    veterinarian = models.CharField(max_length=200, blank=True, default='')
    clinic = models.CharField(max_length=200, blank=True, default='')
    cost = models.DecimalField(
        max_digits=10, decimal_places=2, null=True, blank=True
    )
    document = models.FileField(
        upload_to='health_documents/', null=True, blank=True
    )
    details = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-date']
        indexes = [
            models.Index(fields=['animal', '-date']),
        ]

    def __str__(self):
        return f'{self.title} - {self.animal.name}'

    @property
    def is_overdue(self):
        if not self.next_due_date:
            return False
        from datetime import date
        return self.next_due_date < date.today()

    @property
    def is_due_soon(self):
        if not self.next_due_date or self.is_overdue:
            return False
        from datetime import date, timedelta
        return self.next_due_date <= date.today() + timedelta(days=30)


class BreedingRecord(models.Model):
    """Records breeding events between a sire and dam."""

    class Status(models.IntegerChoices):
        PLANNED = 0, 'Planned'
        CONFIRMED = 1, 'Confirmed'
        PREGNANT = 2, 'Pregnant'
        WHELPING = 3, 'Whelping'
        COMPLETED = 4, 'Completed'
        UNSUCCESSFUL = 5, 'Unsuccessful'
        CANCELLED = 6, 'Cancelled'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    sire = models.ForeignKey(
        Animal, on_delete=models.CASCADE, related_name='breeding_as_sire'
    )
    dam = models.ForeignKey(
        Animal, on_delete=models.CASCADE, related_name='breeding_as_dam'
    )
    breeding_date = models.DateField()
    expected_due_date = models.DateField(null=True, blank=True)
    actual_due_date = models.DateField(null=True, blank=True)
    status = models.IntegerField(
        choices=Status.choices, default=Status.PLANNED
    )
    litter = models.ForeignKey(
        'Litter',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='breeding_record',
    )
    method = models.CharField(
        max_length=50, blank=True, default='',
        help_text='e.g., Natural, Artificial Insemination'
    )
    veterinarian = models.CharField(max_length=200, blank=True, default='')
    notes = models.TextField(blank=True, default='')
    sire_coi_contribution = models.FloatField(null=True, blank=True)
    dam_coi_contribution = models.FloatField(null=True, blank=True)
    expected_offspring_coi = models.FloatField(null=True, blank=True)
    genetic_test_results = models.JSONField(default=list, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-breeding_date']
        indexes = [
            models.Index(fields=['sire', 'dam']),
            models.Index(fields=['status']),
        ]

    def __str__(self):
        return f'{self.sire.name} x {self.dam.name} ({self.breeding_date})'

    @property
    def gestation_days_remaining(self):
        if not self.expected_due_date:
            return None
        from datetime import date
        return (self.expected_due_date - date.today()).days


class Litter(models.Model):
    """Records a litter resulting from a breeding."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    sire = models.ForeignKey(
        Animal, on_delete=models.CASCADE, related_name='litters_as_sire'
    )
    dam = models.ForeignKey(
        Animal, on_delete=models.CASCADE, related_name='litters_as_dam'
    )
    date_of_birth = models.DateField()
    total_puppies = models.PositiveIntegerField(default=0)
    male_count = models.PositiveIntegerField(default=0)
    female_count = models.PositiveIntegerField(default=0)
    stillborn = models.PositiveIntegerField(default=0)
    offspring = models.ManyToManyField(
        Animal, blank=True, related_name='birth_litter'
    )
    registration_number = models.CharField(
        max_length=100, blank=True, default=''
    )
    notes = models.TextField(blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-date_of_birth']

    def __str__(self):
        return f'Litter: {self.sire.name} x {self.dam.name} ({self.date_of_birth})'

    @property
    def surviving_count(self):
        return self.total_puppies - self.stillborn
