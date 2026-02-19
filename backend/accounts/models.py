import uuid
from django.conf import settings
from django.db import models


class ServiceTier(models.IntegerChoices):
    """
    Service tiers determine the capabilities available to each account.

    - STARTER / STANDARD / PROFESSIONAL: single breed only
    - ENTERPRISE: multi-species and multi-breed allowed
    """
    STARTER = 0, 'Starter'
    STANDARD = 1, 'Standard'
    PROFESSIONAL = 2, 'Professional'
    ENTERPRISE = 3, 'Enterprise'


# Limits per tier: (max_animals, allows_multi_breed)
SERVICE_TIER_LIMITS = {
    ServiceTier.STARTER: {
        'max_animals': 10,
        'allows_multi_breed': False,
        'label': 'Starter',
        'description': 'Up to 10 animals, single breed',
    },
    ServiceTier.STANDARD: {
        'max_animals': 50,
        'allows_multi_breed': False,
        'label': 'Standard',
        'description': 'Up to 50 animals, single breed',
    },
    ServiceTier.PROFESSIONAL: {
        'max_animals': 200,
        'allows_multi_breed': False,
        'label': 'Professional',
        'description': 'Up to 200 animals, single breed',
    },
    ServiceTier.ENTERPRISE: {
        'max_animals': None,  # unlimited
        'allows_multi_breed': True,
        'label': 'Enterprise',
        'description': 'Unlimited animals, multiple species and breeds',
    },
}


class UserProfile(models.Model):
    """
    Extends the built-in User model with service tier and account details.

    Each user account is locked to a single breed (species inferred from breed)
    unless they are on the Enterprise tier.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='profile',
    )
    service_tier = models.IntegerField(
        choices=ServiceTier.choices,
        default=ServiceTier.STARTER,
    )
    # The single species this account is registered for (e.g. "Horse", "Cattle")
    # Only enforced for non-Enterprise tiers.
    registered_species = models.CharField(
        max_length=100,
        blank=True,
        default='',
        help_text='The species this account manages. Set on first animal or by user.',
    )
    # The single breed this account is registered for (e.g. "Thoroughbred")
    # Only enforced for non-Enterprise tiers.
    registered_breed = models.CharField(
        max_length=200,
        blank=True,
        default='',
        help_text='The breed this account manages. Set on first animal or by user.',
    )
    farm_name = models.CharField(max_length=300, blank=True, default='')
    contact_phone = models.CharField(max_length=30, blank=True, default='')
    address = models.TextField(blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'{self.user.username} ({self.get_service_tier_display()})'

    # ─── Tier helpers ─────────────────────────────────────────────

    @property
    def tier_limits(self):
        return SERVICE_TIER_LIMITS[self.service_tier]

    @property
    def max_animals(self):
        return self.tier_limits['max_animals']

    @property
    def allows_multi_breed(self):
        return self.tier_limits['allows_multi_breed']

    @property
    def tier_label(self):
        return self.tier_limits['label']

    @property
    def tier_description(self):
        return self.tier_limits['description']

    def get_animal_count(self):
        """Current number of animals owned by this user."""
        from animals.models import Animal
        return Animal.objects.filter(owner=self).count()

    def can_add_animal(self):
        """Check if the user can add another animal within their tier limit."""
        limit = self.max_animals
        if limit is None:
            return True
        return self.get_animal_count() < limit

    def animals_remaining(self):
        """Number of animals that can still be added."""
        limit = self.max_animals
        if limit is None:
            return None  # unlimited
        return max(0, limit - self.get_animal_count())

    def can_use_breed(self, species, breed):
        """
        Check if the given species/breed is allowed for this account.

        Enterprise accounts: any species/breed allowed.
        Other tiers: must match the registered breed.
        If no breed is registered yet, the first animal sets it.
        """
        if self.allows_multi_breed:
            return True

        # First animal sets the breed
        if not self.registered_breed:
            return True

        return self.registered_species == species and self.registered_breed == breed

    def lock_breed(self, species, breed):
        """
        Lock this account to a specific species and breed.
        Called when the first animal is added on a non-Enterprise tier.
        """
        if not self.allows_multi_breed and not self.registered_breed:
            self.registered_species = species
            self.registered_breed = breed
            self.save(update_fields=['registered_species', 'registered_breed'])

    def validate_animal_addition(self, species, breed):
        """
        Full validation for adding an animal. Returns (is_valid, error_message).
        """
        if not self.can_add_animal():
            limit = self.max_animals
            return False, (
                f'Animal limit reached. Your {self.tier_label} plan allows '
                f'up to {limit} animals. Upgrade your plan to add more.'
            )

        if not self.can_use_breed(species, breed):
            return False, (
                f'Your {self.tier_label} plan only allows a single breed. '
                f'This account is registered for {self.registered_species} - '
                f'{self.registered_breed}. Upgrade to Enterprise for '
                f'multi-species/breed support.'
            )

        return True, ''
