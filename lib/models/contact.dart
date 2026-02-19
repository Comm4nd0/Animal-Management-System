import 'package:uuid/uuid.dart';

/// A person or organisation that can be assigned as a breeder
/// or current owner of an animal. Both roles share this table.
class Contact {
  final String id;
  final String name;
  final String farmName;
  final String email;
  final String phone;
  final String address;
  final String prefix;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Contact({
    String? id,
    required this.name,
    this.farmName = '',
    this.email = '',
    this.phone = '',
    this.address = '',
    this.prefix = '',
    this.notes = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  String get displayName {
    if (farmName.isNotEmpty) return '$name ($farmName)';
    return name;
  }

  Contact copyWith({
    String? name,
    String? farmName,
    String? email,
    String? phone,
    String? address,
    String? prefix,
    String? notes,
  }) {
    return Contact(
      id: id,
      name: name ?? this.name,
      farmName: farmName ?? this.farmName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      prefix: prefix ?? this.prefix,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  // ─── SQLite serialization ───────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'farmName': farmName,
      'email': email,
      'phone': phone,
      'address': address,
      'prefix': prefix,
      'notes': notes,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Contact.fromMap(Map<String, dynamic> map) {
    return Contact(
      id: map['id'] as String,
      name: map['name'] as String,
      farmName: map['farmName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      address: map['address'] as String? ?? '',
      prefix: map['prefix'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      updatedAt:
          DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
    );
  }

  // ─── API serialization ─────────────────────────────────────

  factory Contact.fromApi(Map<String, dynamic> m) {
    return Contact(
      id: m['id'] as String,
      name: m['name'] as String,
      farmName: m['farm_name'] as String? ?? '',
      email: m['email'] as String? ?? '',
      phone: m['phone'] as String? ?? '',
      address: m['address'] as String? ?? '',
      prefix: m['prefix'] as String? ?? '',
      notes: m['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toApi() {
    return {
      'name': name,
      'farm_name': farmName,
      'email': email,
      'phone': phone,
      'address': address,
      'prefix': prefix,
      'notes': notes,
    };
  }

  @override
  String toString() => 'Contact(id: $id, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Contact && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
