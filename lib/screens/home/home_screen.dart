import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/animal_provider.dart';
import '../../services/demo_service.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';
import '../../widgets/demo_write_guard.dart';
import 'dashboard_charts.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isExitingDemo = false;

  Future<void> _exitDemo() async {
    setState(() => _isExitingDemo = true);
    final provider = context.read<AnimalProvider>();
    final demoService = DemoService();
    await demoService.exitDemoMode(provider);
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      kIsWeb ? '/' : '/login',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AnimalProvider>();
    final isDemo = provider.isDemoMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pedigree Manager'),
        actions: [
          if (!isDemo)
            IconButton(
              icon: const Icon(Icons.person),
              tooltip: 'Account',
              onPressed: () {
                final profile =
                    context.read<AnimalProvider>().userProfile;
                if (profile != null) {
                  Navigator.pushNamed(context, '/account',
                      arguments: profile);
                } else {
                  Navigator.pushNamed(context, '/register');
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.pushNamed(context, '/animals'),
          ),
          // Support messaging — with unread badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.support_agent),
                tooltip: 'Support',
                onPressed: () => Navigator.pushNamed(context, '/support'),
              ),
              if (provider.supportUnreadCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${provider.supportUnreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (!isDemo)
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Settings',
              onPressed: () => Navigator.pushNamed(context, '/settings'),
            ),
          if (isDemo)
            TextButton.icon(
              onPressed: _isExitingDemo ? null : _exitDemo,
              icon: _isExitingDemo
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.exit_to_app, color: Colors.white),
              label: const Text('Exit Demo', style: TextStyle(color: Colors.white)),
            )
          else
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Log Out',
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  kIsWeb ? '/' : '/login',
                  (route) => false,
                );
              },
            ),
        ],
      ),
      body: Consumer<AnimalProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: provider.loadAll,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (isDemo) ...[
                  _buildDemoBanner(context),
                  const SizedBox(height: 12),
                ],
                _buildWelcomeCard(context),
                const SizedBox(height: 16),
                _buildStatsRow(context, provider.stats),
                const SizedBox(height: 16),
                if (provider.allAnimals.isNotEmpty) ...[
                  _buildChartsSection(context, provider),
                  const SizedBox(height: 16),
                ],
                _buildQuickActions(context),
                const SizedBox(height: 16),
                _buildRecentAnimals(context, provider),
                const SizedBox(height: 16),
                _buildActiveBreedings(context, provider),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (!await guardWriteAction(context)) return;
          if (!context.mounted) return;
          Navigator.pushNamed(context, '/animal/add');
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Animal'),
      ),
    );
  }

  Widget _buildDemoBanner(BuildContext context) {
    return Card(
      color: Colors.amber.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.amber.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.explore, color: Colors.amber.shade800),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Exploring Demo',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade900,
                    ),
                  ),
                  Text(
                    'Browse freely — create an account to add your own animals.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber.shade800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => Navigator.pushNamed(context, '/register'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text('Create Account'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(BuildContext context) {
    return Card(
      color: AppTheme.primaryColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pets, color: Colors.white, size: 32),
                const SizedBox(width: 12),
                Text(
                  'Pedigree Manager',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Pedigree management, lineage tracking, and breeding suggestions for farm animals and horses.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, Map<String, int> stats) {
    return Row(
      children: [
        _StatCard(
          label: 'Total',
          value: '${stats['total'] ?? 0}',
          icon: Icons.pets,
          color: AppTheme.primaryColor,
        ),
        const SizedBox(width: 8),
        _StatCard(
          label: 'Males',
          value: '${stats['males'] ?? 0}',
          icon: Icons.male,
          color: AppTheme.maleColor,
        ),
        const SizedBox(width: 8),
        _StatCard(
          label: 'Females',
          value: '${stats['females'] ?? 0}',
          icon: Icons.female,
          color: AppTheme.femaleColor,
        ),
        const SizedBox(width: 8),
        _StatCard(
          label: 'Breeds',
          value: '${stats['breeds'] ?? 0}',
          icon: Icons.category,
          color: AppTheme.accentColor,
        ),
      ],
    );
  }

  Widget _buildChartsSection(BuildContext context, AnimalProvider provider) {
    final animals = provider.allAnimals;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Insights',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        RegistrationTimelineChart(animals: animals),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: SexDistributionChart(animals: animals)),
            const SizedBox(width: 12),
            Expanded(child: StatusDistributionChart(animals: animals)),
          ],
        ),
        const SizedBox(height: 12),
        BreedDistributionChart(animals: animals),
        const SizedBox(height: 12),
        AgeDistributionChart(animals: animals),
        const SizedBox(height: 12),
        GeneticDiversityCard(animals: animals),
        const SizedBox(height: 12),
        _HealthRemindersSection(provider: provider),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.list_alt,
                label: 'All Animals',
                onTap: () => Navigator.pushNamed(context, '/animals'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionCard(
                icon: Icons.favorite,
                label: 'Breeding',
                onTap: () => Navigator.pushNamed(context, '/breeding'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionCard(
                icon: Icons.child_friendly,
                label: 'Litters',
                onTap: () => Navigator.pushNamed(context, '/litters'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.people,
                label: 'Contacts',
                onTap: () => Navigator.pushNamed(context, '/contacts'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionCard(
                icon: Icons.tune,
                label: 'Custom Fields',
                onTap: () => Navigator.pushNamed(context, '/custom-fields'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionCard(
                icon: Icons.calculate,
                label: 'COI Calc',
                onTap: () => Navigator.pushNamed(context, '/coi-calculator'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.male,
                label: 'Stud Matcher',
                onTap: () => Navigator.pushNamed(context, '/stud-matcher'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionCard(
                icon: Icons.health_and_safety,
                label: 'Data Audit',
                onTap: () => Navigator.pushNamed(context, '/data-audit'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionCard(
                icon: Icons.support_agent,
                label: 'Support',
                onTap: () => Navigator.pushNamed(context, '/support'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.upload_file,
                label: 'Import',
                onTap: () => Navigator.pushNamed(context, '/import'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionCard(
                icon: Icons.download,
                label: 'Export',
                onTap: () => Navigator.pushNamed(context, '/export'),
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentAnimals(BuildContext context, AnimalProvider provider) {
    final recent = provider.allAnimals.take(5).toList();
    if (recent.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.pets, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                'No animals yet',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap the + button to add your first animal',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade500,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Animals',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/animals'),
              child: const Text('View All'),
            ),
          ],
        ),
        ...recent.map((animal) => _AnimalListTile(animal: animal)),
      ],
    );
  }

  Widget _buildActiveBreedings(BuildContext context, AnimalProvider provider) {
    if (provider.breedingRecords.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Active Breedings',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        ...provider.breedingRecords.take(3).map((record) {
          final sire = provider.getAnimalById(record.sireId);
          final dam = provider.getAnimalById(record.damId);
          return Card(
            child: ListTile(
              leading: const Icon(Icons.favorite, color: AppTheme.femaleColor),
              title: Text('${sire?.name ?? "Unknown"} x ${dam?.name ?? "Unknown"}'),
              subtitle: Text(record.statusDisplay),
              trailing: record.gestationDaysRemaining != null
                  ? Chip(
                      label: Text('${record.gestationDaysRemaining}d left'),
                    )
                  : null,
            ),
          );
        }),
      ],
    );
  }
}

class _HealthRemindersSection extends StatefulWidget {
  final AnimalProvider provider;
  const _HealthRemindersSection({required this.provider});

  @override
  State<_HealthRemindersSection> createState() => _HealthRemindersSectionState();
}

class _HealthRemindersSectionState extends State<_HealthRemindersSection> {
  List<HealthRecord> _upcoming = [];
  List<HealthRecord> _overdue = [];

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    final all = await widget.provider.getUpcomingHealthReminders();
    if (!mounted) return;
    final now = DateTime.now();
    setState(() {
      _overdue = all.where((r) =>
          r.nextDueDate != null && r.nextDueDate!.isBefore(now)).toList();
      _upcoming = all.where((r) =>
          r.nextDueDate != null && !r.nextDueDate!.isBefore(now)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return HealthRemindersCard(
      upcoming: _upcoming,
      overdue: _overdue,
      animals: widget.provider.allAnimals,
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, size: 28, color: AppTheme.primaryColor),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimalListTile extends StatelessWidget {
  final Animal animal;

  const _AnimalListTile({required this.animal});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: animal.sex == Sex.male
              ? AppTheme.maleColor.withValues(alpha: 0.2)
              : animal.sex == Sex.female
                  ? AppTheme.femaleColor.withValues(alpha: 0.2)
                  : Colors.grey.shade200,
          child: Icon(
            animal.sex == Sex.male
                ? Icons.male
                : animal.sex == Sex.female
                    ? Icons.female
                    : Icons.pets,
            color: animal.sex == Sex.male
                ? AppTheme.maleColor
                : animal.sex == Sex.female
                    ? AppTheme.femaleColor
                    : Colors.grey,
          ),
        ),
        title: Text(animal.name),
        subtitle: Text('${animal.breed} ${animal.ageDisplay != null ? "- ${animal.ageDisplay}" : ""}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.pushNamed(
          context,
          '/animal/detail',
          arguments: animal.id,
        ),
      ),
    );
  }
}
