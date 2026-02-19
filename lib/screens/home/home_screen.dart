import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/animal_provider.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pedigree Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.pushNamed(context, '/animals'),
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
                _buildWelcomeCard(context),
                const SizedBox(height: 16),
                _buildStatsRow(context, provider.stats),
                const SizedBox(height: 16),
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
        onPressed: () => Navigator.pushNamed(context, '/animal/add'),
        icon: const Icon(Icons.add),
        label: const Text('Add Animal'),
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
              'Track lineage, manage health records, and get intelligent breeding suggestions for your animals.',
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
