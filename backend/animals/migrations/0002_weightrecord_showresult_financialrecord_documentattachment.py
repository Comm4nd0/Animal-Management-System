import uuid
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('animals', '0001_initial'),
    ]

    operations = [
        migrations.CreateModel(
            name='WeightRecord',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('date', models.DateField()),
                ('weight', models.DecimalField(blank=True, decimal_places=2, help_text='Weight in kg', max_digits=8, null=True)),
                ('height', models.DecimalField(blank=True, decimal_places=2, help_text='Height in cm', max_digits=8, null=True)),
                ('notes', models.TextField(blank=True, default='')),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('animal', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='weight_records', to='animals.animal')),
            ],
            options={
                'ordering': ['-date'],
            },
        ),
        migrations.CreateModel(
            name='ShowResult',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('show_name', models.CharField(max_length=300)),
                ('show_date', models.DateField()),
                ('class_name', models.CharField(blank=True, default='', help_text='e.g. Open, Yearling, Junior Handler', max_length=200)),
                ('placement', models.IntegerField(choices=[(1, '1st Place'), (2, '2nd Place'), (3, '3rd Place'), (4, '4th Place'), (5, '5th Place'), (10, 'Reserve'), (20, 'Champion'), (30, 'Best in Show'), (99, 'Participated')], default=99)),
                ('judge', models.CharField(blank=True, default='', max_length=200)),
                ('points', models.DecimalField(blank=True, decimal_places=2, help_text='Points or score awarded', max_digits=8, null=True)),
                ('notes', models.TextField(blank=True, default='')),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('animal', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='show_results', to='animals.animal')),
            ],
            options={
                'ordering': ['-show_date'],
            },
        ),
        migrations.CreateModel(
            name='FinancialRecord',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('date', models.DateField()),
                ('transaction_type', models.IntegerField(choices=[(0, 'Expense'), (1, 'Income')])),
                ('category', models.IntegerField(choices=[(0, 'Feed'), (1, 'Veterinary'), (2, 'Registration'), (3, 'Insurance'), (4, 'Transport'), (5, 'Equipment'), (6, 'Stud Fee'), (7, 'Sale'), (8, 'Prize Money'), (99, 'Other')], default=99)),
                ('amount', models.DecimalField(decimal_places=2, max_digits=12)),
                ('description', models.CharField(blank=True, default='', max_length=500)),
                ('receipt', models.FileField(blank=True, null=True, upload_to='receipts/')),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('animal', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='financial_records', to='animals.animal')),
            ],
            options={
                'ordering': ['-date'],
            },
        ),
        migrations.CreateModel(
            name='DocumentAttachment',
            fields=[
                ('id', models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ('title', models.CharField(max_length=300)),
                ('document_type', models.IntegerField(choices=[(0, 'Pedigree Certificate'), (1, 'Registration Paper'), (2, 'DNA Test Result'), (3, 'Health Certificate'), (4, 'Insurance'), (5, 'Contract'), (6, 'Photo ID'), (99, 'Other')], default=99)),
                ('file', models.FileField(upload_to='animal_documents/')),
                ('notes', models.TextField(blank=True, default='')),
                ('uploaded_at', models.DateTimeField(auto_now_add=True)),
                ('animal', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='documents', to='animals.animal')),
            ],
            options={
                'ordering': ['-uploaded_at'],
            },
        ),
        migrations.AddIndex(
            model_name='weightrecord',
            index=models.Index(fields=['animal', '-date'], name='animals_wei_animal__636740_idx'),
        ),
        migrations.AddIndex(
            model_name='showresult',
            index=models.Index(fields=['animal', '-show_date'], name='animals_sho_animal__a1b2c3_idx'),
        ),
        migrations.AddIndex(
            model_name='financialrecord',
            index=models.Index(fields=['animal', '-date'], name='animals_fin_animal__d4e5f6_idx'),
        ),
    ]
