import 'package:uuid/uuid.dart';

enum BreedingStatus {
  planned,
  confirmed,
  pregnant,
  whelping,
  completed,
  unsuccessful,
  cancelled,
}

class BreedingRecord {
  final String id;
  final String sireId;
  final String damId;
  final DateTime breedingDate;
  final DateTime? expectedDueDate;
  final DateTime? actualDueDate;
  final BreedingStatus status;
  final String? litterId;
  final String? method; // natural, AI, etc.
  final String? veterinarian;
  final String? notes;
  final double? sireCoiContribution;
  final double? damCoiContribution;
  final double? expectedOffspringCoi;
  final List<String> geneticTestResults;
  final DateTime createdAt;

  BreedingRecord({
    String? id,
    required this.sireId,
    required this.damId,
    required this.breedingDate,
    this.expectedDueDate,
    this.actualDueDate,
    this.status = BreedingStatus.planned,
    this.litterId,
    this.method,
    this.veterinarian,
    this.notes,
    this.sireCoiContribution,
    this.damCoiContribution,
    this.expectedOffspringCoi,
    this.geneticTestResults = const [],
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  String get statusDisplay {
    switch (status) {
      case BreedingStatus.planned:
        return 'Planned';
      case BreedingStatus.confirmed:
        return 'Confirmed';
      case BreedingStatus.pregnant:
        return 'Pregnant';
      case BreedingStatus.whelping:
        return 'Whelping';
      case BreedingStatus.completed:
        return 'Completed';
      case BreedingStatus.unsuccessful:
        return 'Unsuccessful';
      case BreedingStatus.cancelled:
        return 'Cancelled';
    }
  }

  int? get gestationDaysRemaining {
    if (expectedDueDate == null) return null;
    return expectedDueDate!.difference(DateTime.now()).inDays;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sireId': sireId,
      'damId': damId,
      'breedingDate': breedingDate.millisecondsSinceEpoch,
      'expectedDueDate': expectedDueDate?.millisecondsSinceEpoch,
      'actualDueDate': actualDueDate?.millisecondsSinceEpoch,
      'status': status.index,
      'litterId': litterId,
      'method': method,
      'veterinarian': veterinarian,
      'notes': notes,
      'sireCoiContribution': sireCoiContribution,
      'damCoiContribution': damCoiContribution,
      'expectedOffspringCoi': expectedOffspringCoi,
      'geneticTestResults': geneticTestResults.join(','),
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory BreedingRecord.fromMap(Map<String, dynamic> map) {
    return BreedingRecord(
      id: map['id'] as String,
      sireId: map['sireId'] as String,
      damId: map['damId'] as String,
      breedingDate:
          DateTime.fromMillisecondsSinceEpoch(map['breedingDate'] as int),
      expectedDueDate: map['expectedDueDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['expectedDueDate'] as int)
          : null,
      actualDueDate: map['actualDueDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['actualDueDate'] as int)
          : null,
      status: BreedingStatus.values[map['status'] as int? ?? 0],
      litterId: map['litterId'] as String?,
      method: map['method'] as String?,
      veterinarian: map['veterinarian'] as String?,
      notes: map['notes'] as String?,
      sireCoiContribution: map['sireCoiContribution'] as double?,
      damCoiContribution: map['damCoiContribution'] as double?,
      expectedOffspringCoi: map['expectedOffspringCoi'] as double?,
      geneticTestResults: (map['geneticTestResults'] as String?)
              ?.split(',')
              .where((s) => s.isNotEmpty)
              .toList() ??
          [],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    );
  }
}
