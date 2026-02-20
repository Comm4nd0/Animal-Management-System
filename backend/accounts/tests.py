from django.test import TestCase
from django.contrib.auth.models import User
from rest_framework.test import APITestCase
from rest_framework import status as http_status

from .models import (
    UserProfile, ServiceTier, UserRole,
    TierConfiguration, get_tier_limits, get_all_tier_limits,
    SERVICE_TIER_DEFAULTS,
)
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

    def test_all_tiers_have_defaults(self):
        for tier in ServiceTier:
            self.assertIn(tier, SERVICE_TIER_DEFAULTS)
            limits = SERVICE_TIER_DEFAULTS[tier]
            self.assertIn('max_animals', limits)
            self.assertIn('allows_multi_breed', limits)
            self.assertIn('max_users', limits)
            self.assertIn('label', limits)

    def test_get_tier_limits_uses_db(self):
        """get_tier_limits() should read from TierConfiguration when it exists."""
        # The migration seeds defaults, so DB rows exist
        limits = get_tier_limits(ServiceTier.STARTER)
        self.assertEqual(limits['max_animals'], 10)
        # Override in DB
        TierConfiguration.objects.filter(tier=ServiceTier.STARTER).update(max_animals=25)
        limits = get_tier_limits(ServiceTier.STARTER)
        self.assertEqual(limits['max_animals'], 25)

    def test_get_tier_limits_falls_back(self):
        """If DB row is deleted, falls back to hard-coded defaults."""
        TierConfiguration.objects.filter(tier=ServiceTier.STARTER).delete()
        limits = get_tier_limits(ServiceTier.STARTER)
        self.assertEqual(limits['max_animals'], 10)  # from SERVICE_TIER_DEFAULTS

    def test_get_all_tier_limits_merges(self):
        """get_all_tier_limits() returns all tiers with DB overrides."""
        all_limits = get_all_tier_limits()
        self.assertEqual(len(all_limits), 4)
        self.assertIn(ServiceTier.ENTERPRISE, all_limits)


class UserRoleModelTests(TestCase):
    def setUp(self):
        self.owner_user = User.objects.create_user(
            username='owner', password='testpass123', email='owner@test.com'
        )
        self.owner = UserProfile.objects.create(
            user=self.owner_user,
            role=UserRole.OWNER,
            service_tier=ServiceTier.PROFESSIONAL,
            farm_name='Owner Farm',
        )

    def test_owner_properties(self):
        self.assertTrue(self.owner.is_owner)
        self.assertFalse(self.owner.is_admin)
        self.assertTrue(self.owner.can_manage_users)
        self.assertTrue(self.owner.can_write_data)
        self.assertIsNone(self.owner.organization)
        self.assertEqual(self.owner.organization_owner, self.owner)

    def test_admin_properties(self):
        admin_user = User.objects.create_user('admin', 'admin@test.com', 'pass12345')
        admin = UserProfile.objects.create(
            user=admin_user, role=UserRole.ADMIN,
            organization=self.owner, service_tier=ServiceTier.PROFESSIONAL,
        )
        self.assertTrue(admin.is_admin)
        self.assertTrue(admin.can_manage_users)
        self.assertTrue(admin.can_write_data)
        self.assertEqual(admin.organization_owner, self.owner)

    def test_contributor_properties(self):
        contrib_user = User.objects.create_user('contrib', 'c@test.com', 'pass12345')
        contrib = UserProfile.objects.create(
            user=contrib_user, role=UserRole.CONTRIBUTOR,
            organization=self.owner, service_tier=ServiceTier.PROFESSIONAL,
        )
        self.assertFalse(contrib.can_manage_users)
        self.assertTrue(contrib.can_write_data)

    def test_read_only_properties(self):
        ro_user = User.objects.create_user('viewer', 'v@test.com', 'pass12345')
        ro = UserProfile.objects.create(
            user=ro_user, role=UserRole.READ_ONLY,
            organization=self.owner, service_tier=ServiceTier.PROFESSIONAL,
        )
        self.assertFalse(ro.can_manage_users)
        self.assertFalse(ro.can_write_data)
        self.assertTrue(ro.is_read_only)

    def test_team_members_count(self):
        self.assertEqual(self.owner.get_team_count(), 1)  # Just the owner
        admin_user = User.objects.create_user('admin2', 'a2@test.com', 'pass12345')
        UserProfile.objects.create(
            user=admin_user, role=UserRole.ADMIN,
            organization=self.owner, service_tier=ServiceTier.PROFESSIONAL,
        )
        self.assertEqual(self.owner.get_team_count(), 2)

    def test_can_add_user_within_limit(self):
        self.assertTrue(self.owner.can_add_user())  # Professional: 10 users

    def test_max_users_per_tier(self):
        """Default limits should be correct (from DB seed or fallback)."""
        self.assertEqual(get_tier_limits(ServiceTier.STARTER)['max_users'], 1)
        self.assertEqual(get_tier_limits(ServiceTier.STANDARD)['max_users'], 3)
        self.assertEqual(get_tier_limits(ServiceTier.PROFESSIONAL)['max_users'], 10)
        self.assertIsNone(get_tier_limits(ServiceTier.ENTERPRISE)['max_users'])

    def test_db_override_affects_profile(self):
        """Changing TierConfiguration in the DB should immediately affect UserProfile."""
        TierConfiguration.objects.filter(tier=ServiceTier.PROFESSIONAL).update(max_animals=500)
        self.assertEqual(self.owner.max_animals, 500)


