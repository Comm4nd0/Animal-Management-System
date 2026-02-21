from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('animals', '0002_weightrecord_showresult_financialrecord_documentattachment'),
    ]

    operations = [
        migrations.AddField(
            model_name='animal',
            name='registration_date',
            field=models.DateField(blank=True, null=True),
        ),
    ]
