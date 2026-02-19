import 'package:uuid/uuid.dart';

enum CustomFieldType {
  text,
  number,
  date,
  boolean,
  dropdown,
}

class CustomFieldDefinition {
  final String id;
  final String name;
  final String fieldKey;
  final CustomFieldType fieldType;
  final bool required;
  final List<String> options;
  final int displayOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  CustomFieldDefinition({
    String? id,
    required this.name,
    String? fieldKey,
    this.fieldType = CustomFieldType.text,
    this.required = false,
    this.options = const [],
    this.displayOrder = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        fieldKey = fieldKey ?? _generateKey(name),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  static String _generateKey(String name) {
    return name
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll('-', '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
  }

  String get fieldTypeDisplay {
    switch (fieldType) {
      case CustomFieldType.text:
        return 'Text';
      case CustomFieldType.number:
        return 'Number';
      case CustomFieldType.date:
        return 'Date';
      case CustomFieldType.boolean:
        return 'Yes/No';
      case CustomFieldType.dropdown:
        return 'Dropdown';
    }
  }

  CustomFieldDefinition copyWith({
    String? name,
    String? fieldKey,
    CustomFieldType? fieldType,
    bool? required,
    List<String>? options,
    int? displayOrder,
  }) {
    return CustomFieldDefinition(
      id: id,
      name: name ?? this.name,
      fieldKey: fieldKey ?? this.fieldKey,
      fieldType: fieldType ?? this.fieldType,
      required: required ?? this.required,
      options: options ?? this.options,
      displayOrder: displayOrder ?? this.displayOrder,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'fieldKey': fieldKey,
      'fieldType': fieldType.index,
      'required': required ? 1 : 0,
      'options': options.join('||'),
      'displayOrder': displayOrder,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory CustomFieldDefinition.fromMap(Map<String, dynamic> map) {
    return CustomFieldDefinition(
      id: map['id'] as String,
      name: map['name'] as String,
      fieldKey: map['fieldKey'] as String,
      fieldType: CustomFieldType.values[map['fieldType'] as int],
      required: (map['required'] as int? ?? 0) == 1,
      options: (map['options'] as String?)?.isNotEmpty == true
          ? (map['options'] as String).split('||')
          : [],
      displayOrder: map['displayOrder'] as int? ?? 0,
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      updatedAt:
          DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
    );
  }

  factory CustomFieldDefinition.fromApi(Map<String, dynamic> m) {
    return CustomFieldDefinition(
      id: m['id'] as String,
      name: m['name'] as String,
      fieldKey: m['field_key'] as String,
      fieldType: CustomFieldType.values[m['field_type'] as int? ?? 0],
      required: m['required'] as bool? ?? false,
      options: (m['options'] as List?)?.cast<String>() ?? [],
      displayOrder: m['display_order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toApi() {
    return {
      'name': name,
      'field_type': fieldType.index,
      'required': required,
      'options': options,
      'display_order': displayOrder,
    };
  }

  @override
  String toString() =>
      'CustomFieldDefinition(name: $name, type: $fieldTypeDisplay)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomFieldDefinition && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
