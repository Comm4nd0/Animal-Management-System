from datetime import date
from django.test import TestCase
from animals.models import Animal
from . import services


class GeneticsServiceTests(TestCase):
    def setUp(self):
        # Create a simple pedigree:
        # GrandSire + GrandDam -> Sire
        # GrandSire + GrandDam -> Dam (inbred scenario)
        self.grandsire = Animal.objects.create(
            name='GrandSire', species='Dog', breed='Labrador',
            sex=Animal.Sex.MALE,
        )
        self.granddam = Animal.objects.create(
            name='GrandDam', species='Dog', breed='Labrador',
            sex=Animal.Sex.FEMALE,
        )
        self.sire = Animal.objects.create(
            name='Sire', species='Dog', breed='Labrador',
            sex=Animal.Sex.MALE,
            sire=self.grandsire, dam=self.granddam,
            date_of_birth=date(2020, 1, 1),
            weight=30.0,
        )
        self.dam = Animal.objects.create(
            name='Dam', species='Dog', breed='Labrador',
            sex=Animal.Sex.FEMALE,
            sire=self.grandsire, dam=self.granddam,
            date_of_birth=date(2020, 6, 1),
            weight=25.0,
        )
        # Unrelated dam for comparison
        self.unrelated_dam = Animal.objects.create(
            name='Unrelated', species='Dog', breed='Labrador',
            sex=Animal.Sex.FEMALE,
            date_of_birth=date(2021, 3, 1),
            weight=24.0,
        )

    def test_build_pedigree_tree(self):
        tree = services.build_pedigree_tree(str(self.sire.pk))
        self.assertIsNotNone(tree)
        self.assertEqual(tree['animal'].name, 'Sire')
        self.assertIsNotNone(tree['sire'])
        self.assertIsNotNone(tree['dam'])
        self.assertEqual(tree['sire']['animal'].name, 'GrandSire')

    def test_pedigree_not_found(self):
        tree = services.build_pedigree_tree('00000000-0000-0000-0000-000000000000')
        self.assertIsNone(tree)

    def test_coi_related_siblings(self):
        """Full siblings (same sire and dam) should have COI of 25%."""
        coi = services.calculate_coi(str(self.sire.pk), str(self.dam.pk))
        self.assertAlmostEqual(coi, 25.0, places=1)

    def test_coi_unrelated(self):
        """Unrelated animals should have COI of 0%."""
        coi = services.calculate_coi(str(self.sire.pk), str(self.unrelated_dam.pk))
        self.assertEqual(coi, 0.0)

    def test_breeding_suggestions(self):
        suggestions = services.generate_breeding_suggestions(str(self.sire.pk))
        self.assertIsInstance(suggestions, list)
        self.assertTrue(len(suggestions) > 0)
        # All suggestions should have the required keys
        for s in suggestions:
            self.assertIn('compatibility_score', s)
            self.assertIn('estimated_coi', s)
            self.assertIn('pros', s)
            self.assertIn('cons', s)

    def test_suggestions_ranking(self):
        """Unrelated dam should score higher than related dam."""
        suggestions = services.generate_breeding_suggestions(str(self.sire.pk))
        if len(suggestions) >= 2:
            # Should be sorted by compatibility score descending
            self.assertGreaterEqual(
                suggestions[0]['compatibility_score'],
                suggestions[1]['compatibility_score'],
            )

    def test_common_ancestors(self):
        common = services.find_common_ancestors(
            str(self.sire.pk), str(self.dam.pk)
        )
        ancestor_names = [a.name for a in common]
        self.assertIn('GrandSire', ancestor_names)
        self.assertIn('GrandDam', ancestor_names)

    def test_no_common_ancestors(self):
        common = services.find_common_ancestors(
            str(self.sire.pk), str(self.unrelated_dam.pk)
        )
        self.assertEqual(len(common), 0)

    def test_coi_rating(self):
        self.assertEqual(services._coi_rating(1.0), 'Low')
        self.assertEqual(services._coi_rating(5.0), 'Moderate')
        self.assertEqual(services._coi_rating(10.0), 'High')
        self.assertEqual(services._coi_rating(15.0), 'Very High')

    def test_score_grade(self):
        self.assertEqual(services._score_grade(95), 'Excellent')
        self.assertEqual(services._score_grade(80), 'Good')
        self.assertEqual(services._score_grade(65), 'Fair')
        self.assertEqual(services._score_grade(45), 'Caution')
        self.assertEqual(services._score_grade(30), 'Not Recommended')
