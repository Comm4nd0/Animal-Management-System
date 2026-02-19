from django.db import migrations, models


def seed_defaults(apps, schema_editor):
    """Pre-populate TierConfiguration with the hard-coded defaults."""
    TierConfiguration = apps.get_model('accounts', 'TierConfiguration')
    defaults = [
        (0, 'Starter', 'Up to 10 animals, single breed, 1 user', 10, 1, False),
        (1, 'Standard', 'Up to 50 animals, single breed, 3 users', 50, 3, False),
        (2, 'Professional', 'Up to 200 animals, single breed, 10 users', 200, 10, False),
        (3, 'Enterprise', 'Unlimited animals, multiple species and breeds, unlimited users', None, None, True),
    ]
    for tier, label, description, max_animals, max_users, allows_multi_breed in defaults:
        TierConfiguration.objects.create(
            tier=tier,
            label=label,
            description=description,
            max_animals=max_animals,
            max_users=max_users,
            allows_multi_breed=allows_multi_breed,
        )


def remove_defaults(apps, schema_editor):
    TierConfiguration = apps.get_model('accounts', 'TierConfiguration')
    TierConfiguration.objects.all().delete()


class Migration(migrations.Migration):

    dependencies = [
        ('accounts', '0001_initial'),
    ]

    operations = [
        migrations.CreateModel(
            name='TierConfiguration',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('tier', models.IntegerField(choices=[(0, 'Starter'), (1, 'Standard'), (2, 'Professional'), (3, 'Enterprise')], help_text='The service tier this configuration applies to.', unique=True)),
                ('label', models.CharField(help_text='Display name for this tier (e.g. "Starter").', max_length=100)),
                ('description', models.CharField(blank=True, default='', help_text='Short description shown to users.', max_length=500)),
                ('max_animals', models.IntegerField(blank=True, help_text='Maximum number of animals. Leave blank for unlimited.', null=True)),
                ('max_users', models.IntegerField(blank=True, help_text='Maximum number of team members. Leave blank for unlimited.', null=True)),
                ('allows_multi_breed', models.BooleanField(default=False, help_text='Whether this tier allows multiple species/breeds.')),
            ],
            options={
                'verbose_name': 'Tier Configuration',
                'verbose_name_plural': 'Tier Configurations',
                'ordering': ['tier'],
            },
        ),
        migrations.RunPython(seed_defaults, remove_defaults),
    ]
