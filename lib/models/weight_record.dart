import 'package:uuid/uuid.dart';

class WeightRecord {
  final String id;
  final String animalId;
  final DateTime date;
  final double? weight; // kg
  final double? height; // cm
  final String notes;
  final DateTime createdAt;

  WeightRecord({
    String? id,
    required this.animalId,
    required this.date,
    this.weight,
    this.height,
    this.notes = '',
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'animalId': animalId,
        'date': date.millisecondsSinceEpoch,
        'weight': weight,
        'height': height,
        'notes': notes,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory WeightRecord.fromMap(Map<String, dynamic> map) => WeightRecord(
        id: map['id'] as String,
        animalId: map['animalId'] as String,
        date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
        weight: (map['weight'] as num?)?.toDouble(),
        height: (map['height'] as num?)?.toDouble(),
        notes: map['notes'] as String? ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      );
}
