import 'package:uuid/uuid.dart';
import '../utils/constants.dart';

/// Represents a team member within an organization.
/// Used for the local SQLite cache and API responses.
class TeamMember {
  final String id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final UserRole role;
  final DateTime createdAt;

  TeamMember({
    String? id,
    required this.username,
    required this.email,
    this.firstName = '',
    this.lastName = '',
    this.role = UserRole.readOnly,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  String get roleLabel => getUserRoleLabel(role);

  String get displayName {
    if (firstName.isNotEmpty || lastName.isNotEmpty) {
      return '$firstName $lastName'.trim();
    }
    return username;
  }

  /// Parse from API response.
  factory TeamMember.fromApi(Map<String, dynamic> m) {
    final user = m['user'] as Map<String, dynamic>? ?? {};
    return TeamMember(
      id: m['id'] as String? ?? '',
      username: user['username'] as String? ?? '',
      email: user['email'] as String? ?? '',
      firstName: user['first_name'] as String? ?? '',
      lastName: user['last_name'] as String? ?? '',
      role: userRoleFromIndex(m['role'] as int? ?? 0),
      createdAt: m['created_at'] != null
          ? DateTime.tryParse(m['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  /// Convert to SQLite map for local storage.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'role': role.index,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  /// Parse from SQLite map.
  factory TeamMember.fromMap(Map<String, dynamic> m) {
    return TeamMember(
      id: m['id'] as String,
      username: m['username'] as String? ?? '',
      email: m['email'] as String? ?? '',
      firstName: m['firstName'] as String? ?? '',
      lastName: m['lastName'] as String? ?? '',
      role: userRoleFromIndex(m['role'] as int? ?? 0),
      createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int),
    );
  }

  TeamMember copyWith({UserRole? role}) {
    return TeamMember(
      id: id,
      username: username,
      email: email,
      firstName: firstName,
      lastName: lastName,
      role: role ?? this.role,
      createdAt: createdAt,
    );
  }
}