class AuthenticationTests(APITestCase):
    def test_login_with_username(self):
        User.objects.create_user('farmer', 'f@f.com', 'pass12345')
        response = self.client.post('/api/v1/accounts/login/', {
            'username': 'farmer',
            'password': 'pass12345',
        }, format='json')
        self.assertEqual(response.status_code, http_status.HTTP_200_OK)
        self.assertIn('token', response.data)
        self.assertIn('user', response.data)

    def test_login_with_email(self):
        User.objects.create_user('farmer2', 'farmer@test.com', 'pass12345')
        response = self.client.post('/api/v1/accounts/login/', {
            'username': 'farmer@test.com',
            'password': 'pass12345',
        }, format='json')
        self.assertEqual(response.status_code, http_status.HTTP_200_OK)
        self.assertIn('token', response.data)

    def test_login_invalid_credentials(self):
        response = self.client.post('/api/v1/accounts/login/', {
            'username': 'nobody',
            'password': 'wrong',
        }, format='json')
        self.assertEqual(response.status_code, http_status.HTTP_401_UNAUTHORIZED)

    def test_logout(self):
        user = User.objects.create_user('logmeout', 'l@t.com', 'pass12345')
        self.client.force_authenticate(user=user)
        response = self.client.post('/api/v1/accounts/logout/')
        self.assertEqual(response.status_code, http_status.HTTP_204_NO_CONTENT)


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

    def test_register_creates_owner(self):
        """Registration should create an owner-role profile."""
        response = self.client.post('/api/v1/accounts/register/', {
            'username': 'newowner',
            'email': 'owner@new.com',
            'password': 'securepass123',
            'service_tier': ServiceTier.STANDARD,
            'farm_name': 'New Farm',
        }, format='json')
        self.assertEqual(response.status_code, http_status.HTTP_201_CREATED)
        self.assertEqual(response.data['role'], UserRole.OWNER)
        self.assertEqual(response.data['role_label'], 'Owner')

    def test_me_includes_role_info(self):
        user = User.objects.create_user('me_user', 'me@t.com', 'pass12345')
        UserProfile.objects.create(
            user=user, role=UserRole.OWNER,
            service_tier=ServiceTier.STANDARD,
        )
        self.client.force_authenticate(user=user)
        response = self.client.get('/api/v1/accounts/me/')
        self.assertEqual(response.status_code, http_status.HTTP_200_OK)
        self.assertEqual(response.data['role'], UserRole.OWNER)
        self.assertTrue(response.data['can_manage_users'])
        self.assertTrue(response.data['can_write_data'])
        self.assertEqual(response.data['team_count'], 1)


