import 'package:uuid/uuid.dart';

class Litter {
  final String id;
  final String sireId;
  final String damId;
  final String? breedingRecordId;
  final DateTime dateOfBirth;
  final int totalPuppies;
  final int maleCount;
  final int femaleCount;
  final int stillborn;
  final List<String> offspringIds;
  final String? registrationNumber;
  final String? notes;
  final DateTime createdAt;

  Litter({
    String? id,
    required this.sireId,
    required this.damId,
    this.breedingRecordId,
    required this.dateOfBirth,
    this.totalPuppies = 0,
    this.maleCount = 0,
    this.femaleCount = 0,
    this.stillborn = 0,
    this.offspringIds = const [],
    this.registrationNumber,
    this.notes,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  int get survivingCount => totalPuppies - stillborn;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sireId': sireId,
      'damId': damId,
      'breedingRecordId': breedingRecordId,
      'dateOfBirth': dateOfBirth.millisecondsSinceEpoch,
      'totalPuppies': totalPuppies,
      'maleCount': maleCount,
      'femaleCount': femaleCount,
      'stillborn': stillborn,
      'offspringIds': offspringIds.join(','),
      'registrationNumber': registrationNumber,
      'notes': notes,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Litter.fromMap(Map<String, dynamic> map) {
    return Litter(
      id: map['id'] as String,
      sireId: map['sireId'] as String,
      damId: map['damId'] as String,
      breedingRecordId: map['breedingRecordId'] as String?,
      dateOfBirth:
          DateTime.fromMillisecondsSinceEpoch(map['dateOfBirth'] as int),
      totalPuppies: map['totalPuppies'] as int? ?? 0,
      maleCount: map['maleCount'] as int? ?? 0,
      femaleCount: map['femaleCount'] as int? ?? 0,
      stillborn: map['stillborn'] as int? ?? 0,
      offspringIds: (map['offspringIds'] as String?)
              ?.split(',')
              .where((s) => s.isNotEmpty)
              .toList() ??
          [],
      registrationNumber: map['registrationNumber'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    );
  }
}
