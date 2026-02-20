import 'package:uuid/uuid.dart';

enum ShowPlacement {
  first,
  second,
  third,
  fourth,
  fifth,
  reserve,
  champion,
  bestInShow,
  participated;

  String get label => switch (this) {
        first => '1st Place',
        second => '2nd Place',
        third => '3rd Place',
        fourth => '4th Place',
        fifth => '5th Place',
        reserve => 'Reserve',
        champion => 'Champion',
        bestInShow => 'Best in Show',
        participated => 'Participated',
      };

  int get apiValue => switch (this) {
        first => 1,
        second => 2,
        third => 3,
        fourth => 4,
        fifth => 5,
        reserve => 10,
        champion => 20,
        bestInShow => 30,
        participated => 99,
      };

  static ShowPlacement fromApiValue(int val) => switch (val) {
        1 => first,
        2 => second,
        3 => third,
        4 => fourth,
        5 => fifth,
        10 => reserve,
        20 => champion,
        30 => bestInShow,
        _ => participated,
      };
}

class ShowResult {
  final String id;
  final String animalId;
  final String showName;
  final DateTime showDate;
  final String className;
  final ShowPlacement placement;
  final String judge;
  final double? points;
  final String notes;
  final DateTime createdAt;

  ShowResult({
    String? id,
    required this.animalId,
    required this.showName,
    required this.showDate,
    this.className = '',
    this.placement = ShowPlacement.participated,
    this.judge = '',
    this.points,
    this.notes = '',
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'animalId': animalId,
        'showName': showName,
        'showDate': showDate.millisecondsSinceEpoch,
        'className': className,
        'placement': placement.apiValue,
        'judge': judge,
        'points': points,
        'notes': notes,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory ShowResult.fromMap(Map<String, dynamic> map) => ShowResult(
        id: map['id'] as String,
        animalId: map['animalId'] as String,
        showName: map['showName'] as String,
        showDate: DateTime.fromMillisecondsSinceEpoch(map['showDate'] as int),
        className: map['className'] as String? ?? '',
        placement: ShowPlacement.fromApiValue(map['placement'] as int? ?? 99),
        judge: map['judge'] as String? ?? '',
        points: (map['points'] as num?)?.toDouble(),
        notes: map['notes'] as String? ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      );
}
