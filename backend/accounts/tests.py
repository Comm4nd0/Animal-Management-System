from django.test import TestCase
from django.contrib.auth.models import User
from rest_framework.test import APITestCase
from rest_framework import status as http_status

from .models import UserProfile, ServiceTier, SERVICE_TIER_LIMITS
from animals.models import Animal


class ServiceTierModelTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username='farmer', password='testpass123', email='farmer@test.com'
        )
        self.profile = UserProfile.objects.create(
            user=self.user,
            service_tier=ServiceTier.STARTER,
            farm_name='Green Acres',
        )

    def test_starter_limits(self):
        self.assertEqual(self.profile.max_animals, 10)
        self.assertFalse(self.profile.allows_multi_breed)
        self.assertEqual(self.profile.tier_label, 'Starter')

    def test_enterprise_limits(self):
        self.profile.service_tier = ServiceTier.ENTERPRISE
        self.profile.save()
        self.assertIsNone(self.profile.max_animals)
        self.assertTrue(self.profile.allows_multi_breed)

    def test_can_add_animal_within_limit(self):
        self.assertTrue(self.profile.can_add_animal())
        self.assertEqual(self.profile.animals_remaining(), 10)

    def test_can_add_animal_at_limit(self):
        for i in range(10):
            Animal.objects.create(
                name=f'Animal{i}', species='Horse', breed='Thoroughbred',
                sex=Animal.Sex.MALE, owner=self.profile,
            )
        self.assertFalse(self.profile.can_add_animal())
        self.assertEqual(self.profile.animals_remaining(), 0)

    def test_breed_lock_on_first_animal(self):
        self.assertEqual(self.profile.registered_breed, '')
        self.profile.lock_breed('Horse', 'Thoroughbred')
        self.assertEqual(self.profile.registered_species, 'Horse')
        self.assertEqual(self.profile.registered_breed, 'Thoroughbred')

    def test_can_use_registered_breed(self):
        self.profile.lock_breed('Horse', 'Thoroughbred')
        self.assertTrue(self.profile.can_use_breed('Horse', 'Thoroughbred'))
        self.assertFalse(self.profile.can_use_breed('Horse', 'Arabian'))
        self.assertFalse(self.profile.can_use_breed('Cattle', 'Hereford'))

    def test_enterprise_any_breed(self):
        self.profile.service_tier = ServiceTier.ENTERPRISE
        self.profile.save()
        self.profile.lock_breed('Horse', 'Thoroughbred')
        self.assertTrue(self.profile.can_use_breed('Horse', 'Arabian'))
        self.assertTrue(self.profile.can_use_breed('Cattle', 'Hereford'))

    def test_first_animal_any_breed_allowed(self):
        """Before first animal is added, any breed should be accepted."""
        self.assertTrue(self.profile.can_use_breed('Horse', 'Arabian'))
        self.assertTrue(self.profile.can_use_breed('Cattle', 'Hereford'))

    def test_validate_animal_addition_limit(self):
        for i in range(10):
            Animal.objects.create(
                name=f'A{i}', species='Horse', breed='Thoroughbred',
                sex=Animal.Sex.MALE, owner=self.profile,
            )
        is_valid, error = self.profile.validate_animal_addition('Horse', 'Thoroughbred')
        self.assertFalse(is_valid)
        self.assertIn('limit reached', error.lower())

    def test_validate_animal_addition_wrong_breed(self):
        self.profile.lock_breed('Horse', 'Thoroughbred')
        is_valid, error = self.profile.validate_animal_addition('Horse', 'Arabian')
        self.assertFalse(is_valid)
        self.assertIn('single breed', error.lower())

    def test_all_tiers_have_limits(self):
        for tier in ServiceTier:
            self.assertIn(tier, SERVICE_TIER_LIMITS)
            limits = SERVICE_TIER_LIMITS[tier]
            self.assertIn('max_animals', limits)
            self.assertIn('allows_multi_breed', limits)
            self.assertIn('label', limits)


