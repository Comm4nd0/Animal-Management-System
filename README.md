# Pedigree Manager

A cross-platform pedigree animal management system with intelligent breeding suggestions, lineage tracking, and health record management.

## Architecture

```
├── lib/                    # Flutter app (iOS, Android, Web)
│   ├── models/             # Data models
│   ├── services/           # Business logic & API client
│   ├── screens/            # UI screens
│   ├── widgets/            # Reusable widgets
│   └── utils/              # Theme, constants
├── backend/                # Django REST API
│   ├── animals/            # Animal CRUD, health, breeding, litters
│   ├── genetics/           # COI calculation, breeding suggestions
│   ├── pedigree_api/       # Django project settings
│   └── config/             # AWS deployment config
├── test/                   # Flutter tests
└── config/                 # AWS RDS setup guide
```

## Features

### Animal Management
- Register animals with full pedigree details (species, breed, sex, DOB, color, markings)
- Track registration numbers, microchip IDs, and DNA profiles
- Link sire/dam relationships to build complete family trees
- Search and filter by species, breed, name, or registration number
- Photo management and custom fields per animal

### Pedigree Tree
- Visual multi-generation pedigree tree display (up to 6 generations)
- Navigate through ancestors by tapping nodes
- Color-coded by sex (blue = male, red = female)
- Shows breed, registration, and color info at each node

### Genetic Breeding Suggestions
- **Wright's Coefficient of Inbreeding (COI)** calculation using path-based analysis
- Automated compatibility scoring considering:
  - Inbreeding coefficient (primary factor)
  - Breed compatibility
  - Age suitability for both sire and dam
  - Size differential risk assessment
  - Genetic diversity (different breeder bonus)
- Ranked suggestions with detailed pros, cons, and genetic risk warnings
- COI ratings: Low (<3%), Moderate (3-6.25%), High (6.25-12.5%), Very High (>12.5%)

### Health Records
- Track vaccinations, examinations, surgeries, medications, lab tests, deworming, and dental
- Automatic overdue and due-soon alerts
- Veterinarian and cost tracking
- Document attachments

### Breeding & Litter Management
- Record breeding events with status tracking (Planned → Confirmed → Pregnant → Whelping → Completed)
- Gestation progress tracking with expected due dates
- Litter recording with male/female/stillborn counts
- Link offspring to their birth litter

## Tech Stack

### Frontend
- **Flutter** (Dart) - Single codebase for iOS, Android, and Web
- **Provider** for state management
- **sqflite** for local offline storage
- **fl_chart** for data visualization

### Backend
- **Django 5** with **Django REST Framework**
- **PostgreSQL** via AWS RDS
- **django-filter** for querystring filtering
- **django-cors-headers** for cross-origin requests
- **WhiteNoise** for static file serving
- **Gunicorn** for production WSGI serving

### Infrastructure
- **AWS RDS** (PostgreSQL) for the database
- **AWS S3** (optional) for media file storage
- **Docker** for containerized deployment
- Deployable to AWS ECS/Fargate, Elastic Beanstalk, or EC2

## Getting Started

### Backend Setup

```bash
cd backend

# Create virtual environment
python -m venv venv
source venv/bin/activate  # or venv\Scripts\activate on Windows

# Install dependencies
pip install -r requirements.txt

# Configure environment
cp .env.example .env
# Edit .env with your database credentials

# For local development with SQLite:
# Set USE_SQLITE=True in .env

# Run migrations
python manage.py migrate

# Create admin user
python manage.py createsuperuser

# Run development server
python manage.py runserver
```

### Backend with Docker

```bash
cd backend
docker-compose up
# API available at http://localhost:8000/api/v1/
# Admin panel at http://localhost:8000/admin/
```

### Flutter App Setup

```bash
# Install Flutter dependencies
flutter pub get

# Run on connected device/emulator
flutter run

# Run for web
flutter run -d chrome

# Build for production
flutter build apk          # Android
flutter build ios           # iOS
flutter build web           # Web

# Point to your API server
flutter run --dart-define=API_BASE_URL=http://your-server:8000/api/v1
```

### Running Tests

```bash
# Django backend tests
cd backend
python manage.py test

# Flutter tests
flutter test
```

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET/POST | `/api/v1/animals/` | List/create animals |
| GET/PUT/DELETE | `/api/v1/animals/{id}/` | Retrieve/update/delete animal |
| GET | `/api/v1/animals/stats/` | Aggregate statistics |
| GET | `/api/v1/animals/{id}/offspring/` | Get offspring |
| GET/POST | `/api/v1/health-records/` | List/create health records |
| GET | `/api/v1/health-records/upcoming/` | Due within 30 days |
| GET | `/api/v1/health-records/overdue/` | Overdue records |
| GET/POST | `/api/v1/breeding-records/` | List/create breeding records |
| GET | `/api/v1/breeding-records/active/` | Active breedings |
| GET/POST | `/api/v1/litters/` | List/create litters |
| GET | `/api/v1/genetics/{id}/pedigree/` | Pedigree tree |
| GET | `/api/v1/genetics/coi/?sire={id}&dam={id}` | Calculate COI |
| GET | `/api/v1/genetics/{id}/suggestions/` | Breeding suggestions |
| GET | `/api/v1/genetics/common-ancestors/?animal1={id}&animal2={id}` | Common ancestors |

## AWS RDS Configuration

See [config/aws-rds-setup.md](config/aws-rds-setup.md) for detailed AWS RDS setup instructions including:
- RDS instance creation (Console and CLI)
- Security group configuration
- Environment variable setup
- Deployment options (ECS, Elastic Beanstalk, EC2)
- Production checklist

## License

MIT
