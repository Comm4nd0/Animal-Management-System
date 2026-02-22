from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('animals', '0003_animal_registration_date'),
    ]

    operations = [
        # Add entity_type to CustomFieldDefinition (default=0 means 'Animal')
        migrations.AddField(
            model_name='customfielddefinition',
            name='entity_type',
            field=models.IntegerField(
                choices=[(0, 'Animal'), (1, 'Contact'), (2, 'Pedigree')],
                default=0,
                help_text='Which record type this field applies to',
            ),
        ),
        # Update unique_together to include entity_type
        migrations.AlterUniqueTogether(
            name='customfielddefinition',
            unique_together={('owner', 'field_key', 'entity_type')},
        ),
        # Add custom_fields JSONField to Contact
        migrations.AddField(
            model_name='contact',
            name='custom_fields',
            field=models.JSONField(blank=True, default=dict),
        ),
    ]
