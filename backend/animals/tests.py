from datetime import date, timedelta
from django.test import TestCase
from rest_framework.test import APITestCase
from rest_framework import status

from .models import Animal, HealthRecord, BreedingRecord, Litter


class AnimalModelTests(TestCase):
    def setUp(self):
        self.sire = Animal.objects.create(
            name='Max',
            species='Dog',
            breed='German Shepherd',
            sex=Animal.Sex.MALE,
            date_of_birth=date(2020, 1, 15),
        )
        self.dam = Animal.objects.create(
            name='Bella',
            species='Dog',
            breed='German Shepherd',
            sex=Animal.Sex.FEMALE,
            date_of_birth=date(2020, 6, 20),
        )

    def test_animal_creation(self):
        self.assertEqual(self.sire.name, 'Max')
        self.assertEqual(self.sire.species, 'Dog')
        self.assertEqual(self.sire.sex, Animal.Sex.MALE)

    def test_animal_str(self):
        self.assertEqual(str(self.sire), 'Max (German Shepherd)')

    def test_age_display(self):
        age = self.sire.age_display
        self.assertIsNotNone(age)
        self.assertIn('yr', age)

    def test_offspring_relationship(self):
        pup = Animal.objects.create(
            name='Rex',
            species='Dog',
            breed='German Shepherd',
            sex=Animal.Sex.MALE,
            sire=self.sire,
            dam=self.dam,
            date_of_birth=date(2022, 3, 10),
        )
        self.assertIn(pup, self.sire.offspring)
        self.assertIn(pup, self.dam.offspring)


class HealthRecordModelTests(TestCase):
    def setUp(self):
        self.animal = Animal.objects.create(
            name='Buddy',
            species='Dog',
            breed='Labrador',
            sex=Animal.Sex.MALE,
        )

    def test_health_record_creation(self):
        record = HealthRecord.objects.create(
            animal=self.animal,
            type=HealthRecord.RecordType.VACCINATION,
            title='Rabies Vaccine',
            date=date.today(),
            next_due_date=date.today() + timedelta(days=365),
        )
        self.assertEqual(record.title, 'Rabies Vaccine')
        self.assertFalse(record.is_overdue)

    def test_overdue_record(self):
        record = HealthRecord.objects.create(
            animal=self.animal,
            type=HealthRecord.RecordType.VACCINATION,
            title='Overdue Vaccine',
            date=date.today() - timedelta(days=400),
            next_due_date=date.today() - timedelta(days=35),
        )
        self.assertTrue(record.is_overdue)


class AnimalAPITests(APITestCase):
    def setUp(self):
        self.animal = Animal.objects.create(
            name='Luna',
            species='Dog',
            breed='Golden Retriever',
            sex=Animal.Sex.FEMALE,
            date_of_birth=date(2021, 5, 12),
        )

    def test_list_animals(self):
        response = self.client.get('/api/v1/animals/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_create_animal(self):
        data = {
            'name': 'Charlie',
            'species': 'Dog',
            'breed': 'Poodle',
            'sex': Animal.Sex.MALE,
        }
        response = self.client.post('/api/v1/animals/', data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(Animal.objects.count(), 2)

    def test_retrieve_animal(self):
        response = self.client.get(f'/api/v1/animals/{self.animal.pk}/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['name'], 'Luna')

    def test_update_animal(self):
        response = self.client.patch(
            f'/api/v1/animals/{self.animal.pk}/',
            {'name': 'Luna Star'},
            format='json',
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.animal.refresh_from_db()
        self.assertEqual(self.animal.name, 'Luna Star')

    def test_delete_animal(self):
        response = self.client.delete(f'/api/v1/animals/{self.animal.pk}/')
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        self.assertEqual(Animal.objects.count(), 0)

    def test_animal_stats(self):
        response = self.client.get('/api/v1/animals/stats/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['total'], 1)
        self.assertEqual(response.data['females'], 1)

    def test_filter_by_species(self):
        response = self.client.get('/api/v1/animals/', {'species': 'Dog'})
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_search_animals(self):
        response = self.client.get('/api/v1/animals/', {'search': 'Luna'})
        self.assertEqual(response.status_code, status.HTTP_200_OK)


class GeneticsAPITests(APITestCase):
    def setUp(self):
        self.grandsire = Animal.objects.create(
            name='GrandSire',
            species='Dog',
            breed='Labrador',
            sex=Animal.Sex.MALE,
        )
        self.granddam = Animal.objects.create(
            name='GrandDam',
            species='Dog',
            breed='Labrador',
            sex=Animal.Sex.FEMALE,
        )
        self.sire = Animal.objects.create(
            name='Sire',
            species='Dog',
            breed='Labrador',
            sex=Animal.Sex.MALE,
            sire=self.grandsire,
            dam=self.granddam,
            date_of_birth=date(2020, 1, 1),
        )
        self.dam = Animal.objects.create(
            name='Dam',
            species='Dog',
            breed='Labrador',
            sex=Animal.Sex.FEMALE,
            sire=self.grandsire,
            dam=self.granddam,
            date_of_birth=date(2020, 6, 1),
        )

    def test_pedigree_endpoint(self):
        response = self.client.get(f'/api/v1/genetics/{self.sire.pk}/pedigree/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['animal']['name'], 'Sire')

    def test_coi_endpoint(self):
        response = self.client.get(
            '/api/v1/genetics/coi/',
            {'sire': str(self.sire.pk), 'dam': str(self.dam.pk)},
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('coi_percentage', response.data)
        # Siblings from same parents should have COI of 25%
        self.assertGreater(response.data['coi_percentage'], 0)

    def test_coi_missing_params(self):
        response = self.client.get('/api/v1/genetics/coi/')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_suggestions_endpoint(self):
        response = self.client.get(f'/api/v1/genetics/{self.sire.pk}/suggestions/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_common_ancestors(self):
        response = self.client.get(
            '/api/v1/genetics/common-ancestors/',
            {'animal1': str(self.sire.pk), 'animal2': str(self.dam.pk)},
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
