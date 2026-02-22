import uuid
from django.core.exceptions import ValidationError
from django.db import models


class Contact(models.Model):
    """
    A person or organisation that can be assigned as a breeder or
    current owner of an animal.  Both roles draw from the same table.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    account = models.ForeignKey(
        'accounts.UserProfile',
        on_delete=models.CASCADE,
        related_name='contacts',
        help_text='The user account this contact belongs to',
    )
    name = models.CharField(max_length=200)
    farm_name = models.CharField(max_length=200, blank=True, default='')
    email = models.EmailField(blank=True, default='')
    phone = models.CharField(max_length=50, blank=True, default='')
    address = models.TextField(blank=True, default='')
    prefix = models.CharField(
        max_length=100, blank=True, default='',
        help_text='Breeding prefix / affix',
    )
    notes = models.TextField(blank=True, default='')
    custom_fields = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['name']

    def __str__(self):
        if self.farm_name:
            return f'{self.name} ({self.farm_name})'
        return self.name


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
    registration_date = models.DateField(null=True, blank=True)
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
    account = models.ForeignKey(
        'accounts.UserProfile',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='animals',
        help_text='The user account that owns this animal record',
    )
    current_owner = models.ForeignKey(
        Contact,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='owned_animals',
        help_text='The current owner / keeper of this animal',
    )
    breeder = models.ForeignKey(
        Contact,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='bred_animals',
        help_text='The breeder of this animal',
    )
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

    def clean(self):
        """Validate pedigree integrity before saving."""
        errors = {}

        # Self-reference
        if self.sire_id and self.sire_id == self.pk:
            errors['sire'] = 'An animal cannot be its own sire.'
        if self.dam_id and self.dam_id == self.pk:
            errors['dam'] = 'An animal cannot be its own dam.'

        # Same animal as both parents
        if self.sire_id and self.dam_id and self.sire_id == self.dam_id:
            errors['dam'] = 'Sire and dam cannot be the same animal.'

        # Sex mismatch
        if self.sire_id:
            try:
                sire = Animal.objects.get(pk=self.sire_id)
                if sire.sex == self.Sex.FEMALE:
                    errors['sire'] = f'The sire ({sire.name}) is female.'
            except Animal.DoesNotExist:
                pass
        if self.dam_id:
            try:
                dam = Animal.objects.get(pk=self.dam_id)
                if dam.sex == self.Sex.MALE:
                    errors['dam'] = f'The dam ({dam.name}) is male.'
            except Animal.DoesNotExist:
                pass

        # Date-of-birth checks
        if self.date_of_birth:
            if self.sire_id:
                try:
                    sire = Animal.objects.get(pk=self.sire_id)
                    if sire.date_of_birth and sire.date_of_birth >= self.date_of_birth:
                        errors['sire'] = (
                            f'The sire ({sire.name}) was born on or after this animal.'
                        )
                except Animal.DoesNotExist:
                    pass
            if self.dam_id:
                try:
                    dam = Animal.objects.get(pk=self.dam_id)
                    if dam.date_of_birth and dam.date_of_birth >= self.date_of_birth:
                        errors['dam'] = (
                            f'The dam ({dam.name}) was born on or after this animal.'
                        )
                except Animal.DoesNotExist:
                    pass

            if self.date_of_death and self.date_of_death < self.date_of_birth:
                errors['date_of_death'] = 'Date of death cannot be before date of birth.'

        # Circular ancestry — walk up the ancestor chain.
        # Bounded by pedigree depth, not total animals, so safe at scale.
        for field_name, parent_id in [('sire', self.sire_id), ('dam', self.dam_id)]:
            if parent_id and parent_id != self.pk:
                if self._has_circular_ancestry(parent_id):
                    errors[field_name] = (
                        'Setting this parent would create a circular pedigree.'
                    )

        if errors:
            raise ValidationError(errors)

    def _has_circular_ancestry(self, start_id, max_depth=30):
        """Walk ancestors from start_id looking for self.pk."""
        visited = set()
        queue = [start_id]
        depth = 0
        while queue and depth < max_depth:
            next_queue = []
            for current_id in queue:
                if current_id == self.pk:
                    return True
                if current_id in visited:
                    continue
                visited.add(current_id)
                try:
                    ancestor = Animal.objects.only('sire_id', 'dam_id').get(pk=current_id)
                    if ancestor.sire_id:
                        next_queue.append(ancestor.sire_id)
                    if ancestor.dam_id:
                        next_queue.append(ancestor.dam_id)
                except Animal.DoesNotExist:
                    pass
            queue = next_queue
            depth += 1
        return False

    def save(self, *args, **kwargs):
        self.full_clean()
        super().save(*args, **kwargs)

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


class AnimalImage(models.Model):
    """An image associated with an animal. One can be marked as profile image."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    animal = models.ForeignKey(
        Animal, on_delete=models.CASCADE, related_name='images'
    )
    image = models.ImageField(upload_to='animal_images/')
    caption = models.CharField(max_length=200, blank=True, default='')
    is_profile = models.BooleanField(default=False)
    uploaded_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-is_profile', '-uploaded_at']

    def __str__(self):
        label = 'Profile' if self.is_profile else 'Photo'
        return f'{label} - {self.animal.name}'

    def save(self, *args, **kwargs):
        if self.is_profile:
            AnimalImage.objects.filter(
                animal=self.animal, is_profile=True
            ).exclude(pk=self.pk).update(is_profile=False)
        super().save(*args, **kwargs)


