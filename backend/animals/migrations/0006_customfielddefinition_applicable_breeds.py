from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('animals', '0005_customfielddefinition_show_in_pedigree'),
    ]

    operations = [
        migrations.AddField(
            model_name='customfielddefinition',
            name='applicable_breeds',
            field=models.JSONField(
                blank=True,
                default=list,
                help_text='Breeds this field applies to. Empty list means all breeds.',
            ),
        ),
    ]
