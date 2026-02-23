import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/animal_provider.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';
import '../../widgets/demo_write_guard.dart';

/// Identifiers for every column available in the animals table.
enum AnimalColumn {
  name,
  species,
  breed,
  sex,
  dob,
  status,
  color,
  regNumber,
  microchip,
  added,
}

/// Metadata for each column: display label, optional API sort key.
class _ColumnDef {
  final String label;
  final String? sortField;
  const _ColumnDef(this.label, {this.sortField});
}

const Map<AnimalColumn, _ColumnDef> _columnDefs = {
  AnimalColumn.name: _ColumnDef('Name', sortField: 'name'),
  AnimalColumn.species: _ColumnDef('Species'),
  AnimalColumn.breed: _ColumnDef('Breed', sortField: 'breed'),
  AnimalColumn.sex: _ColumnDef('Sex'),
  AnimalColumn.dob: _ColumnDef('DOB', sortField: 'date_of_birth'),
  AnimalColumn.status: _ColumnDef('Status'),
  AnimalColumn.color: _ColumnDef('Color'),
  AnimalColumn.regNumber: _ColumnDef('Reg #'),
  AnimalColumn.microchip: _ColumnDef('Microchip'),
  AnimalColumn.added: _ColumnDef('Added', sortField: 'created_at'),
};

/// Default visible columns (Name is always shown).
const List<AnimalColumn> _defaultVisibleColumns = [
  AnimalColumn.name,
  AnimalColumn.breed,
  AnimalColumn.sex,
  AnimalColumn.dob,
  AnimalColumn.status,
  AnimalColumn.regNumber,
  AnimalColumn.added,
];

class AnimalListScreen extends StatefulWidget {
  const AnimalListScreen({super.key});

  @override
  State<AnimalListScreen> createState() => _AnimalListScreenState();
}

