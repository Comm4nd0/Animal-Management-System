"""
Generate realistic demo data for the Pedigree Animal Management System.

Usage:
    python manage.py seed_demo          # Seed ~2,500 animals
    python manage.py seed_demo --clear  # Delete existing demo data first

Creates a dedicated ``demo_user`` account (Enterprise tier, OWNER role)
with thousands of animals spanning multiple species, multi-generation pedigree
trees, health records, breeding records, litters, contacts, and custom fields.
"""

import random
import uuid
from datetime import date, timedelta
from decimal import Decimal

from django.contrib.auth.models import User
from django.core.management.base import BaseCommand

from accounts.models import (
    ServiceTier,
    UserProfile,
    UserRole,
)
from animals.models import (
    Animal,
    BreedingRecord,
    Contact,
    CustomFieldDefinition,
    FinancialRecord,
    HealthRecord,
    Litter,
    ShowResult,
    WeightRecord,
)


# ── Name pools ───────────────────────────────────────────────────────────────

FARM_PREFIXES = [
    'Greenfield', 'Silverdale', 'Oakridge', 'Windmere', 'Briarwood',
    'Rosewood', 'Thornhill', 'Meadowbrook', 'Stonewall', 'Irongate',
    'Highclere', 'Ashford', 'Willowbank', 'Foxhaven', 'Kingswood',
    'Riverside', 'Elmhurst', 'Pinecrest', 'Sunnyvale', 'Lakeside',
]

HORSE_NAMES = [
    'Eclipse', 'Storm', 'Thunder', 'Willow', 'Duchess', 'Apollo',
    'Shadow', 'Blaze', 'Misty', 'Spirit', 'Noble', 'Majesty',
    'Starlight', 'Valor', 'Harmony', 'Phoenix', 'Destiny', 'Legend',
    'Grace', 'Titan', 'Aurora', 'Ember', 'Jasper', 'Luna',
    'Crimson', 'Ivory', 'Sapphire', 'Atlas', 'Cleo', 'Orion',
    'Velvet', 'Ranger', 'Breeze', 'Sterling', 'Clover', 'Falcon',
    'Ruby', 'Knight', 'Pearl', 'Rex', 'Ginger', 'Onyx',
    'Whisper', 'Prince', 'Belle', 'Zeus', 'Rosie', 'Duke',
]

CATTLE_NAMES = [
    'Lady', 'Boss', 'Belle', 'King', 'Daisy', 'Bruno',
    'Maggie', 'Tank', 'Molly', 'Chief', 'Lucy', 'Duke',
    'Annie', 'Angus', 'Hazel', 'Brutus', 'Penny', 'Tex',
    'Ruby', 'Hank', 'Sadie', 'Buck', 'Ivy', 'Rusty',
]

SHEEP_GOAT_NAMES = [
    'Woolly', 'Clover', 'Cotton', 'Pepper', 'Biscuit', 'Patches',
    'Nutmeg', 'Cocoa', 'Bramble', 'Fern', 'Sage', 'Basil',
    'Thyme', 'Maple', 'Holly', 'Daisy', 'Poppy', 'Jasmine',
    'Olive', 'Pearl', 'Ivy', 'Hazel', 'Rosie', 'Ginger',
]

PIG_NAMES = [
    'Hamlet', 'Truffle', 'Bacon', 'Oink', 'Wilbur', 'Porky',
    'Piglet', 'Waddles', 'Snout', 'Grunter', 'Rosie', 'Babe',
    'Muddy', 'Curly', 'Porkchop', 'Squealer', 'Petunia', 'Daisy',
    'Buttercup', 'Penelope', 'Trotter', 'Sausage', 'Peppa', 'George',
]

VET_NAMES = [
    'Dr. Sarah Mitchell', 'Dr. James Fletcher', 'Dr. Emma Watson',
    'Dr. Michael Chen', 'Dr. Lisa Kumar', 'Dr. David Thompson',
    'Dr. Rachel Green', 'Dr. Mark Stevens',
]

CLINIC_NAMES = [
    'Valley Veterinary Clinic', 'Countryside Animal Hospital',
    'Green Pastures Vet Centre', 'Rural Animal Care',
    'Stockman\'s Veterinary Services', 'Farm & Equine Vets',
]

