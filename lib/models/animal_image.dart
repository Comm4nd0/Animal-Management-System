import 'package:uuid/uuid.dart';

/// Represents a photo associated with an animal.
/// One image per animal can be marked [isProfile].
class AnimalImage {
  final String id;
  final String animalId;
  final String imagePath;
  final String caption;
  final bool isProfile;
  final DateTime createdAt;

  AnimalImage({
    String? id,
    required this.animalId,
    required this.imagePath,
    this.caption = '',
    this.isProfile = false,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'animalId': animalId,
      'imagePath': imagePath,
      'caption': caption,
      'isProfile': isProfile ? 1 : 0,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory AnimalImage.fromMap(Map<String, dynamic> map) {
    return AnimalImage(
      id: map['id'] as String,
      animalId: map['animalId'] as String,
      imagePath: map['imagePath'] as String,
      caption: map['caption'] as String? ?? '',
      isProfile: (map['isProfile'] as int? ?? 0) == 1,
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    );
  }

  AnimalImage copyWith({
    String? caption,
    bool? isProfile,
  }) {
    return AnimalImage(
      id: id,
      animalId: animalId,
      imagePath: imagePath,
      caption: caption ?? this.caption,
      isProfile: isProfile ?? this.isProfile,
      createdAt: createdAt,
    );
  }
}
