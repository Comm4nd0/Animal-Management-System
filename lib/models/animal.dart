import 'package:uuid/uuid.dart';

enum Sex { male, female, unknown }

enum AnimalStatus { alive, deceased, sold, transferred }

class Animal {
  final String id;
  final String name;
  final String species;
  final String breed;
  final Sex sex;
  final DateTime? dateOfBirth;
  final DateTime? dateOfDeath;
  final String? color;
  final String? markings;
  final String? registrationNumber;
  final String? microchipNumber;
  final String? dnaProfileId;
  final String? sireId;
  final String? damId;
  final String? breederId;
  final String? currentOwnerId;
  final String? imagePath;
  final double? weight;
  final double? height;
  final AnimalStatus status;
  final Map<String, dynamic> geneticTraits;
  final Map<String, dynamic> customFields;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Animal({
    String? id,
    required this.name,
    required this.species,
    required this.breed,
    required this.sex,
    this.dateOfBirth,
    this.dateOfDeath,
    this.color,
    this.markings,
    this.registrationNumber,
    this.microchipNumber,
    this.dnaProfileId,
    this.sireId,
    this.damId,
    this.breederId,
    this.currentOwnerId,
    this.imagePath,
    this.weight,
    this.height,
    this.status = AnimalStatus.alive,
    this.geneticTraits = const {},
    this.customFields = const {},
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  int? get ageInDays {
    if (dateOfBirth == null) return null;
    final end = dateOfDeath ?? DateTime.now();
    return end.difference(dateOfBirth!).inDays;
  }

  String? get ageDisplay {
    final days = ageInDays;
    if (days == null) return null;
    final years = days ~/ 365;
    final months = (days % 365) ~/ 30;
    if (years > 0) {
      return '$years yr${years > 1 ? 's' : ''} $months mo';
    }
    if (months > 0) {
      return '$months mo';
    }
    return '$days days';
  }

  double get inbreedingCoefficient =>
      geneticTraits['coi'] as double? ?? 0.0;

  Animal copyWith({
    String? name,
    String? species,
    String? breed,
    Sex? sex,
    DateTime? dateOfBirth,
    DateTime? dateOfDeath,
    String? color,
    String? markings,
    String? registrationNumber,
    String? microchipNumber,
    String? dnaProfileId,
    String? sireId,
    String? damId,
    String? breederId,
    String? currentOwnerId,
    String? imagePath,
    double? weight,
    double? height,
    AnimalStatus? status,
    Map<String, dynamic>? geneticTraits,
    Map<String, dynamic>? customFields,
    String? notes,
  }) {
    return Animal(
      id: id,
      name: name ?? this.name,
      species: species ?? this.species,
      breed: breed ?? this.breed,
      sex: sex ?? this.sex,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      dateOfDeath: dateOfDeath ?? this.dateOfDeath,
      color: color ?? this.color,
      markings: markings ?? this.markings,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      microchipNumber: microchipNumber ?? this.microchipNumber,
      dnaProfileId: dnaProfileId ?? this.dnaProfileId,
      sireId: sireId ?? this.sireId,
      damId: damId ?? this.damId,
      breederId: breederId ?? this.breederId,
      currentOwnerId: currentOwnerId ?? this.currentOwnerId,
      imagePath: imagePath ?? this.imagePath,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      status: status ?? this.status,
      geneticTraits: geneticTraits ?? this.geneticTraits,
      customFields: customFields ?? this.customFields,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'species': species,
      'breed': breed,
      'sex': sex.index,
      'dateOfBirth': dateOfBirth?.millisecondsSinceEpoch,
      'dateOfDeath': dateOfDeath?.millisecondsSinceEpoch,
      'color': color,
      'markings': markings,
      'registrationNumber': registrationNumber,
      'microchipNumber': microchipNumber,
      'dnaProfileId': dnaProfileId,
      'sireId': sireId,
      'damId': damId,
      'breederId': breederId,
      'currentOwnerId': currentOwnerId,
      'imagePath': imagePath,
      'weight': weight,
      'height': height,
      'status': status.index,
      'geneticTraits': _encodeMap(geneticTraits),
      'customFields': _encodeMap(customFields),
      'notes': notes,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Animal.fromMap(Map<String, dynamic> map) {
    return Animal(
      id: map['id'] as String,
      name: map['name'] as String,
      species: map['species'] as String,
      breed: map['breed'] as String,
      sex: Sex.values[map['sex'] as int],
      dateOfBirth: map['dateOfBirth'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['dateOfBirth'] as int)
          : null,
      dateOfDeath: map['dateOfDeath'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['dateOfDeath'] as int)
          : null,
      color: map['color'] as String?,
      markings: map['markings'] as String?,
      registrationNumber: map['registrationNumber'] as String?,
      microchipNumber: map['microchipNumber'] as String?,
      dnaProfileId: map['dnaProfileId'] as String?,
      sireId: map['sireId'] as String?,
      damId: map['damId'] as String?,
      breederId: map['breederId'] as String?,
      currentOwnerId: map['currentOwnerId'] as String?,
      imagePath: map['imagePath'] as String?,
      weight: map['weight'] as double?,
      height: map['height'] as double?,
      status: AnimalStatus.values[map['status'] as int? ?? 0],
      geneticTraits: _decodeMap(map['geneticTraits']),
      customFields: _decodeMap(map['customFields']),
      notes: map['notes'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
    );
  }

  static String _encodeMap(Map<String, dynamic> map) {
    if (map.isEmpty) return '{}';
    final entries = map.entries
        .map((e) => '"${e.key}":"${e.value}"')
        .join(',');
    return '{$entries}';
  }

  static Map<String, dynamic> _decodeMap(dynamic value) {
    if (value == null || value == '{}') return {};
    if (value is Map<String, dynamic>) return value;
    if (value is String) {
      final clean = value.substring(1, value.length - 1);
      if (clean.isEmpty) return {};
      final result = <String, dynamic>{};
      for (final pair in clean.split(',')) {
        final kv = pair.split(':');
        if (kv.length == 2) {
          final key = kv[0].replaceAll('"', '').trim();
          final val = kv[1].replaceAll('"', '').trim();
          result[key] = num.tryParse(val) ?? val;
        }
      }
      return result;
    }
    return {};
  }

  @override
  String toString() => 'Animal(id: $id, name: $name, breed: $breed)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Animal && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
