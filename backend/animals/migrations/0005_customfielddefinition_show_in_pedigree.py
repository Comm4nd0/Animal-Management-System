from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('animals', '0004_customfielddefinition_entity_type_contact_custom_fields'),
    ]

    operations = [
        # Add show_in_pedigree boolean to CustomFieldDefinition
        migrations.AddField(
            model_name='customfielddefinition',
            name='show_in_pedigree',
            field=models.BooleanField(
                default=False,
                help_text='Whether to display this field on pedigree tree cards (animal fields only)',
            ),
        ),
        # Update entity_type choices (remove Pedigree=2, keep Animal=0 and Contact=1)
        migrations.AlterField(
            model_name='customfielddefinition',
            name='entity_type',
            field=models.IntegerField(
                choices=[(0, 'Animal'), (1, 'Contact')],
                default=0,
                help_text='Which record type this field applies to',
            ),
        ),
        # Migrate any existing Pedigree (2) fields to Animal (0) with show_in_pedigree=True
        migrations.RunSQL(
            sql="UPDATE animals_customfielddefinition SET entity_type=0, show_in_pedigree=TRUE WHERE entity_type=2;",
            reverse_sql=migrations.RunSQL.noop,
        ),
    ]
