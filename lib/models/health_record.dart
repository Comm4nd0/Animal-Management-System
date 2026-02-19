import 'package:uuid/uuid.dart';

enum HealthRecordType {
  vaccination,
  examination,
  surgery,
  medication,
  labTest,
  deworming,
  dental,
  other,
}

class HealthRecord {
  final String id;
  final String animalId;
  final HealthRecordType type;
  final String title;
  final String? description;
  final DateTime date;
  final DateTime? nextDueDate;
  final String? veterinarian;
  final String? clinic;
  final double? cost;
  final String? documentPath;
  final Map<String, dynamic> details;
  final DateTime createdAt;

  HealthRecord({
    String? id,
    required this.animalId,
    required this.type,
    required this.title,
    this.description,
    required this.date,
    this.nextDueDate,
    this.veterinarian,
    this.clinic,
    this.cost,
    this.documentPath,
    this.details = const {},
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  bool get isOverdue =>
      nextDueDate != null && nextDueDate!.isBefore(DateTime.now());

  bool get isDueSoon =>
      nextDueDate != null &&
      !isOverdue &&
      nextDueDate!.difference(DateTime.now()).inDays <= 30;

  String get typeDisplay {
    switch (type) {
      case HealthRecordType.vaccination:
        return 'Vaccination';
      case HealthRecordType.examination:
        return 'Examination';
      case HealthRecordType.surgery:
        return 'Surgery';
      case HealthRecordType.medication:
        return 'Medication';
      case HealthRecordType.labTest:
        return 'Lab Test';
      case HealthRecordType.deworming:
        return 'Deworming';
      case HealthRecordType.dental:
        return 'Dental';
      case HealthRecordType.other:
        return 'Other';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'animalId': animalId,
      'type': type.index,
      'title': title,
      'description': description,
      'date': date.millisecondsSinceEpoch,
      'nextDueDate': nextDueDate?.millisecondsSinceEpoch,
      'veterinarian': veterinarian,
      'clinic': clinic,
      'cost': cost,
      'documentPath': documentPath,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory HealthRecord.fromMap(Map<String, dynamic> map) {
    return HealthRecord(
      id: map['id'] as String,
      animalId: map['animalId'] as String,
      type: HealthRecordType.values[map['type'] as int],
      title: map['title'] as String,
      description: map['description'] as String?,
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      nextDueDate: map['nextDueDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['nextDueDate'] as int)
          : null,
      veterinarian: map['veterinarian'] as String?,
      clinic: map['clinic'] as String?,
      cost: map['cost'] as double?,
      documentPath: map['documentPath'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    );
  }
}
