import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/animal_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/demo_write_guard.dart';

class FinancialRecordsTab extends StatelessWidget {
  final String animalId;
  const FinancialRecordsTab({super.key, required this.animalId});

  @override
  Widget build(BuildContext context) {
    return Consumer<AnimalProvider>(
      builder: (context, provider, _) {
        final records = provider.financialRecords;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (!await guardWriteAction(context)) return;
                  _showAddDialog(context, provider);
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Transaction'),
              ),
            ),
            if (records.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildSummaryCard(records),
              ),
            Expanded(
              child: records.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.account_balance_wallet,
                              size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text('No financial records yet'),
                          const SizedBox(height: 4),
                          Text(
                            'Track expenses and income',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: records.length,
                      itemBuilder: (context, index) {
                        final record = records[index];
                        final isIncome =
                            record.transactionType == TransactionType.income;
                        return Card(
                          child: ListTile(
                            leading: Icon(
                              isIncome
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward,
                              color: isIncome ? Colors.green : Colors.red,
                            ),
                            title: Text(
                              '${isIncome ? '+' : '-'}\$${record.amount.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: isIncome ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              [
                                record.category.label,
                                DateFormat.yMMMd().format(record.date),
                                if (record.description.isNotEmpty)
                                  record.description,
                              ].join(' - '),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              onPressed: () async {
                                if (!await guardWriteAction(context)) return;
                                _confirmDelete(context, provider, record);
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard(List<FinancialRecord> records) {
    final totalIncome = records
        .where((r) => r.transactionType == TransactionType.income)
        .fold<double>(0, (sum, r) => sum + r.amount);
    final totalExpense = records
        .where((r) => r.transactionType == TransactionType.expense)
        .fold<double>(0, (sum, r) => sum + r.amount);
    final net = totalIncome - totalExpense;

    return Card(
      color: AppTheme.primaryColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _StatCol('Income', '\$${totalIncome.toStringAsFixed(0)}',
                Colors.green),
            _StatCol('Expenses', '\$${totalExpense.toStringAsFixed(0)}',
                Colors.red),
            _StatCol(
              'Net',
              '${net >= 0 ? '+' : ''}\$${net.toStringAsFixed(0)}',
              net >= 0 ? Colors.green : Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context, AnimalProvider provider) {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();
    TransactionType type = TransactionType.expense;
    FinancialCategory category = FinancialCategory.other;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Transaction'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<TransactionType>(
                  segments: const [
                    ButtonSegment(
                        value: TransactionType.expense,
                        label: Text('Expense')),
                    ButtonSegment(
                        value: TransactionType.income,
                        label: Text('Income')),
                  ],
                  selected: {type},
                  onSelectionChanged: (v) =>
                      setDialogState(() => type = v.first),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Amount *',
                    prefixText: '\$',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<FinancialCategory>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: FinancialCategory.values
                      .map((c) => DropdownMenuItem(
                          value: c, child: Text(c.label)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => category = v);
                    }
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                      'Date: ${DateFormat.yMMMd().format(selectedDate)}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                ),
                TextField(
                  controller: descCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountCtrl.text);
                if (amount == null || amount <= 0) return;
                provider.addFinancialRecord(FinancialRecord(
                  animalId: animalId,
                  date: selectedDate,
                  transactionType: type,
                  category: category,
                  amount: amount,
                  description: descCtrl.text,
                ));
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, AnimalProvider provider, FinancialRecord record) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Record'),
        content: const Text('Delete this financial record?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              provider.deleteFinancialRecord(record.id, animalId);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _StatCol extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCol(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }
}