class CustomFieldDefinition(models.Model):
    """
    Defines a custom field that a user can create for their animals,
    contacts (breeders/owners), or pedigree records.
    The actual values are stored in the respective model's custom_fields JSONField.
    """

    class FieldType(models.IntegerChoices):
        TEXT = 0, 'Text'
        NUMBER = 1, 'Number'
        DATE = 2, 'Date'
        BOOLEAN = 3, 'Yes/No'
        DROPDOWN = 4, 'Dropdown'

    class EntityType(models.IntegerChoices):
        ANIMAL = 0, 'Animal'
        CONTACT = 1, 'Contact'
        PEDIGREE = 2, 'Pedigree'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    owner = models.ForeignKey(
        'accounts.UserProfile',
        on_delete=models.CASCADE,
        related_name='custom_field_definitions',
    )
    name = models.CharField(
        max_length=100,
        help_text='Display name for the custom field',
    )
    field_key = models.CharField(
        max_length=100,
        help_text='Storage key used in the custom_fields JSON (auto-generated from name)',
    )
    field_type = models.IntegerField(choices=FieldType.choices, default=FieldType.TEXT)
    entity_type = models.IntegerField(
        choices=EntityType.choices,
        default=EntityType.ANIMAL,
        help_text='Which record type this field applies to',
    )
    required = models.BooleanField(default=False)
    options = models.JSONField(
        default=list,
        blank=True,
        help_text='List of options for dropdown fields',
    )
    display_order = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['display_order', 'name']
        unique_together = [['owner', 'field_key', 'entity_type']]

    def __str__(self):
        return f'{self.name} ({self.get_field_type_display()}) [{self.get_entity_type_display()}]'

    def save(self, *args, **kwargs):
        if not self.field_key:
            import re
            self.field_key = self.name.lower().replace(' ', '_').replace('-', '_')
            self.field_key = re.sub(r'[^a-z0-9_]', '', self.field_key)
        super().save(*args, **kwargs)