class AccountAPITests(APITestCase):
    def test_register_account(self):
        response = self.client.post('/api/v1/accounts/register/', {
            'username': 'newfarmer',
            'email': 'new@farm.com',
            'password': 'securepass123',
            'service_tier': ServiceTier.STANDARD,
            'farm_name': 'New Farm',
        }, format='json')
        self.assertEqual(response.status_code, http_status.HTTP_201_CREATED)
        self.assertEqual(response.data['tier_label'], 'Standard')
        self.assertEqual(response.data['max_animals'], 50)

    def test_register_duplicate_username(self):
        User.objects.create_user('taken', 'a@b.com', 'pass12345')
        response = self.client.post('/api/v1/accounts/register/', {
            'username': 'taken',
            'email': 'c@d.com',
            'password': 'securepass123',
            'service_tier': ServiceTier.STARTER,
        }, format='json')
        self.assertEqual(response.status_code, http_status.HTTP_400_BAD_REQUEST)

    def test_list_tiers(self):
        response = self.client.get('/api/v1/accounts/tiers/')
        self.assertEqual(response.status_code, http_status.HTTP_200_OK)
        self.assertEqual(len(response.data), 4)  # 4 tiers
        labels = [t['label'] for t in response.data]
        self.assertIn('Starter', labels)
        self.assertIn('Enterprise', labels)

    def test_tier_enforcement_on_animal_create(self):
        """Non-Enterprise user cannot add a different breed after first animal."""
        user = User.objects.create_user('farmer2', 'f@f.com', 'pass12345')
        profile = UserProfile.objects.create(
            user=user, service_tier=ServiceTier.STARTER,
        )
        self.client.force_authenticate(user=user)

        # First animal sets the breed
        response = self.client.post('/api/v1/animals/', {
            'name': 'Thunder',
            'species': 'Horse',
            'breed': 'Thoroughbred',
            'sex': Animal.Sex.MALE,
        }, format='json')
        self.assertEqual(response.status_code, http_status.HTTP_201_CREATED)

        profile.refresh_from_db()
        self.assertEqual(profile.registered_breed, 'Thoroughbred')

        # Second animal of different breed should be rejected
        response = self.client.post('/api/v1/animals/', {
            'name': 'Sandy',
            'species': 'Horse',
            'breed': 'Arabian',
            'sex': Animal.Sex.FEMALE,
        }, format='json')
        self.assertEqual(response.status_code, http_status.HTTP_403_FORBIDDEN)
        self.assertIn('single breed', response.data['error'].lower())

    def test_enterprise_multi_breed(self):
        """Enterprise user can add multiple breeds."""
        user = User.objects.create_user('bigfarm', 'b@f.com', 'pass12345')
        UserProfile.objects.create(
            user=user, service_tier=ServiceTier.ENTERPRISE,
        )
        self.client.force_authenticate(user=user)

        response = self.client.post('/api/v1/animals/', {
            'name': 'Thunder', 'species': 'Horse',
            'breed': 'Thoroughbred', 'sex': Animal.Sex.MALE,
        }, format='json')
        self.assertEqual(response.status_code, http_status.HTTP_201_CREATED)

        response = self.client.post('/api/v1/animals/', {
            'name': 'Daisy', 'species': 'Cattle',
            'breed': 'Hereford', 'sex': Animal.Sex.FEMALE,
        }, format='json')
        self.assertEqual(response.status_code, http_status.HTTP_201_CREATED)

    def test_stats_include_tier_info(self):
        user = User.objects.create_user('f3', 'f3@f.com', 'pass12345')
        UserProfile.objects.create(
            user=user, service_tier=ServiceTier.PROFESSIONAL,
        )
        self.client.force_authenticate(user=user)
        response = self.client.get('/api/v1/animals/stats/')
        self.assertEqual(response.status_code, http_status.HTTP_200_OK)
        self.assertEqual(response.data['tier'], 'Professional')
        self.assertEqual(response.data['max_animals'], 200)