SHOW_NAMES = [
    'Royal Agricultural Show', 'County Fair Championship',
    'National Breed Show', 'Spring Classic', 'Autumn Invitational',
    'Regional Livestock Expo', 'Grand Champion Series',
    'Heritage Breed Festival', 'Premier Stock Show',
]

# ── Species / breed configuration ─────────────────────────────────────────────

SPECIES_CONFIG = [
    {
        'species': 'Horse',
        'breeds': ['Thoroughbred', 'Arabian', 'Quarter Horse', 'Warmblood', 'Friesian'],
        'total': 800,
        'name_pool': HORSE_NAMES,
        'use_prefix': True,
        'weight_range': (400, 650),
        'height_range': (145, 175),
        'gestation_days': 340,
    },
    {
        'species': 'Cattle',
        'breeds': ['Angus', 'Hereford', 'Charolais', 'Holstein', 'Simmental'],
        'total': 600,
        'name_pool': CATTLE_NAMES,
        'use_prefix': True,
        'weight_range': (350, 900),
        'height_range': (120, 155),
        'gestation_days': 283,
    },
    {
        'species': 'Sheep',
        'breeds': ['Suffolk', 'Merino', 'Dorper', 'Texel'],
        'total': 400,
        'name_pool': SHEEP_GOAT_NAMES,
        'use_prefix': False,
        'weight_range': (40, 120),
        'height_range': (55, 80),
        'gestation_days': 150,
    },
    {
        'species': 'Goat',
        'breeds': ['Boer', 'Nubian', 'Alpine', 'Saanen'],
        'total': 300,
        'name_pool': SHEEP_GOAT_NAMES,
        'use_prefix': False,
        'weight_range': (30, 100),
        'height_range': (50, 85),
        'gestation_days': 150,
    },
    {
        'species': 'Pig',
        'breeds': ['Large White', 'Landrace', 'Duroc', 'Berkshire'],
        'total': 200,
        'name_pool': PIG_NAMES,
        'use_prefix': False,
        'weight_range': (60, 300),
        'height_range': (55, 90),
        'gestation_days': 114,
    },
    {
        'species': 'Alpaca',
        'breeds': ['Huacaya', 'Suri'],
        'total': 100,
        'name_pool': SHEEP_GOAT_NAMES,
        'use_prefix': True,
        'weight_range': (50, 85),
        'height_range': (80, 100),
        'gestation_days': 345,
    },
]

COLORS = {
    'Horse': ['Bay', 'Chestnut', 'Black', 'Grey', 'Palomino', 'Dun', 'Roan', 'Buckskin'],
    'Cattle': ['Black', 'Red', 'White', 'Brindle', 'Roan', 'Brown', 'Dun', 'Spotted'],
    'Sheep': ['White', 'Black', 'Brown', 'Grey', 'Spotted', 'Cream'],
    'Goat': ['White', 'Black', 'Brown', 'Red', 'Spotted', 'Tan', 'Grey'],
    'Pig': ['White', 'Black', 'Red', 'Spotted', 'Sandy', 'Belted'],
    'Alpaca': ['White', 'Fawn', 'Brown', 'Black', 'Grey', 'Rose Grey'],
}