class WeightRecord(models.Model):
    """Tracks weight/height measurements over time for growth curves."""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    animal = models.ForeignKey(
        Animal, on_delete=models.CASCADE, related_name='weight_records'
    )
    date = models.DateField()
    weight = models.DecimalField(
        max_digits=8, decimal_places=2, null=True, blank=True,
        help_text='Weight in kg'
    )
    height = models.DecimalField(
        max_digits=8, decimal_places=2, null=True, blank=True,
        help_text='Height in cm'
    )
    notes = models.TextField(blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-date']
        indexes = [
            models.Index(fields=['animal', '-date']),
        ]

    def __str__(self):
        return f'{self.animal.name} - {self.date}'


class ShowResult(models.Model):
    """Records show/competition results for pedigree animals."""

    class Placement(models.IntegerChoices):
        FIRST = 1, '1st Place'
        SECOND = 2, '2nd Place'
        THIRD = 3, '3rd Place'
        FOURTH = 4, '4th Place'
        FIFTH = 5, '5th Place'
        RESERVE = 10, 'Reserve'
        CHAMPION = 20, 'Champion'
        BEST_IN_SHOW = 30, 'Best in Show'
        PARTICIPATED = 99, 'Participated'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    animal = models.ForeignKey(
        Animal, on_delete=models.CASCADE, related_name='show_results'
    )
    show_name = models.CharField(max_length=300)
    show_date = models.DateField()
    class_name = models.CharField(
        max_length=200, blank=True, default='',
        help_text='e.g. Open, Yearling, Junior Handler'
    )
    placement = models.IntegerField(
        choices=Placement.choices, default=Placement.PARTICIPATED
    )
    judge = models.CharField(max_length=200, blank=True, default='')
    points = models.DecimalField(
        max_digits=8, decimal_places=2, null=True, blank=True,
        help_text='Points or score awarded'
    )
    notes = models.TextField(blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-show_date']
        indexes = [
            models.Index(fields=['animal', '-show_date']),
        ]

    def __str__(self):
        return f'{self.animal.name} - {self.show_name} ({self.get_placement_display()})'


class FinancialRecord(models.Model):
    """Tracks income and expenses per animal."""

    class TransactionType(models.IntegerChoices):
        EXPENSE = 0, 'Expense'
        INCOME = 1, 'Income'

    class Category(models.IntegerChoices):
        FEED = 0, 'Feed'
        VETERINARY = 1, 'Veterinary'
        REGISTRATION = 2, 'Registration'
        INSURANCE = 3, 'Insurance'
        TRANSPORT = 4, 'Transport'
        EQUIPMENT = 5, 'Equipment'
        STUD_FEE = 6, 'Stud Fee'
        SALE = 7, 'Sale'
        PRIZE_MONEY = 8, 'Prize Money'
        OTHER = 99, 'Other'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    animal = models.ForeignKey(
        Animal, on_delete=models.CASCADE, related_name='financial_records'
    )
    date = models.DateField()
    transaction_type = models.IntegerField(choices=TransactionType.choices)
    category = models.IntegerField(choices=Category.choices, default=Category.OTHER)
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    description = models.CharField(max_length=500, blank=True, default='')
    receipt = models.FileField(upload_to='receipts/', null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-date']
        indexes = [
            models.Index(fields=['animal', '-date']),
        ]

    def __str__(self):
        return f'{self.animal.name} - {self.get_category_display()} ({self.amount})'


class DocumentAttachment(models.Model):
    """Stores documents (certificates, contracts, DNA results, etc.) per animal."""

    class DocumentType(models.IntegerChoices):
        PEDIGREE_CERT = 0, 'Pedigree Certificate'
        REGISTRATION = 1, 'Registration Paper'
        DNA_TEST = 2, 'DNA Test Result'
        HEALTH_CERT = 3, 'Health Certificate'
        INSURANCE = 4, 'Insurance'
        CONTRACT = 5, 'Contract'
        PHOTO_ID = 6, 'Photo ID'
        OTHER = 99, 'Other'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    animal = models.ForeignKey(
        Animal, on_delete=models.CASCADE, related_name='documents'
    )
    title = models.CharField(max_length=300)
    document_type = models.IntegerField(
        choices=DocumentType.choices, default=DocumentType.OTHER
    )
    file = models.FileField(upload_to='animal_documents/')
    notes = models.TextField(blank=True, default='')
    uploaded_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-uploaded_at']

    def __str__(self):
        return f'{self.title} - {self.animal.name}'
