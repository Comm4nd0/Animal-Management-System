import uuid
import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        ('accounts', '0001_initial'),
    ]

    operations = [
        migrations.CreateModel(
            name='Contact',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('name', models.CharField(max_length=200)),
                ('farm_name', models.CharField(blank=True, default='', max_length=200)),
                ('email', models.EmailField(blank=True, default='', max_length=254)),
                ('phone', models.CharField(blank=True, default='', max_length=50)),
                ('address', models.TextField(blank=True, default='')),
                ('prefix', models.CharField(blank=True, default='', help_text='Breeding prefix / affix', max_length=100)),
                ('notes', models.TextField(blank=True, default='')),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('account', models.ForeignKey(help_text='The user account this contact belongs to', on_delete=django.db.models.deletion.CASCADE, related_name='contacts', to='accounts.userprofile')),
            ],
            options={
                'ordering': ['name'],
            },
        ),
        migrations.CreateModel(
            name='Animal',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('name', models.CharField(max_length=200)),
                ('species', models.CharField(db_index=True, max_length=100)),
                ('breed', models.CharField(db_index=True, max_length=200)),
                ('sex', models.IntegerField(choices=[(0, 'Male'), (1, 'Female'), (2, 'Unknown')])),
                ('date_of_birth', models.DateField(blank=True, null=True)),
                ('date_of_death', models.DateField(blank=True, null=True)),
                ('color', models.CharField(blank=True, default='', max_length=100)),
                ('markings', models.CharField(blank=True, default='', max_length=200)),
                ('registration_number', models.CharField(blank=True, db_index=True, default='', max_length=100)),
                ('microchip_number', models.CharField(blank=True, db_index=True, default='', max_length=100)),
                ('dna_profile_id', models.CharField(blank=True, default='', max_length=100)),
                ('image', models.ImageField(blank=True, null=True, upload_to='animals/')),
                ('weight', models.DecimalField(blank=True, decimal_places=2, help_text='Weight in kg', max_digits=8, null=True)),
                ('height', models.DecimalField(blank=True, decimal_places=2, help_text='Height in cm', max_digits=8, null=True)),
                ('status', models.IntegerField(choices=[(0, 'Alive'), (1, 'Deceased'), (2, 'Sold'), (3, 'Transferred')], default=0)),
                ('genetic_traits', models.JSONField(blank=True, default=dict)),
                ('custom_fields', models.JSONField(blank=True, default=dict)),
                ('notes', models.TextField(blank=True, default='')),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('sire', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='sire_offspring', to='animals.animal')),
                ('dam', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='dam_offspring', to='animals.animal')),
                ('account', models.ForeignKey(blank=True, help_text='The user account that owns this animal record', null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='animals', to='accounts.userprofile')),
                ('current_owner', models.ForeignKey(blank=True, help_text='The current owner / keeper of this animal', null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='owned_animals', to='animals.contact')),
                ('breeder', models.ForeignKey(blank=True, help_text='The breeder of this animal', null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='bred_animals', to='animals.contact')),
            ],
            options={
                'ordering': ['name'],
            },
        ),
        migrations.AddIndex(
            model_name='animal',
            index=models.Index(fields=['species', 'breed'], name='animals_ani_species_idx'),
        ),
        migrations.AddIndex(
            model_name='animal',
            index=models.Index(fields=['sire'], name='animals_ani_sire_id_idx'),
        ),
        migrations.AddIndex(
            model_name='animal',
            index=models.Index(fields=['dam'], name='animals_ani_dam_id_idx'),
        ),
        migrations.CreateModel(
            name='AnimalImage',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('image', models.ImageField(upload_to='animal_images/')),
                ('caption', models.CharField(blank=True, default='', max_length=200)),
                ('is_profile', models.BooleanField(default=False)),
                ('uploaded_at', models.DateTimeField(auto_now_add=True)),
                ('animal', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='images', to='animals.animal')),
            ],
            options={
                'ordering': ['-is_profile', '-uploaded_at'],
            },
        ),
        migrations.CreateModel(
            name='HealthRecord',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('type', models.IntegerField(choices=[(0, 'Vaccination'), (1, 'Examination'), (2, 'Surgery'), (3, 'Medication'), (4, 'Lab Test'), (5, 'Deworming'), (6, 'Dental'), (7, 'Other')])),
                ('title', models.CharField(max_length=200)),
                ('description', models.TextField(blank=True, default='')),
                ('date', models.DateField()),
                ('next_due_date', models.DateField(blank=True, null=True)),
                ('veterinarian', models.CharField(blank=True, default='', max_length=200)),
                ('clinic', models.CharField(blank=True, default='', max_length=200)),
                ('cost', models.DecimalField(blank=True, decimal_places=2, max_digits=10, null=True)),
                ('document', models.FileField(blank=True, null=True, upload_to='health_documents/')),
                ('details', models.JSONField(blank=True, default=dict)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('animal', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='health_records', to='animals.animal')),
            ],
            options={
                'ordering': ['-date'],
            },
        ),
        migrations.AddIndex(
            model_name='healthrecord',
            index=models.Index(fields=['animal', '-date'], name='animals_hea_animal__idx'),
        ),
        migrations.CreateModel(
            name='Litter',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('date_of_birth', models.DateField()),
                ('total_puppies', models.PositiveIntegerField(default=0)),
                ('male_count', models.PositiveIntegerField(default=0)),
                ('female_count', models.PositiveIntegerField(default=0)),
                ('stillborn', models.PositiveIntegerField(default=0)),
                ('registration_number', models.CharField(blank=True, default='', max_length=100)),
                ('notes', models.TextField(blank=True, default='')),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('sire', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='litters_as_sire', to='animals.animal')),
                ('dam', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='litters_as_dam', to='animals.animal')),
                ('offspring', models.ManyToManyField(blank=True, related_name='birth_litter', to='animals.animal')),
            ],
            options={
                'ordering': ['-date_of_birth'],
            },
        ),
        migrations.CreateModel(
            name='BreedingRecord',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('breeding_date', models.DateField()),
                ('expected_due_date', models.DateField(blank=True, null=True)),
                ('actual_due_date', models.DateField(blank=True, null=True)),
                ('status', models.IntegerField(choices=[(0, 'Planned'), (1, 'Confirmed'), (2, 'Pregnant'), (3, 'Whelping'), (4, 'Completed'), (5, 'Unsuccessful'), (6, 'Cancelled')], default=0)),
                ('method', models.CharField(blank=True, default='', help_text='e.g., Natural, Artificial Insemination', max_length=50)),
                ('veterinarian', models.CharField(blank=True, default='', max_length=200)),
                ('notes', models.TextField(blank=True, default='')),
                ('sire_coi_contribution', models.FloatField(blank=True, null=True)),
                ('dam_coi_contribution', models.FloatField(blank=True, null=True)),
                ('expected_offspring_coi', models.FloatField(blank=True, null=True)),
                ('genetic_test_results', models.JSONField(blank=True, default=list)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('sire', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='breeding_as_sire', to='animals.animal')),
                ('dam', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='breeding_as_dam', to='animals.animal')),
                ('litter', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='breeding_record', to='animals.litter')),
            ],
            options={
                'ordering': ['-breeding_date'],
            },
        ),
        migrations.AddIndex(
            model_name='breedingrecord',
            index=models.Index(fields=['sire', 'dam'], name='animals_bre_sire_id_idx'),
        ),
        migrations.AddIndex(
            model_name='breedingrecord',
            index=models.Index(fields=['status'], name='animals_bre_status_idx'),
        ),
        migrations.CreateModel(
            name='CustomFieldDefinition',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('name', models.CharField(help_text='Display name for the custom field', max_length=100)),
                ('field_key', models.CharField(help_text='Storage key used in the custom_fields JSON (auto-generated from name)', max_length=100)),
                ('field_type', models.IntegerField(choices=[(0, 'Text'), (1, 'Number'), (2, 'Date'), (3, 'Yes/No'), (4, 'Dropdown')], default=0)),
                ('required', models.BooleanField(default=False)),
                ('options', models.JSONField(blank=True, default=list, help_text='List of options for dropdown fields')),
                ('display_order', models.IntegerField(default=0)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('owner', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='custom_field_definitions', to='accounts.userprofile')),
            ],
            options={
                'ordering': ['display_order', 'name'],
                'unique_together': {('owner', 'field_key')},
            },
        ),
    ]
