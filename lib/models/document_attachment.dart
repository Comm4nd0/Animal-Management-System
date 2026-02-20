import 'package:uuid/uuid.dart';

enum DocumentType {
  pedigreeCert,
  registration,
  dnaTest,
  healthCert,
  insurance,
  contract,
  photoId,
  other;

  String get label => switch (this) {
        pedigreeCert => 'Pedigree Certificate',
        registration => 'Registration Paper',
        dnaTest => 'DNA Test Result',
        healthCert => 'Health Certificate',
        insurance => 'Insurance',
        contract => 'Contract',
        photoId => 'Photo ID',
        other => 'Other',
      };

  int get apiValue => switch (this) {
        pedigreeCert => 0,
        registration => 1,
        dnaTest => 2,
        healthCert => 3,
        insurance => 4,
        contract => 5,
        photoId => 6,
        other => 99,
      };

  static DocumentType fromApiValue(int val) => switch (val) {
        0 => pedigreeCert,
        1 => registration,
        2 => dnaTest,
        3 => healthCert,
        4 => insurance,
        5 => contract,
        6 => photoId,
        _ => other,
      };
}

class DocumentAttachment {
  final String id;
  final String animalId;
  final String title;
  final DocumentType documentType;
  final String filePath;
  final String notes;
  final DateTime uploadedAt;

  DocumentAttachment({
    String? id,
    required this.animalId,
    required this.title,
    this.documentType = DocumentType.other,
    required this.filePath,
    this.notes = '',
    DateTime? uploadedAt,
  })  : id = id ?? const Uuid().v4(),
        uploadedAt = uploadedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'animalId': animalId,
        'title': title,
        'documentType': documentType.apiValue,
        'filePath': filePath,
        'notes': notes,
        'uploadedAt': uploadedAt.millisecondsSinceEpoch,
      };

  factory DocumentAttachment.fromMap(Map<String, dynamic> map) =>
      DocumentAttachment(
        id: map['id'] as String,
        animalId: map['animalId'] as String,
        title: map['title'] as String,
        documentType: DocumentType.fromApiValue(map['documentType'] as int? ?? 99),
        filePath: map['filePath'] as String,
        notes: map['notes'] as String? ?? '',
        uploadedAt:
            DateTime.fromMillisecondsSinceEpoch(map['uploadedAt'] as int),
      );
}
