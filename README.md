# Pedigree Manager

A cross-platform pedigree animal management system for **farm animals and horses**, with tiered service plans, intelligent breeding suggestions, lineage tracking, and health record management.

## Architecture

```
├── lib/                    # Flutter app (iOS, Android, Web)
│   ├── models/             # Data models (Animal, UserProfile, etc.)
│   ├── services/           # Business logic, API client, state management
│   ├── screens/            # UI screens (home, animals, pedigree, breeding, account)
│   ├── widgets/            # Reusable widgets
│   └── utils/              # Theme, constants, service tier definitions
├── backend/                # Django REST API
│   ├── accounts/           # User registration, service tiers, tier enforcement
│   ├── animals/            # Animal CRUD, health records, breeding, litters
│   ├── genetics/           # COI calculation, breeding suggestions
│   └── pedigree_api/       # Django project settings & URLs
├── config/                 # AWS RDS setup guide
└── test/                   # Flutter tests
```

## Service Tiers

Each user account chooses a service tier that determines their animal capacity and breed restrictions.
**Only the Enterprise tier allows multiple species and breeds** - all other tiers are locked to a single breed.

| Tier | Max Animals | Multi-Breed | Description |
|------|-------------|-------------|-------------|
| **Starter** | 10 | No | For small holdings and hobby breeders |
| **Standard** | 50 | No | For established single-breed operations |
| **Professional** | 200 | No | For large single-breed farms and studs |
| **Enterprise** | Unlimited | **Yes** | For multi-species/breed operations |

### How breed locking works

1. New accounts on Starter/Standard/Professional start with no breed set
2. When the **first animal** is added, the account is automatically locked to that animal's species and breed
3. All subsequent animals must match the registered breed
4. Enterprise accounts can add any species and breed at any time
5. Downgrading from Enterprise requires all animals to be a single breed first

## Supported Species

The system is built for **farm animals and horses**:

| Species | Example Breeds |
|---------|----------------|
| Horse | Thoroughbred, Arabian, Quarter Horse, Warmblood, Clydesdale, Shire, ... |
| Cattle | Angus, Hereford, Charolais, Holstein, Jersey, Highland, Wagyu, ... |
| Sheep | Suffolk, Merino, Dorper, Texel, Romney, Hampshire, ... |
| Goat | Boer, Nubian, Alpine, Saanen, Toggenburg, Angora, ... |
| Pig | Large White, Landrace, Duroc, Berkshire, Tamworth, Saddleback, ... |
| Alpaca | (custom breed entry) |
| Donkey | (custom breed entry) |
| Poultry | (custom breed entry) |

## Features

### Account Management
- User registration with service tier selection
- Account dashboard showing usage (animals used / limit)
- Breed lock status display
- Tier upgrade flow with validation (can't downgrade if over limits)
- Farm/stud name and contact details

### Animal Management
- Register animals with full pedigree details (species, breed, sex, DOB, color, markings)
- Track registration numbers, microchip IDs, and DNA profiles
- Link sire/dam relationships to build complete family trees
- Search and filter by species, breed, name, or registration number
- Tier-enforced: species/breed must match account registration (non-Enterprise)
- Tier-enforced: animal count must not exceed tier limit

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
- Record breeding events with status tracking (Planned -> Confirmed -> Pregnant -> Whelping -> Completed)
- Gestation progress tracking with species-specific due dates
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

### Accounts
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/accounts/register/` | Register new account with tier selection |
| GET | `/api/v1/accounts/me/` | Get current user profile + tier info |
| GET | `/api/v1/accounts/tiers/` | List all available service tiers |
| POST | `/api/v1/accounts/change-tier/` | Change service tier (with validation) |

### Animals
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET/POST | `/api/v1/animals/` | List/create animals (tier-enforced) |
| GET/PUT/DELETE | `/api/v1/animals/{id}/` | Retrieve/update/delete animal |
| GET | `/api/v1/animals/stats/` | Stats + tier usage info |
| GET | `/api/v1/animals/{id}/offspring/` | Get offspring |

### Health Records
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET/POST | `/api/v1/health-records/` | List/create health records |
| GET | `/api/v1/health-records/upcoming/` | Due within 30 days |
| GET | `/api/v1/health-records/overdue/` | Overdue records |

### Breeding & Litters
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET/POST | `/api/v1/breeding-records/` | List/create breeding records |
| GET | `/api/v1/breeding-records/active/` | Active breedings |
| GET/POST | `/api/v1/litters/` | List/create litters |

### Genetics
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/genetics/{id}/pedigree/` | Pedigree tree |
| GET | `/api/v1/genetics/coi/?sire={id}&dam={id}` | Calculate COI |
| GET | `/api/v1/genetics/{id}/suggestions/` | Breeding suggestions |
| GET | `/api/v1/genetics/common-ancestors/?animal1={id}&animal2={id}` | Common ancestors |

## Tier Enforcement

The API enforces tier restrictions on animal creation:

```
POST /api/v1/animals/
```

**403 Forbidden** responses when:
- User has reached their tier's animal limit
- User tries to add an animal of a different breed (non-Enterprise)

Response includes:
```json
{
  "error": "Your Standard plan only allows a single breed. This account is registered for Horse - Thoroughbred. Upgrade to Enterprise for multi-species/breed support.",
  "tier": "Standard"
}
```

## AWS RDS Configuration

See [config/aws-rds-setup.md](config/aws-rds-setup.md) for detailed AWS RDS setup instructions.

## License

MIT
