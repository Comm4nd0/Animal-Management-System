import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/animal_provider.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';

class AnimalListScreen extends StatefulWidget {
  const AnimalListScreen({super.key});

  @override
  State<AnimalListScreen> createState() => _AnimalListScreenState();
}

class _AnimalListScreenState extends State<AnimalListScreen> {
  final _searchController = TextEditingController();
  bool _showFilters = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Animals'),
        actions: [
          IconButton(
            icon: Icon(_showFilters ? Icons.filter_list_off : Icons.filter_list),
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
        ],
      ),
      body: Consumer<AnimalProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              _buildSearchBar(provider),
              if (_showFilters) _buildFilters(provider),
              Expanded(
                child: provider.animals.isEmpty
                    ? _buildEmptyState(context)
                    : _buildAnimalList(provider),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/animal/add'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSearchBar(AnimalProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by name, breed, or registration...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    provider.setSearchQuery('');
                  },
                )
              : null,
        ),
        onChanged: provider.setSearchQuery,
      ),
    );
  }

  Widget _buildFilters(AnimalProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: provider.selectedSpeciesFilter,
                  decoration: const InputDecoration(
                    labelText: 'Species',
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Species')),
                    ...provider.availableSpecies.map((s) =>
                        DropdownMenuItem(value: s, child: Text(s))),
                  ],
                  onChanged: provider.setSpeciesFilter,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: provider.selectedBreedFilter,
                  decoration: const InputDecoration(
                    labelText: 'Breed',
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Breeds')),
                    ...provider.availableBreeds.map((b) =>
                        DropdownMenuItem(value: b, child: Text(b))),
                  ],
                  onChanged: provider.setBreedFilter,
                ),
              ),
            ],
          ),
          // Custom field filters
          ...provider.customFieldDefinitions.map((field) {
            if (field.fieldType == CustomFieldType.dropdown) {
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: DropdownButtonFormField<String>(
                  value: provider.customFieldFilters[field.fieldKey],
                  decoration: InputDecoration(
                    labelText: field.name,
                    isDense: true,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text('All ${field.name}'),
                    ),
                    ...field.options.map(
                      (o) => DropdownMenuItem(value: o, child: Text(o)),
                    ),
                  ],
                  onChanged: (v) =>
                      provider.setCustomFieldFilter(field.fieldKey, v),
                ),
              );
            } else if (field.fieldType == CustomFieldType.boolean) {
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: DropdownButtonFormField<String>(
                  value: provider.customFieldFilters[field.fieldKey],
                  decoration: InputDecoration(
                    labelText: field.name,
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Any')),
                    DropdownMenuItem(value: 'true', child: Text('Yes')),
                    DropdownMenuItem(value: 'false', child: Text('No')),
                  ],
                  onChanged: (v) =>
                      provider.setCustomFieldFilter(field.fieldKey, v),
                ),
              );
            }
            // Text and number fields: show a text filter input
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextField(
                decoration: InputDecoration(
                  labelText: 'Filter by ${field.name}',
                  isDense: true,
                  suffixIcon: provider.customFieldFilters[field.fieldKey] !=
                          null
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => provider.setCustomFieldFilter(
                              field.fieldKey, null),
                        )
                      : null,
                ),
                onChanged: (v) => provider.setCustomFieldFilter(
                  field.fieldKey,
                  v.isEmpty ? null : v,
                ),
              ),
            );
          }),
          if (provider.hasActiveFilters)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: TextButton(
                onPressed: provider.clearFilters,
                child: const Text('Clear Filters'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pets, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No animals found',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first animal to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade500,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimalList(AnimalProvider provider) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: provider.animals.length,
      itemBuilder: (context, index) {
        final animal = provider.animals[index];
        return _AnimalCard(animal: animal);
      },
    );
  }
}

class _AnimalCard extends StatelessWidget {
  final Animal animal;

  const _AnimalCard({required this.animal});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => Navigator.pushNamed(
          context,
          '/animal/detail',
          arguments: animal.id,
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: animal.sex == Sex.male
                    ? AppTheme.maleColor.withValues(alpha: 0.15)
                    : animal.sex == Sex.female
                        ? AppTheme.femaleColor.withValues(alpha: 0.15)
                        : Colors.grey.shade200,
                child: animal.imagePath != null
                    ? ClipOval(
                        child: Image.asset(
                          animal.imagePath!,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildSexIcon(),
                        ),
                      )
                    : _buildSexIcon(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      animal.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${animal.species} - ${animal.breed}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (animal.ageDisplay != null)
                          _InfoChip(label: animal.ageDisplay!),
                        if (animal.registrationNumber != null) ...[
                          const SizedBox(width: 4),
                          _InfoChip(label: animal.registrationNumber!),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSexIcon() {
    return Icon(
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
      size: 28,
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;

  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
      ),
    );
  }
}
