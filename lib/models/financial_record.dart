import 'package:uuid/uuid.dart';

enum TransactionType {
  expense,
  income;

  String get label => switch (this) {
        expense => 'Expense',
        income => 'Income',
      };
}

enum FinancialCategory {
  feed,
  veterinary,
  registration,
  insurance,
  transport,
  equipment,
  studFee,
  sale,
  prizeMoney,
  other;

  String get label => switch (this) {
        feed => 'Feed',
        veterinary => 'Veterinary',
        registration => 'Registration',
        insurance => 'Insurance',
        transport => 'Transport',
        equipment => 'Equipment',
        studFee => 'Stud Fee',
        sale => 'Sale',
        prizeMoney => 'Prize Money',
        other => 'Other',
      };

  int get apiValue => switch (this) {
        feed => 0,
        veterinary => 1,
        registration => 2,
        insurance => 3,
        transport => 4,
        equipment => 5,
        studFee => 6,
        sale => 7,
        prizeMoney => 8,
        other => 99,
      };

  static FinancialCategory fromApiValue(int val) => switch (val) {
        0 => feed,
        1 => veterinary,
        2 => registration,
        3 => insurance,
        4 => transport,
        5 => equipment,
        6 => studFee,
        7 => sale,
        8 => prizeMoney,
        _ => other,
      };
}

class FinancialRecord {
  final String id;
  final String animalId;
  final DateTime date;
  final TransactionType transactionType;
  final FinancialCategory category;
  final double amount;
  final String description;
  final String? receiptPath;
  final DateTime createdAt;

  FinancialRecord({
    String? id,
    required this.animalId,
    required this.date,
    required this.transactionType,
    this.category = FinancialCategory.other,
    required this.amount,
    this.description = '',
    this.receiptPath,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'animalId': animalId,
        'date': date.millisecondsSinceEpoch,
        'transactionType': transactionType.index,
        'category': category.apiValue,
        'amount': amount,
        'description': description,
        'receiptPath': receiptPath,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory FinancialRecord.fromMap(Map<String, dynamic> map) => FinancialRecord(
        id: map['id'] as String,
        animalId: map['animalId'] as String,
        date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
        transactionType: TransactionType.values[map['transactionType'] as int? ?? 0],
        category: FinancialCategory.fromApiValue(map['category'] as int? ?? 99),
        amount: (map['amount'] as num).toDouble(),
        description: map['description'] as String? ?? '',
        receiptPath: map['receiptPath'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      );
}