class Command(BaseCommand):
    help = 'Generate realistic demo data with ~2,500 animals and related records.'

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.rng = random.Random(42)  # deterministic for reproducibility
        self.today = date.today()
        self.name_counters = {}
        self.all_animals = []
        self.profile = None
        self.contacts = []

    def add_arguments(self, parser):
        parser.add_argument(
            '--clear',
            action='store_true',
            help='Delete existing demo data before seeding.',
        )

    def handle(self, *args, **options):
        if options['clear']:
            self._clear_demo_data()

        self.profile = self._get_or_create_demo_account()
        self.contacts = self._create_contacts()
        self._create_custom_fields()

        for config in SPECIES_CONFIG:
            self._generate_species(config)

        self._create_breeding_records()

        total = Animal.objects.filter(account=self.profile).count()
        self.stdout.write(self.style.SUCCESS(
            f'\n  Done! {total} animals across {len(SPECIES_CONFIG)} species.\n'
            f'    Demo login: demo@pedigreemanager.app\n'
        ))

    # ── Account setup ─────────────────────────────────────────────────────

    def _get_or_create_demo_account(self):
        user, created = User.objects.get_or_create(
            username='demo_user',
            defaults={
                'email': 'demo@pedigreemanager.app',
                'first_name': 'Demo',
                'last_name': 'User',
                'is_active': True,
            },
        )
        if created:
            user.set_unusable_password()
            user.save()

        profile, p_created = UserProfile.objects.get_or_create(
            user=user,
            defaults={
                'service_tier': ServiceTier.ENTERPRISE,
                'role': UserRole.OWNER,
                'farm_name': 'Pedigree Manager Demo Farm',
                'registered_species': '',
                'registered_breed': '',
            },
        )
        if not p_created:
            profile.service_tier = ServiceTier.ENTERPRISE
            profile.role = UserRole.OWNER
            profile.save(update_fields=['service_tier', 'role'])

        self.stdout.write(f'  Demo account: {user.username} ({"created" if created else "exists"})')
        return profile

    def _clear_demo_data(self):
        try:
            user = User.objects.get(username='demo_user')
            profile = user.profile
            # Deleting animals cascades to health, weight, show, financial, documents
            Animal.objects.filter(account=profile).delete()
            BreedingRecord.objects.filter(
                sire__account=profile,
            ).delete()
            Litter.objects.filter(
                sire__account=profile,
            ).delete()
            Contact.objects.filter(account=profile).delete()
            CustomFieldDefinition.objects.filter(owner=profile).delete()
            self.stdout.write('  Cleared existing demo data.')
        except (User.DoesNotExist, UserProfile.DoesNotExist):
            pass

    # ── Contacts ──────────────────────────────────────────────────────────

    def _create_contacts(self):
        contacts = []
        farm_names = [
            'Green Valley Stud', 'Highland Farm', 'Blue River Ranch',
            'Sunset Acres', 'Pinewood Estate', 'Mountain View Farm',
            'Golden Meadows', 'Cedar Creek Stud', 'Rolling Hills Farm',
            'Stonebridge Farm', 'Willow Creek Ranch', 'Eagle Ridge Farm',
            'Spring Water Stud', 'Ironbark Station', 'Maplewood Farm',
        ]
        for i, farm in enumerate(farm_names):
            contact = Contact.objects.create(
                name=f'Contact {i + 1}',
                farm_name=farm,
                email=f'contact{i + 1}@{farm.lower().replace(" ", "")}.com',
                phone=f'+61 4{self.rng.randint(10, 99)} {self.rng.randint(100, 999)} {self.rng.randint(100, 999)}',
                address=f'{self.rng.randint(1, 999)} {farm} Road, Rural District',
                prefix=farm.split()[0][:2].upper(),
                account=self.profile,
            )
            contacts.append(contact)
        self.stdout.write(f'  Created {len(contacts)} contacts.')
        return contacts

    # ── Custom fields ─────────────────────────────────────────────────────

    def _create_custom_fields(self):
        fields = [
            ('Ear Tag Number', 'ear_tag', CustomFieldDefinition.FieldType.TEXT, '', 1),
            ('Horn Status', 'horn_status', CustomFieldDefinition.FieldType.DROPDOWN,
             'Polled,Horned,Scurred,Dehorned', 2),
            ('Fleece Weight (kg)', 'fleece_weight', CustomFieldDefinition.FieldType.NUMBER, '', 3),
            ('Temperament Score', 'temperament', CustomFieldDefinition.FieldType.NUMBER, '', 4),
            ('Registration Date', 'reg_date', CustomFieldDefinition.FieldType.DATE, '', 5),
        ]
        for name, key, ftype, options, order in fields:
            CustomFieldDefinition.objects.get_or_create(
                field_key=key,
                owner=self.profile,
                defaults={
                    'name': name,
                    'field_type': ftype,
                    'required': False,
                    'options': options,
                    'display_order': order,
                },
            )
        self.stdout.write('  Created 5 custom field definitions.')

    # ── Animal generation ─────────────────────────────────────────────────

    def _generate_species(self, config):
        species = config['species']
        breeds = config['breeds']
        total = config['total']
        per_breed = total // len(breeds)

        species_animals = []
        for breed in breeds:
            breed_animals = self._generate_breed(species, breed, per_breed, config)
            species_animals.extend(breed_animals)

        self.all_animals.extend(species_animals)
        self.stdout.write(f'  {species}: {len(species_animals)} animals across {len(breeds)} breeds.')

    def _generate_breed(self, species, breed, count, config):
        """Generate animals for a single breed with multi-generation pedigrees."""
        gen_split = [0.35, 0.28, 0.22, 0.15]  # gen 0, 1, 2, 3
        generations = []

        for gen_idx, ratio in enumerate(gen_split):
            gen_count = max(2, int(count * ratio))
            # Ensure roughly even sex split
            males = gen_count // 2
            gen_animals = []

            for i in range(gen_count):
                sex = Animal.Sex.MALE if i < males else Animal.Sex.FEMALE
                sire = None
                dam = None

                if gen_idx > 0 and generations:
                    prev = generations[gen_idx - 1]
                    prev_males = [a for a in prev if a.sex == Animal.Sex.MALE]
                    prev_females = [a for a in prev if a.sex == Animal.Sex.FEMALE]
                    if prev_males and prev_females:
                        sire = self.rng.choice(prev_males)
                        dam = self.rng.choice(prev_females)

                dob = self._gen_dob(gen_idx)
                name = self._gen_name(species, breed, sex, config)
                color = self.rng.choice(COLORS.get(species, ['Unknown']))

                weight_min, weight_max = config['weight_range']
                height_min, height_max = config['height_range']

                animal = Animal(
                    id=uuid.uuid4(),
                    name=name,
                    species=species,
                    breed=breed,
                    sex=sex,
                    date_of_birth=dob,
                    color=color,
                    sire=sire,
                    dam=dam,
                    breeder=self.rng.choice(self.contacts) if self.rng.random() < 0.6 else None,
                    current_owner=self.rng.choice(self.contacts) if self.rng.random() < 0.4 else None,
                    weight=Decimal(str(round(self.rng.uniform(weight_min, weight_max), 1))),
                    height=Decimal(str(round(self.rng.uniform(height_min, height_max), 1))),
                    status=Animal.Status.ALIVE if self.rng.random() < 0.85 else Animal.Status.DECEASED,
                    registration_number=self._gen_reg_number(species, breed),
                    microchip_number=self._gen_microchip() if self.rng.random() < 0.7 else '',
                    genetic_traits=self._gen_traits(),
                    custom_fields=self._gen_custom_fields(species),
                    notes='' if self.rng.random() < 0.7 else f'Demo animal for {breed} breed.',
                    account=self.profile,
                )
                gen_animals.append(animal)

            Animal.objects.bulk_create(gen_animals, ignore_conflicts=True)
            generations.append(gen_animals)

        all_breed_animals = [a for gen in generations for a in gen]

        # Generate related records
        for animal in all_breed_animals:
            self._generate_health_records(animal)
            if self.rng.random() < 0.5:
                self._generate_weight_records(animal, config)
            if self.rng.random() < 0.2:
                self._generate_show_results(animal)
            if self.rng.random() < 0.3:
                self._generate_financial_records(animal)

        return all_breed_animals

    def _gen_dob(self, generation):
        """Generate a date of birth based on generation."""
        years_ago_ranges = [
            (8, 15),   # Gen 0: founders
            (5, 8),    # Gen 1
            (2, 5),    # Gen 2
            (0, 2),    # Gen 3: youngest
        ]
        min_y, max_y = years_ago_ranges[generation]
        days_ago = self.rng.randint(min_y * 365, max_y * 365)
        return self.today - timedelta(days=days_ago)

    def _gen_name(self, species, breed, sex, config):
        key = f'{species}_{breed}'
        self.name_counters.setdefault(key, 0)
        self.name_counters[key] += 1
        seq = self.name_counters[key]

        name_pool = config['name_pool']
        base_name = name_pool[(seq - 1) % len(name_pool)]

        if config.get('use_prefix'):
            prefix = FARM_PREFIXES[(seq - 1) % len(FARM_PREFIXES)]
            # Add a numeric suffix to avoid duplicates across generations
            suffix = '' if seq <= len(name_pool) else f' {seq // len(name_pool) + 1}'
            return f'{prefix} {base_name}{suffix}'

        breed_code = breed[:3].upper()
        sex_code = 'M' if sex == Animal.Sex.MALE else 'F'
        year = self.today.year - self.rng.randint(0, 5)
        return f'{breed_code}-{sex_code}-{year}-{seq:03d}'

    def _gen_reg_number(self, species, breed):
        breed_code = breed[:4].upper()
        num = self.rng.randint(10000, 99999)
        return f'{breed_code}-{num}'

    def _gen_microchip(self):
        return ''.join([str(self.rng.randint(0, 9)) for _ in range(15)])

    def _gen_traits(self):
        traits = {}
        if self.rng.random() < 0.4:
            traits['coat_pattern'] = self.rng.choice(['solid', 'spotted', 'roan', 'brindle'])
        if self.rng.random() < 0.3:
            traits['temperament'] = self.rng.choice(['calm', 'spirited', 'docile', 'alert'])
        return traits

    def _gen_custom_fields(self, species):
        fields = {}
        if self.rng.random() < 0.5:
            fields['ear_tag'] = f'ET-{self.rng.randint(1000, 9999)}'
        if species in ('Cattle', 'Goat'):
            fields['horn_status'] = self.rng.choice(['Polled', 'Horned', 'Scurred', 'Dehorned'])
        if species == 'Sheep' and self.rng.random() < 0.4:
            fields['fleece_weight'] = str(round(self.rng.uniform(2.0, 8.0), 1))
        if self.rng.random() < 0.3:
            fields['temperament'] = str(self.rng.randint(1, 10))
        return fields

    # ── Related records ───────────────────────────────────────────────────

    def _generate_health_records(self, animal):
        record_count = self.rng.randint(2, 4)
        types = [
            HealthRecord.RecordType.VACCINATION,
            HealthRecord.RecordType.EXAMINATION,
            HealthRecord.RecordType.DEWORMING,
        ]
        titles_map = {
            HealthRecord.RecordType.VACCINATION: [
                'Annual Vaccination', 'Clostridial Vaccine', 'Tetanus Booster',
                'Respiratory Vaccine', 'Reproductive Vaccine',
            ],
            HealthRecord.RecordType.EXAMINATION: [
                'Annual Health Check', 'Pre-breeding Examination',
                'Wellness Exam', 'Dental Check',
            ],
            HealthRecord.RecordType.DEWORMING: [
                'Routine Deworming', 'Strategic Drench',
                'Faecal Egg Count + Drench',
            ],
        }
        records = []
        for _ in range(record_count):
            rec_type = self.rng.choice(types)
            days_ago = self.rng.randint(30, 365 * 3)
            rec_date = self.today - timedelta(days=days_ago)

            records.append(HealthRecord(
                animal=animal,
                type=rec_type,
                title=self.rng.choice(titles_map.get(rec_type, ['Health Check'])),
                description=f'Routine {rec_type.label.lower()} for {animal.name}.',
                date=rec_date,
                next_due_date=rec_date + timedelta(days=self.rng.choice([90, 180, 365])),
                veterinarian=self.rng.choice(VET_NAMES),
                clinic=self.rng.choice(CLINIC_NAMES),
                cost=Decimal(str(round(self.rng.uniform(50, 350), 2))),
            ))
        HealthRecord.objects.bulk_create(records, ignore_conflicts=True)

    def _generate_weight_records(self, animal, config):
        if not animal.date_of_birth:
            return
        record_count = self.rng.randint(3, 6)
        weight_min, weight_max = config['weight_range']
        records = []
        for _ in range(record_count):
            age_days = (self.today - animal.date_of_birth).days
            if age_days <= 30:
                continue
            record_day = self.rng.randint(30, age_days)
            rec_date = animal.date_of_birth + timedelta(days=record_day)
            age_fraction = min(1.0, record_day / (365 * 3))
            weight = weight_min * 0.1 + (weight_max - weight_min * 0.1) * age_fraction
            weight += self.rng.uniform(-weight * 0.1, weight * 0.1)

            records.append(WeightRecord(
                animal=animal,
                date=rec_date,
                weight=Decimal(str(round(max(1, weight), 1))),
                notes='',
            ))
        if records:
            WeightRecord.objects.bulk_create(records, ignore_conflicts=True)

    def _generate_show_results(self, animal):
        count = self.rng.randint(1, 3)
        placements = [
            ShowResult.Placement.FIRST,
            ShowResult.Placement.SECOND,
            ShowResult.Placement.THIRD,
            ShowResult.Placement.FOURTH,
            ShowResult.Placement.FIFTH,
            ShowResult.Placement.RESERVE,
            ShowResult.Placement.CHAMPION,
            ShowResult.Placement.PARTICIPATED,
        ]
        records = []
        for _ in range(count):
            days_ago = self.rng.randint(30, 365 * 3)
            records.append(ShowResult(
                animal=animal,
                show_name=self.rng.choice(SHOW_NAMES),
                show_date=self.today - timedelta(days=days_ago),
                class_name=f'{animal.breed} {self.rng.choice(["Open", "Junior", "Senior", "Yearling"])}',
                placement=self.rng.choice(placements),
                judge=f'Judge {self.rng.choice(["Smith", "Jones", "Brown", "Taylor", "Wilson"])}',
                notes='',
            ))
        ShowResult.objects.bulk_create(records, ignore_conflicts=True)

    def _generate_financial_records(self, animal):
        count = self.rng.randint(1, 3)
        categories = [
            FinancialRecord.Category.VETERINARY,
            FinancialRecord.Category.FEED,
            FinancialRecord.Category.REGISTRATION,
            FinancialRecord.Category.INSURANCE,
        ]
        descriptions = {
            FinancialRecord.Category.VETERINARY: 'Vet consultation and treatment',
            FinancialRecord.Category.FEED: 'Monthly feed supply',
            FinancialRecord.Category.REGISTRATION: 'Breed registration fee',
            FinancialRecord.Category.INSURANCE: 'Annual insurance premium',
        }
        records = []
        for _ in range(count):
            days_ago = self.rng.randint(30, 365 * 2)
            category = self.rng.choice(categories)
            records.append(FinancialRecord(
                animal=animal,
                date=self.today - timedelta(days=days_ago),
                transaction_type=FinancialRecord.TransactionType.EXPENSE,
                category=category,
                amount=Decimal(str(round(self.rng.uniform(25, 1500), 2))),
                description=descriptions.get(category, 'General expense'),
            ))
        FinancialRecord.objects.bulk_create(records, ignore_conflicts=True)

    # ── Breeding records & litters ────────────────────────────────────────

    def _create_breeding_records(self):
        breeding_count = 0
        litter_count = 0

        for config in SPECIES_CONFIG:
            species = config['species']
            species_animals = [a for a in self.all_animals if a.species == species]
            males = [a for a in species_animals if a.sex == Animal.Sex.MALE]
            females = [a for a in species_animals if a.sex == Animal.Sex.FEMALE]

            if len(males) < 2 or len(females) < 2:
                continue

            num_breedings = max(3, len(species_animals) // 30)
            statuses = [
                BreedingRecord.Status.COMPLETED,
                BreedingRecord.Status.COMPLETED,
                BreedingRecord.Status.COMPLETED,
                BreedingRecord.Status.PREGNANT,
                BreedingRecord.Status.CONFIRMED,
                BreedingRecord.Status.PLANNED,
            ]

            for _ in range(num_breedings):
                sire = self.rng.choice(males)
                dam = self.rng.choice(females)
                if sire == dam:
                    continue

                status = self.rng.choice(statuses)
                days_ago = self.rng.randint(30, 365 * 2)
                breeding_date = self.today - timedelta(days=days_ago)
                expected_due = breeding_date + timedelta(days=config['gestation_days'])

                litter = None
                if status == BreedingRecord.Status.COMPLETED:
                    total_offspring = self.rng.randint(
                        1, 8 if species in ('Pig', 'Sheep', 'Goat') else 3
                    )
                    male_count = self.rng.randint(0, total_offspring)
                    female_count = total_offspring - male_count

                    litter = Litter.objects.create(
                        sire=sire,
                        dam=dam,
                        date_of_birth=expected_due,
                        total_puppies=total_offspring,
                        male_count=male_count,
                        female_count=female_count,
                        stillborn=self.rng.randint(0, 1) if self.rng.random() < 0.1 else 0,
                        registration_number=f'LIT-{self.rng.randint(10000, 99999)}',
                        notes='',
                    )
                    litter_count += 1

                BreedingRecord.objects.create(
                    sire=sire,
                    dam=dam,
                    breeding_date=breeding_date,
                    expected_due_date=expected_due,
                    status=status,
                    litter=litter,
                    method=self.rng.choice(['Natural', 'Artificial Insemination']),
                    veterinarian=self.rng.choice(VET_NAMES) if self.rng.random() < 0.5 else '',
                    notes=f'Demo breeding record for {species}.',
                )
                breeding_count += 1

        self.stdout.write(f'  Created {breeding_count} breeding records and {litter_count} litters.')