class TeamManagementAPITests(APITestCase):
    def setUp(self):
        self.owner_user = User.objects.create_user(
            'teamowner', 'to@test.com', 'pass12345'
        )
        self.owner = UserProfile.objects.create(
            user=self.owner_user, role=UserRole.OWNER,
            service_tier=ServiceTier.PROFESSIONAL,
            farm_name='Team Farm',
        )
        self.client.force_authenticate(user=self.owner_user)

    def test_list_team_members(self):
        response = self.client.get('/api/v1/accounts/team/')
        self.assertEqual(response.status_code, http_status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)  # Just the owner
        self.assertEqual(response.data[0]['role'], UserRole.OWNER)

    def test_invite_user(self):
        response = self.client.post('/api/v1/accounts/invite-user/', {
            'username': 'newmember',
            'email': 'nm@test.com',
            'password': 'securepass123',
            'role': UserRole.CONTRIBUTOR,
        }, format='json')
        self.assertEqual(response.status_code, http_status.HTTP_201_CREATED)
        self.assertEqual(response.data['role'], UserRole.CONTRIBUTOR)
        self.assertEqual(self.owner.get_team_count(), 2)

    def test_invite_user_cannot_invite_as_owner(self):
        response = self.client.post('/api/v1/accounts/invite-user/', {
            'username': 'fake_owner',
            'email': 'fo@test.com',
            'password': 'securepass123',
            'role': UserRole.OWNER,
        }, format='json')
        self.assertEqual(response.status_code, http_status.HTTP_400_BAD_REQUEST)

    def test_update_role(self):
        member_user = User.objects.create_user('mem', 'm@test.com', 'pass12345')
        member = UserProfile.objects.create(
            user=member_user, role=UserRole.READ_ONLY,
            organization=self.owner, service_tier=ServiceTier.PROFESSIONAL,
        )
        response = self.client.post('/api/v1/accounts/update-role/', {
            'member_id': str(member.id),
            'role': UserRole.CONTRIBUTOR,
        }, format='json')
        self.assertEqual(response.status_code, http_status.HTTP_200_OK)
        member.refresh_from_db()
        self.assertEqual(member.role, UserRole.CONTRIBUTOR)

    def test_cannot_change_owner_role(self):
        response = self.client.post('/api/v1/accounts/update-role/', {
            'member_id': str(self.owner.id),
            'role': UserRole.ADMIN,
        }, format='json')
        self.assertEqual(response.status_code, http_status.HTTP_403_FORBIDDEN)

    def test_remove_team_member(self):
        member_user = User.objects.create_user('rem', 'r@test.com', 'pass12345')
        member = UserProfile.objects.create(
            user=member_user, role=UserRole.CONTRIBUTOR,
            organization=self.owner, service_tier=ServiceTier.PROFESSIONAL,
        )
        response = self.client.post('/api/v1/accounts/remove-user/', {
            'member_id': str(member.id),
        }, format='json')
        self.assertEqual(response.status_code, http_status.HTTP_204_NO_CONTENT)
        self.assertEqual(self.owner.get_team_count(), 1)

    def test_cannot_remove_owner(self):
        response = self.client.post('/api/v1/accounts/remove-user/', {
            'member_id': str(self.owner.id),
        }, format='json')
        self.assertEqual(response.status_code, http_status.HTTP_403_FORBIDDEN)

    def test_admin_cannot_invite_admin(self):
        admin_user = User.objects.create_user('adm', 'a@test.com', 'pass12345')
        UserProfile.objects.create(
            user=admin_user, role=UserRole.ADMIN,
            organization=self.owner, service_tier=ServiceTier.PROFESSIONAL,
        )
        self.client.force_authenticate(user=admin_user)
        response = self.client.post('/api/v1/accounts/invite-user/', {
            'username': 'another_admin',
            'email': 'aa@test.com',
            'password': 'securepass123',
            'role': UserRole.ADMIN,
        }, format='json')
        self.assertEqual(response.status_code, http_status.HTTP_403_FORBIDDEN)

    def test_read_only_cannot_invite(self):
        ro_user = User.objects.create_user('ro', 'ro@test.com', 'pass12345')
        UserProfile.objects.create(
            user=ro_user, role=UserRole.READ_ONLY,
            organization=self.owner, service_tier=ServiceTier.PROFESSIONAL,
        )
        self.client.force_authenticate(user=ro_user)
        response = self.client.post('/api/v1/accounts/invite-user/', {
            'username': 'should_fail',
            'email': 'sf@test.com',
            'password': 'securepass123',
            'role': UserRole.READ_ONLY,
        }, format='json')
        self.assertEqual(response.status_code, http_status.HTTP_403_FORBIDDEN)

    def test_tiers_include_max_users(self):
        response = self.client.get('/api/v1/accounts/tiers/')
        self.assertEqual(response.status_code, http_status.HTTP_200_OK)
        for tier in response.data:
            self.assertIn('max_users', tier)