class _AnimalListScreenState extends State<AnimalListScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  bool _showFilters = false;
  late List<AnimalColumn> _visibleColumns;

  @override
  void initState() {
    super.initState();
    _visibleColumns = List.from(_defaultVisibleColumns);
    // Trigger initial data load after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AnimalProvider>();
      _searchController.text = provider.tableSearch;
      provider.fetchTablePage();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      context.read<AnimalProvider>().setTableSearch(query);
    });
  }

  void _showColumnPicker() {
    showDialog(
      context: context,
      builder: (ctx) {
        // Work on a temporary copy so Cancel discards changes.
        var tempColumns = List<AnimalColumn>.from(_visibleColumns);
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Choose Columns'),
              content: SizedBox(
                width: 300,
                child: ReorderableListView(
                  shrinkWrap: true,
                  buildDefaultDragHandles: false,
                  onReorder: (oldIndex, newIndex) {
                    setDialogState(() {
                      if (newIndex > oldIndex) newIndex--;
                      final item = tempColumns.removeAt(oldIndex);
                      tempColumns.insert(newIndex, item);
                    });
                  },
                  children: [
                    for (final col in AnimalColumn.values)
                      CheckboxListTile(
                        key: ValueKey(col),
                        value: tempColumns.contains(col),
                        // Name column cannot be removed.
                        enabled: col != AnimalColumn.name,
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(_columnDefs[col]!.label),
                            ),
                            if (tempColumns.contains(col))
                              ReorderableDragStartListener(
                                index: AnimalColumn.values.indexOf(col),
                                child: const Icon(Icons.drag_handle,
                                    size: 20, color: Colors.grey),
                              ),
                          ],
                        ),
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: col == AnimalColumn.name
                            ? null
                            : (checked) {
                                setDialogState(() {
                                  if (checked == true) {
                                    tempColumns.add(col);
                                  } else {
                                    tempColumns.remove(col);
                                  }
                                });
                              },
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _visibleColumns = tempColumns
                          .where((c) => tempColumns.contains(c))
                          .toList();
                      // Ensure ordering follows tempColumns' checked items.
                      _visibleColumns = [
                        for (final c in tempColumns)
                          if (tempColumns.contains(c)) c,
                      ];
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Animals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.view_column),
            tooltip: 'Choose columns',
            onPressed: _showColumnPicker,
          ),
          IconButton(
            icon: Icon(
                _showFilters ? Icons.filter_list_off : Icons.filter_list),
            tooltip: 'Toggle filters',
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
              _buildTableInfo(provider),
              Expanded(child: _buildDataTable(provider)),
              _buildPaginationControls(provider),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (!await guardWriteAction(context)) return;
          Navigator.pushNamed(context, '/animals/new');
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSearchBar(AnimalProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
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
                    provider.setTableSearch('');
                  },
                )
              : null,
        ),
        onChanged: _onSearchChanged,
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
                  value: provider.tableSpeciesFilter,
                  decoration: const InputDecoration(
                    labelText: 'Species',
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('All Species')),
                    ...provider.availableSpecies
                        .map((s) => DropdownMenuItem(value: s, child: Text(s))),
                  ],
                  onChanged: (v) => provider.setTableSpeciesFilter(v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: provider.tableBreedFilter,
                  decoration: const InputDecoration(
                    labelText: 'Breed',
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('All Breeds')),
                    ...provider.availableBreeds
                        .map((b) => DropdownMenuItem(value: b, child: Text(b))),
                  ],
                  onChanged: (v) => provider.setTableBreedFilter(v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: provider.tableSexFilter,
                  decoration: const InputDecoration(
                    labelText: 'Sex',
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All')),
                    DropdownMenuItem(value: 0, child: Text('Male')),
                    DropdownMenuItem(value: 1, child: Text('Female')),
                    DropdownMenuItem(value: 2, child: Text('Unknown')),
                  ],
                  onChanged: (v) => provider.setTableSexFilter(v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: provider.tableStatusFilter,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All')),
                    DropdownMenuItem(value: 0, child: Text('Alive')),
                    DropdownMenuItem(value: 1, child: Text('Deceased')),
                  ],
                  onChanged: (v) => provider.setTableStatusFilter(v),
                ),
              ),
            ],
          ),
          if (provider.hasActiveTableFilters)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: TextButton.icon(
                onPressed: () {
                  _searchController.clear();
                  provider.clearTableFilters();
                },
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('Clear Filters'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTableInfo(AnimalProvider provider) {
    final start = provider.tableTotalCount == 0
        ? 0
        : (provider.tablePage - 1) * provider.tablePageSize + 1;
    final end = (start + provider.tableAnimals.length - 1)
        .clamp(0, provider.tableTotalCount);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          if (provider.tableLoading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          if (provider.tableLoading) const SizedBox(width: 8),
          Text(
            provider.tableTotalCount == 0
                ? 'No animals found'
                : 'Showing $start\u2013$end of ${provider.tableTotalCount}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const Spacer(),
          // Page size selector
          DropdownButton<int>(
            value: provider.tablePageSize,
            underline: const SizedBox(),
            isDense: true,
            style: Theme.of(context).textTheme.bodySmall,
            items: const [
              DropdownMenuItem(value: 10, child: Text('10 per page')),
              DropdownMenuItem(value: 25, child: Text('25 per page')),
              DropdownMenuItem(value: 50, child: Text('50 per page')),
              DropdownMenuItem(value: 100, child: Text('100 per page')),
            ],
            onChanged: (v) {
              if (v != null) provider.setTablePageSize(v);
            },
          ),
        ],
      ),
    );
  }

  // ─── DataTable (dynamic columns) ──────────────────────────────────

  Widget _buildDataTable(AnimalProvider provider) {
    if (provider.tableError != null && provider.tableAnimals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text('Failed to load animals',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(provider.tableError!,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => provider.fetchTablePage(),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (!provider.tableLoading && provider.tableAnimals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pets, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              provider.hasActiveTableFilters
                  ? 'No animals match your filters'
                  : 'No animals found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              provider.hasActiveTableFilters
                  ? 'Try adjusting your search or filters'
                  : 'Add your first animal to get started',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade500,
                  ),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: SingleChildScrollView(
                  child: DataTable(
                    sortColumnIndex: _activeSortIndex(provider.tableSortColumn),
                    sortAscending: provider.tableSortAscending,
                    showCheckboxColumn: false,
                    headingRowColor: WidgetStateProperty.all(
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    dataRowMinHeight: 52,
                    dataRowMaxHeight: 60,
                    columnSpacing: 16,
                    columns: _buildColumns(provider),
                    rows: provider.tableAnimals.map((animal) {
                      return DataRow(
                        onSelectChanged: (_) {
                          Navigator.pushNamed(
                              context, '/animals/${animal.id}');
                        },
                        cells: _buildCells(animal),
                      );
                    }).toList(),
                  ),
                ),
              ),
            );
          },
        ),
        // Loading overlay
        if (provider.tableLoading && provider.tableAnimals.isNotEmpty)
          Positioned.fill(
            child: Container(
              color: Colors.white.withValues(alpha: 0.5),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
      ],
    );
  }

  List<DataColumn> _buildColumns(AnimalProvider provider) {
    return _visibleColumns.map((col) {
      final def = _columnDefs[col]!;
      return DataColumn(
        label: Text(def.label,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        onSort: def.sortField != null
            ? (_, asc) => provider.setTableSort(def.sortField!, asc)
            : null,
      );
    }).toList();
  }

  List<DataCell> _buildCells(Animal animal) {
    return _visibleColumns.map((col) {
      return switch (col) {
        AnimalColumn.name => DataCell(_buildNameCell(animal)),
        AnimalColumn.species => DataCell(Text(animal.species)),
        AnimalColumn.breed => DataCell(Text(animal.breed)),
        AnimalColumn.sex => DataCell(_buildSexChip(animal.sex)),
        AnimalColumn.dob => DataCell(Text(animal.ageDisplay ?? '\u2014')),
        AnimalColumn.status => DataCell(_buildStatusChip(animal.status)),
        AnimalColumn.color => DataCell(Text(animal.color ?? '\u2014')),
        AnimalColumn.regNumber =>
          DataCell(Text(animal.registrationNumber ?? '\u2014')),
        AnimalColumn.microchip =>
          DataCell(Text(animal.microchipNumber ?? '\u2014')),
        AnimalColumn.added => DataCell(Text(_formatDate(animal.createdAt))),
      };
    }).toList();
  }

  /// Returns the index within visible columns that matches the current sort,
  /// or null if the sort column isn't visible.
  int? _activeSortIndex(String sortColumn) {
    for (var i = 0; i < _visibleColumns.length; i++) {
      if (_columnDefs[_visibleColumns[i]]!.sortField == sortColumn) {
        return i;
      }
    }
    return null;
  }

  // ─── Cell widgets ────────────────────────────────────────────────

  Widget _buildNameCell(Animal animal) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: animal.sex == Sex.male
              ? AppTheme.maleColor.withValues(alpha: 0.15)
              : animal.sex == Sex.female
                  ? AppTheme.femaleColor.withValues(alpha: 0.15)
                  : Colors.grey.shade200,
          child: Icon(
            animal.sex == Sex.male
                ? Icons.male
                : animal.sex == Sex.female
                    ? Icons.female
                    : Icons.pets,
            size: 18,
            color: animal.sex == Sex.male
                ? AppTheme.maleColor
                : animal.sex == Sex.female
                    ? AppTheme.femaleColor
                    : Colors.grey,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            animal.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildSexChip(Sex sex) {
    final label = switch (sex) {
      Sex.male => 'Male',
      Sex.female => 'Female',
      Sex.unknown => 'Unknown',
    };
    final color = switch (sex) {
      Sex.male => AppTheme.maleColor,
      Sex.female => AppTheme.femaleColor,
      Sex.unknown => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, color: color, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildStatusChip(AnimalStatus status) {
    final label = switch (status) {
      AnimalStatus.alive => 'Alive',
      AnimalStatus.deceased => 'Deceased',
      AnimalStatus.sold => 'Sold',
      AnimalStatus.transferred => 'Transferred',
    };
    final color = switch (status) {
      AnimalStatus.alive => Colors.green,
      AnimalStatus.deceased => Colors.grey,
      AnimalStatus.sold => Colors.orange,
      AnimalStatus.transferred => Colors.blue,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, color: color, fontWeight: FontWeight.w500)),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Widget _buildPaginationControls(AnimalProvider provider) {
    if (provider.tableTotalCount == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.first_page),
            onPressed:
                provider.tablePage > 1 ? () => provider.setTablePage(1) : null,
            tooltip: 'First page',
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: provider.tablePage > 1
                ? () => provider.setTablePage(provider.tablePage - 1)
                : null,
            tooltip: 'Previous page',
          ),
          const SizedBox(width: 8),
          Text(
            'Page ${provider.tablePage} of ${provider.tableTotalPages}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: provider.tablePage < provider.tableTotalPages
                ? () => provider.setTablePage(provider.tablePage + 1)
                : null,
            tooltip: 'Next page',
          ),
          IconButton(
            icon: const Icon(Icons.last_page),
            onPressed: provider.tablePage < provider.tableTotalPages
                ? () => provider.setTablePage(provider.tableTotalPages)
                : null,
            tooltip: 'Last page',
          ),
        ],
      ),
    );
  }
}
